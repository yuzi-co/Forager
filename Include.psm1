Add-Type -Path .\Includes\OpenCL\*.cs

function Set-NvidiaPowerLimit ([int]$PowerLimitPercent, [string]$Devices) {

    if ($PowerLimitPercent -eq 0) { return }
    foreach ($Device in @($Devices -split ',')) {

        # $Command = (Resolve-Path -Path '.\includes\nvidia-smi.exe').Path
        # $Arguments = @(
        #     "-i $Device"
        #     "--query-gpu=power.default_limit"
        #     "--format=csv,noheader"
        # )
        # $PowerDefaultLimit = [int](((& $Command $Arguments) -replace 'W').Trim())

        $xpr = ".\includes\nvidia-smi.exe -i " + $Device + " --query-gpu=power.default_limit --format=csv,noheader"
        $PowerDefaultLimit = [int]((invoke-expression $xpr) -replace 'W', '')

        #powerlimit change must run in admin mode
        $NewProcess = New-Object System.Diagnostics.ProcessStartInfo ".\includes\nvidia-smi.exe"
        $NewProcess.Verb = "runas"
        #$NewProcess.UseShellExecute = $false
        $NewProcess.Arguments = "-i $Device -pl $([Math]::Floor([int]($PowerDefaultLimit -replace ' W', '') * ($PowerLimitPercent / 100)))"
        [System.Diagnostics.Process]::Start($NewProcess) | Out-Null
    }
    Remove-Variable NewProcess
}

function Send-ErrorsToLog ($LogFile) {

    for ($i = 0; $i -lt $error.count; $i++) {
        if ($error[$i].InnerException.Paramname -ne "scopeId") {
            # errors in debug
            $Msg = "###### ERROR ##### " + [string]($error[$i]) + ' ' + $error[$i].ScriptStackTrace
            Log $msg -Severity Error -NoEcho
        }
    }
    $error.clear()
}

function Edit-ForEachDevice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFileArguments,
        [Parameter(Mandatory = $false)]
        $Devices
    )

    #search string to replace
    $ConfigFileArguments = $ConfigFileArguments -replace [Environment]::NewLine, "#NL#" #replace carriage return for Select-string search (only search in each line)

    $Match = $ConfigFileArguments | Select-String -Pattern "#ForEachDevice#.*?#EndForEachDevice#"
    if ($null -ne $Match) {

        $Match.Matches | ForEach-Object {
            $Base = $_.value -replace "#ForEachDevice#" -replace "#EndForEachDevice#"
            $Index = 0
            $Final = $Devices.Devices -split ',' | ForEach-Object {
                $Base -replace "#DeviceID#", $_ -replace "#DeviceIndex#", $Index
                $Index++
            }
            $ConfigFileArguments = $ConfigFileArguments.Substring(0, $_.index) + $Final + $ConfigFileArguments.Substring($_.index + $_.Length, $ConfigFileArguments.Length - ($_.index + $_.Length))
        }
    }

    $Match = $ConfigFileArguments | Select-String -Pattern "#RemoveLastCharacter#"
    if ($null -ne $Match) {
        $Match.Matches | ForEach-Object {
            $ConfigFileArguments = $ConfigFileArguments.Substring(0, $_.index - 1) + $ConfigFileArguments.Substring($_.index + $_.Length, $ConfigFileArguments.Length - ($_.index + $_.Length))
        }
    }

    $ConfigFileArguments = $ConfigFileArguments -replace "#NL#", [Environment]::NewLine #replace carriage return for Select-string search (only search in each line)
    $ConfigFileArguments
}

function Get-NextFreePort {
    param(
        [Parameter(Mandatory = $true)]
        [int]$LastUsedPort
    )

    if ($LastUsedPort -lt 2000) {$FreePort = 2001} else {$FreePort = $LastUsedPort + 1} #not allow use of <2000 ports
    while (Test-TCPPort -Server 127.0.0.1 -Port $FreePort -timeout 100) {$FreePort = $LastUsedPort + 1}
    $FreePort
}

function Test-TCPPort {
    param([string]$Server, [int]$Port, [int]$Timeout)

    $Connection = New-Object System.Net.Sockets.TCPClient

    try {
        $Connection.SendTimeout = $Timeout
        $Connection.ReceiveTimeout = $Timeout
        $Connection.Connect($Server, $Port) | out-Null
        $Connection.Close
        $Connection.Dispose
        return $true #port is occupied
    } catch {
        $Error.Remove($error[$Error.Count - 1])
        return $false #port is free
    }
}

function Exit-Process {
    param(
        [Parameter(Mandatory = $true)]
        $Process
    )

    $sw = [Diagnostics.Stopwatch]::new()
    try {
        $Process.CloseMainWindow() | Out-Null
        $sw.Start()
        do {
            if ($sw.Elapsed.TotalSeconds -gt 1) {
                Stop-Process -InputObject $Process -Force
            }
            if (-not $Process.HasExited) {
                Start-Sleep -Milliseconds 1
            }
        } while (-not $Process.HasExited)
    } finally {
        $sw.Stop()
        if (-not $Process.HasExited) {
            Stop-Process -InputObject $Process -Force
        }
    }
    Remove-Variable sw
}

function Get-DevicesInfoAfterburner {
    param (
        $Types
    )
    $Devices = foreach ($GroupType in @('AMD')) {
        $DeviceId = 0
        $Pattern = @{
            AMD    = '*Radeon*'
            NVIDIA = '*GeForce*'
            Intel  = '*Intel*'
        }
        @($abMonitor.GpuEntries | Where-Object Device -like $Pattern.$GroupType) | ForEach-Object {
            $CardData = $abMonitor.Entries | Where-Object GPU -eq $_.Index
            $GroupName = $($Types | Where-Object GroupType -eq $GroupType | Where-Object DevicesArray -contains $DeviceId).GroupName
            $Card = [PSCustomObject]@{
                GroupName         = $GroupName
                GroupType         = $GroupType
                Id                = $DeviceId
                AdapterId         = [int]$_.Index
                Name              = $_.Device
                Utilization       = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?usage$").Data
                UtilizationMem    = [int]$($mem = $CardData | Where-Object SrcName -match "^(GPU\d* )?memory usage$"; if ($mem.MaxLimit) {$mem.Data / $mem.MaxLimit * 100})
                Clock             = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?core clock$").Data
                ClockMem          = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?memory clock$").Data
                FanSpeed          = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?fan speed$").Data
                Temperature       = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?temperature$").Data
                PowerDraw         = [int]$($CardData | Where-Object {$_.SrcName -match "^(GPU\d* )?power$" -and $_.SrcUnits -eq 'W'}).Data
                PowerLimitPercent = [int]$($abControl.GpuEntries[$_.Index].PowerLimitCur)
                PCIBus            = [int]$($null = $_.GpuId -match "&BUS_(\d+)&"; $matches[1])
            }
            $DeviceId++
            $Card
        }
    }
    $Devices
}

function Get-DevicesInfoADL {
    param (
        $Types
    )

    $CsvParams = @{
        Header = @(
            'id'
            'fan_speed'
            'fan_max'
            'clock'
            'clock_mem'
            'load'
            'temp'
            'power_limit'
            'name'
            'pci_device'
        )
    }
    $Command = ".\Includes\OverdriveN.exe"
    $Result = & $Command | Where-Object {$_ -notlike "*&???" -and $_ -notlike "*failed"} | ConvertFrom-Csv @CsvParams

    $AmdCardsTDP = Get-Content .\Data\amd-cards-tdp.json | ConvertFrom-Json

    $DeviceId = 0
    $Devices = $Result | Where-Object name -ne $null | ForEach-Object {

        $GroupName = ($Types | Where-Object DevicesArray -contains $DeviceId).GroupName

        $CardName = $($_.name `
                -replace 'ASUS' `
                -replace 'AMD' `
                -replace '\(?TM\)?' `
                -replace 'Series' `
                -replace 'Graphics' `
                -replace "\s+", ' '
        ).Trim()

        $CardName = $CardName -replace '.*Radeon.*([4-5]\d0).*', 'Radeon RX $1'     # RX 400/500 series
        $CardName = $CardName -replace '.*\s(Vega).*(56|64).*', 'Radeon Vega $2'    # Vega series
        $CardName = $CardName -replace '.*\s(R\d)\s(\w+).*', 'Radeon $1 $2'         # R3/R5/R7/R9 series
        $CardName = $CardName -replace '.*\s(HD)\s?(\w+).*', 'Radeon HD $2'         # HD series

        [PSCustomObject]@{
            GroupName         = $GroupName
            GroupType         = 'AMD'
            Id                = $DeviceId
            AdapterId         = [int]$_.id
            FanSpeed          = [int]($_.fan_speed / $_.fan_max * 100)
            Clock             = [int]($_.clock / 100)
            ClockMem          = [int]($_.clock_mem / 100)
            Utilization       = [int]$_.load
            Temperature       = [int]$_.temp / 1000
            PowerLimitPercent = 100 + [int]$_.power_limit
            PowerDraw         = $AmdCardsTDP.$CardName * ((100 + [int]$_.power_limit) / 100) * ([int]$_.load / 100)
            Name              = $CardName
        }

        $DeviceId++
    }
    Clear-Variable AmdCardsTDP
    $Devices
}

function Get-DevicesInfoNvidiaSMI {
    param (
        $Types,
        [switch]$Fake = $false
    )

    $CvsParams = @{
        Header = @(
            'gpu_name'
            'utilization_gpu'
            'utilization_memory'
            'temperature_gpu'
            'power_draw'
            'power_limit'
            'fan_speed'
            'pstate'
            'clocks_current_graphics'
            'clocks_current_memory'
            'power_max_limit'
            'power_default_limit'
        )
    }

    if ($Fake) {
        $FakeData = @"
        GeForce GTX 1060 6GB, 0 %, 3 %, 46, 9.34 W, 180.00 W, 0 %, P8, 139 MHz, 405 MHz, 200.00 W, 180.00 W
        GeForce GTX 1060 6GB, 0 %, 3 %, 46, 9.34 W, 180.00 W, 0 %, P8, 139 MHz, 405 MHz, 200.00 W, 180.00 W
        GeForce GTX 1080, 0 %, 0 %, 29, 6.54 W, 90.00 W, 39 %, P8, 135 MHz, 405 MHz, 108.00 W, 90.00 W
"@
        $Result = $FakeData | ConvertFrom-Csv @CvsParams
    } else {
        $Command = '.\includes\nvidia-smi.exe'
        $Arguments = @(
            '--query-gpu=gpu_name,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed,pstate,clocks.current.graphics,clocks.current.memory,power.max_limit,power.default_limit'
            '--format=csv,noheader'
        )
        $Result = & $Command $Arguments | ConvertFrom-Csv @CvsParams
    }

    $DeviceId = 0
    $Devices = $Result | Where-Object pstate -ne $null | ForEach-Object {
        $GroupName = ($Types | Where-Object DevicesArray -contains $DeviceId).GroupName

        $Card = [PSCustomObject]@{
            GroupName         = $GroupName
            GroupType         = 'NVIDIA'
            Id                = $DeviceId
            Name              = $_.gpu_name
            Utilization       = [int]$(if ($_.utilization_gpu) {$_.utilization_gpu -replace "[^0-9.,]"} else {100}) #If we dont have real Utilization, at least make the watchdog happy
            UtilizationMem    = [int]$($_.utilization_memory -replace "[^0-9.,]")
            Temperature       = [int]$($_.temperature_gpu -replace "[^0-9.,]")
            PowerDraw         = [int]$($_.power_draw -replace "[^0-9.,]")
            PowerLimit        = [int]$($_.power_limit -replace "[^0-9.,]")
            FanSpeed          = [int]$($_.fan_speed -replace "[^0-9.,]")
            Pstate            = $_.pstate
            Clock             = [int]$($_.clocks_current_graphics -replace "[^0-9.,]")
            ClockMem          = [int]$($_.clocks_current_memory -replace "[^0-9.,]")
            PowerMaxLimit     = [int]$($_.power_max_limit -replace "[^0-9.,]")
            PowerDefaultLimit = [int]$($_.power_default_limit -replace "[^0-9.,]")
        }
        if ($Card.PowerDefaultLimit -gt 0) { $Card | Add-Member PowerLimitPercent ([int](($Card.PowerLimit * 100) / $Card.PowerDefaultLimit)) }
        $Card
        $DeviceId++
    }
    $Devices
}

function Get-DevicesInfoCPU {

    $CpuResult = @(Get-CimInstance Win32_Processor)

    ### Not sure how Afterburner results look with more than 1 CPU
    if ($abMonitor) {
        $CpuData = @{
            Clock       = $($abMonitor.Entries | Where-Object SrcName -match '^(CPU\d* )clock' | Measure-Object -Property Data -Maximum).Maximum
            Utilization = $($abMonitor.Entries | Where-Object SrcName -match '^(CPU\d* )usage'| Measure-Object -Property Data -Average).Average
            PowerDraw   = $($abMonitor.Entries | Where-Object SrcName -eq 'CPU power').Data
            Temperature = $($abMonitor.Entries | Where-Object SrcName -match "^(CPU\d* )temperature" | Measure-Object -Property Data -Maximum).Maximum
        }
    } else {
        $CpuData = @{}
    }

    $Devices = $CpuResult | ForEach-Object {
        if (-not $CpuData.Utilization) {
            # Get-Counter is more accurate and is preferable, but currently not available in Poweshell 6
            if (Get-Command "Get-Counter" -Type Cmdlet -errorAction SilentlyContinue) {
                # Language independent version of Get-Counter '\Processor(_Total)\% Processor Time'
                $CpuData.Utilization = (Get-Counter -Counter '\238(_Total)\6').CounterSamples.CookedValue
            } else {
                $Error.Remove($Error[$Error.Count - 1])
                $CpuData.Utilization = $_.LoadPercentage
            }
        }
        if (-not $CpuData.PowerDraw) {
            if (-not $CpuTDP) {$CpuTDP = Get-Content ".\Data\cpu-tdp.json" | ConvertFrom-Json}
            $CpuData.PowerDraw = $CpuTDP.($_.Name.Trim()) * $CpuData.Utilization / 100
        }
        if (-not $CpuData.Clock) {$CpuData.Clock = $_.MaxClockSpeed}
        [PSCustomObject]@{
            GroupName   = 'CPU'
            GroupType   = 'CPU'
            Id          = [int]($_.DeviceID -replace "[^0-9]")
            Name        = $_.Name.Trim()
            Cores       = [int]$_.NumberOfCores
            Threads     = [int]$_.NumberOfLogicalProcessors
            CacheL3     = [int]($_.L3CacheSize / 1024)
            Clock       = [int]$CpuData.Clock
            Utilization = [int]$CpuData.Utilization
            PowerDraw   = [int]$CpuData.PowerDraw
            Temperature = [int]$CpuData.Temperature
        }
    }
    $Devices
}

function Get-DevicesInformation ($Types) {
    $Devices = @()
    if ($abMonitor) {$abMonitor.ReloadAll()}
    if ($abControl) {$abControl.ReloadAll()}

    #AMD
    if ($Types | Where-Object GroupType -in @('AMD')) {
        if ($abMonitor) {
            Get-DevicesInfoAfterburner -Types ($Types | Where-Object GroupType -eq 'AMD')
        } else {
            Get-DevicesInfoADL -Types ($Types | Where-Object GroupType -eq 'AMD')
        }
    }

    #NVIDIA
    if ($Types | Where-Object GroupType -eq 'NVIDIA') {
        Get-DevicesInfoNvidiaSMI -Types ($Types | Where-Object GroupType -eq 'NVIDIA')
    }

    # CPU
    if ($Types | Where-Object GroupType -eq 'CPU') {
        Get-DevicesInfoCPU
    }
}

function Out-DevicesInformation ($Devices) {

    $Devices | Where-Object GroupType -ne 'CPU' | Sort-Object GroupType | Format-Table -Wrap (
        @{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
        @{Label = "Group"; Expression = {$_.GroupName}; Align = 'right'},
        @{Label = "Name"; Expression = {$_.Name}},
        @{Label = "Load"; Expression = {[string]$_.Utilization + "%"}; Align = 'right'},
        @{Label = "Power"; Expression = {[string]$_.PowerDraw + "W"}; Align = 'right'},
        @{Label = "Temp"; Expression = {$_.Temperature}; Align = 'right'},
        @{Label = "Clock"; Expression = {[string]$_.Clock + "Mhz"}; Align = 'right'},
        @{Label = "ClkMem"; Expression = {[string]$_.ClockMem + "Mhz"}; Align = 'right'},
        @{Label = "Mem"; Expression = {[string]$_.UtilizationMem + "%"}; Align = 'right'},
        @{Label = "Fan"; Expression = {[string]$_.FanSpeed + "%"}; Align = 'right'},
        @{Label = "PwLim"; Expression = {[string]$_.PowerLimitPercent + '%'}; Align = 'right'},
        @{Label = "Pstate"; Expression = {$_.pstate}; Align = 'right'}
    ) -GroupBy GroupType | Out-Host

    $Devices | Where-Object GroupType -eq 'CPU' | Format-Table -Wrap (
        @{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
        @{Label = "Group"; Expression = {$_.GroupName}; Align = 'right'},
        @{Label = "Name"; Expression = {$_.Name}},
        @{Label = "Load"; Expression = {[string]$_.Utilization + "%"}; Align = 'right'},
        @{Label = "Power"; Expression = {[string]$_.PowerDraw + "W"}; Align = 'right'},
        @{Label = "Temp"; Expression = {$_.Temperature}; Align = 'right'},
        @{Label = "Clock"; Expression = {[string]$_.Clock + "Mhz"}; Align = 'right'},
        @{Label = "Cores"; Expression = {$_.Cores}},
        @{Label = "Threads"; Expression = {$_.Threads}},
        @{Label = "CacheL3"; Expression = {[string]$_.CacheL3 + "MB"}; Align = 'right'}
    ) -GroupBy GroupType | Out-Host
}

function Get-Devices {
    param(
        [Parameter(Mandatory = $false)]
        [array]$Types = @('AMD', 'NVIDIA', 'CPU')
    )

    $OCLDevices = Get-OpenCLDevices

    $GroupFilter = @"
    {
        "AMD": {
            "Type":  "Gpu",
            "Vendor":  "Advanced Micro Devices, Inc.",
            "PlatformId":  "*"
        },
        "NVIDIA": {
            "Type": "Gpu",
            "Vendor": "NVIDIA*",
            "PlatformId": "*"
        },
        "INTEL": {
            "Type": "Gpu",
            "Vendor": "Intel(R) Corporation",
            "PlatformId": "*"
        },
        "CPU": {
            "Type": "Cpu",
            "Vendor": "*",
            "PlatformId": "*"
        }
    }
"@ | ConvertFrom-Json

    $Groups = foreach ($GroupType in $Types) {
        $GroupBy = @{
            Property = @('PlatformId')
        }
        if ($Config.GroupGpuByType) {
            $GroupBy = @{
                Property = @('PlatformId', 'Name', 'GlobalMemSize', 'MaxComputeUnits')
            }
        }
        if ($GroupType -eq 'CPU') {
            $GroupBy = @{
                Property = @('Type')
            }
        }
        $DeviceList = $OCLDevices | Where-Object {
            $_.Type -like $GroupFilter.$GroupType.Type -and
            $_.Vendor -like $GroupFilter.$GroupType.Vendor -and
            $_.PlatformId -like $GroupFilter.$GroupType.PlatformId
        }
        if ($GroupType -eq 'CPU') {
            if ($DeviceList) {
                $DeviceList = $DeviceList | Sort-Object PlatformId | Select-Object -First 1
            } else {
                # Fake CPU device if none detected in OpenCL
                $DeviceList = @{
                    PlatformId = 0
                    DeviceIndex = 0
                    Name = 'CPU'
                    Vendor = 'Generic'
                    Type = 'Cpu'
                }
            }
        }
        $DeviceList | Group-Object @GroupBy | ForEach-Object {
            if ($_.Group) {
                $Devices = $_.Group | Select-Object -Property PlatformId, Name, Vendor, GlobalMemSize, MaxComputeUnits -First 1
                $GroupName = $GroupType
                if ($Config.GroupGpuByType -and $GroupType -ne 'CPU') {
                    $GroupName = ($Devices.Name -replace "[^\w]") + '_' + $Devices.MaxComputeUnits + 'cu' + [int]($Devices.GlobalMemSize / 1GB) + 'gb'
                }
                $Devices | Add-Member Devices $($_.Group.DeviceIndex -join ',')
                $Devices | Add-Member GroupType $GroupType
                $Devices | Add-Member GroupName $GroupName
                $Devices | Add-Member Enabled $true
                $Devices | Add-Member OCLDevices ($_.Group | Select-Object -Property GlobalMemSize, MaxComputeUnits)

                $Devices | Select-Object -Property GroupName, GroupType, Name, PlatformId, Devices, Enabled, Vendor, OCLDevices
            }
        }
    }
    @($Groups)
}

function Get-OpenCLDevices {
    param(
        [switch]$Fake = $false
    )

    if ($Fake) {
        # start fake
        $OCLDevices = @(
            [PSCustomObject]@{Name = 'Ellesmere'; Vendor = 'Advanced Micro Devices, Inc.'; GlobalMemSize = 8GB; PlatformId = 0; Type = 'Gpu'; DeviceIndex = 0; MaxComputeUnits = 30}
            [PSCustomObject]@{Name = 'Ellesmere'; Vendor = 'Advanced Micro Devices, Inc.'; GlobalMemSize = 8GB; PlatformId = 0; Type = 'Gpu'; DeviceIndex = 1; MaxComputeUnits = 30}
            [PSCustomObject]@{Name = 'Ellesmere'; Vendor = 'Advanced Micro Devices, Inc.'; GlobalMemSize = 4GB; PlatformId = 0; Type = 'Gpu'; DeviceIndex = 2; MaxComputeUnits = 30}
            [PSCustomObject]@{Name = 'GeForce 1060'; Vendor = 'NVIDIA Corporation'; GlobalMemSize = 3GB; PlatformId = 1; Type = 'Gpu'; DeviceIndex = 0; MaxComputeUnits = 30}
            [PSCustomObject]@{Name = 'GeForce 1060'; Vendor = 'NVIDIA Corporation'; GlobalMemSize = 3GB; PlatformId = 1; Type = 'Gpu'; DeviceIndex = 1; MaxComputeUnits = 30}
            [PSCustomObject]@{Name = 'GeForce 1080'; Vendor = 'NVIDIA Corporation'; GlobalMemSize = 8GB; PlatformId = 1; Type = 'Gpu'; DeviceIndex = 2; MaxComputeUnits = 60}
            [PSCustomObject]@{Name = 'Intel CPU'; Vendor = 'Intel'; GlobalMemSize = 8GB; PlatformId = 1; Type = 'Cpu'; DeviceIndex = 1; MaxComputeUnits = 4}
        )
        # end fake
    } else {
        Add-Type -Path .\Includes\OpenCL\*.cs
        try {
            $OCLPlatforms = [OpenCl.Platform]::GetPlatformIds()
            if ($OCLPlatforms) {
                $PlatformId = 0
                $OCLDeviceId = 0
                $OCLGpuId = 0
                $OCLDevices = @($OCLPlatforms | ForEach-Object {
                        $Devs = [OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All)
                        $Devs | Add-Member PlatformId $PlatformId
                        $Devs | ForEach-Object {
                            $_ | Add-Member DeviceIndex $([array]::indexof($Devs, $_))
                            $_ | Add-Member OCLDeviceId $OCLDeviceId
                            $OCLDeviceId++
                            if ($_.Type -eq 'Gpu') {
                                $_ | Add-Member OCLGpuId $OCLGpuId
                                $OCLGpuId++
                            }
                        }
                        $PlatformId++
                        $Devs
                    })
            }
        } catch {
            Log "Error during OpenCL device detection!" -Severity Warn
            Exit
        }
    }
    $OCLDevices
}

function Get-MiningTypes () {
    param(
        [Parameter(Mandatory = $false)]
        [array]$Filter = @(),
        [Parameter(Mandatory = $false)]
        [switch]$All = $false
    )

    $Devices = @(
        if ($Config.GpuGroups -is [string] -and $Config.GpuGroups.Length -gt 0 -and -not $All) {
            # GpuGroups not empty, parse it
            $Config.GpuGroups | ConvertFrom-Json
        } else {
            # Autodetection on
            Get-Devices -Types AMD, NVIDIA
        }
        if ($Config.CPUMining -or $All) {
            Get-Devices -Types CPU
        }
    )

    $Devices | ForEach-Object {
        if ($null -eq $_.Enabled) { $_ | Add-Member Enabled $true }
    }

    if ($Devices | Where-Object {$_.GroupType -eq 'CPU'}) {

        $CpuResult = Get-CimInstance Win32_Processor
        $Features = $($feat = @{}; switch -regex ((& .\Includes\CHKCPU32.exe /x) -split "</\w+>") {"^\s*<_?(\w+)>(\d+).*" {$feat.($matches[1]) = [int]$matches[2]}}; $feat)
        $RealCores = [int[]](0..($CpuResult.NumberOfLogicalProcessors - 1))
        if ($CpuResult.NumberOfLogicalProcessors -gt $CpuResult.NumberOfCores) {
            $RealCores = $RealCores | Where-Object {-not ($_ % 2)}
        }
        $Devices | Where-Object {$_.GroupType -eq 'CPU'} | ForEach-Object {
            $_ | Add-Member Devices "0" -Force
            $_ | Add-Member RealCores ($RealCores -join ',')
            $_ | Add-Member Features $Features
        }
    }

    $OCLDevices = Get-OpenCLDevices

    $TypeID = 0
    $DeviceGroups = $Devices | ForEach-Object {
        if (-not $Filter -or (Compare-Object $_.GroupName $Filter -IncludeEqual -ExcludeDifferent)) {

            $_ | Add-Member ID $TypeID
            $TypeID++

            $_ | Add-Member DevicesArray @([int[]]($_.Devices -split ','))   # @(0,1,2,10,11,12)
            $_ | Add-Member DevicesCount ($_.DevicesArray.count)             # 6

            $Pattern = switch ($_.GroupType) {
                'AMD' { @('Advanced Micro Devices, Inc.') }
                'NVIDIA' { @('NVIDIA Corporation') }
                'INTEL' { @('Intel(R) Corporation') }
                'CPU' { @('GenuineIntel', 'AuthenticAMD') }
            }
            $OCLDevice = @($OCLDevices | Where-Object {$Pattern -contains $_.Vendor})[$_.DevicesArray]
            if ($OCLDevice) {
                if ($null -eq $_.PlatformId) {$_ | Add-Member PlatformId ($OCLDevice.PlatformId | Select-Object -First 1)}
                if ($null -eq $_.MemoryGB) {$_ | Add-Member MemoryGB ([int](($OCLDevice | Measure-Object -Property GlobalMemSize -Minimum).Minimum / 1GB ))}
                if ($OCLDevice[0].Platform.Version -match "CUDA\s+([\d\.]+)") {$_ | Add-Member CUDAVersion $Matches[1] -Force}
            }
            $_ | Add-Member OCLDeviceId (, $OCLDevice.OCLDeviceId)
            $_ | Add-Member OCLGpuId (, $OCLDevice.OCLGpuId)

            if ($_.PowerLimits -is [string] -and $_.PowerLimits.Length -gt 0) {
                $_ | Add-Member PowerLimits @([int[]]($_.PowerLimits -split ',') | Sort-Object -Descending -Unique) -Force
            } else {
                $_ | Add-Member PowerLimits @(0) -Force
            }

            if ($_.GroupType -eq 'AMD' -and -not $abControl) {
                $_ | Add-Member PowerLimits @(0) -Force
            }

            $_ | Add-Member MinProfit ([math]::Max($Config.("MinProfit_" + $_.GroupName), 0))
            $_ | Add-Member Algorithms ($Config.("Algorithms_" + $_.GroupName) -split ',')

            $_
        }
    }
    $DeviceGroups #return
}

function Format-DeviceList {
    param(
        [Parameter(Mandatory = $false)]
        [Array]$Devices,

        [Parameter(Mandatory = $false)]
        [string]$List,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Clay', 'Nsg', 'Eth', 'Count', 'Mask')]
        [string]$Type = 'Info'
    )

    if ($List -and -not $Devices) {
        $Devices = $List -split ','
    }

    switch ($Type) {
        Clay { ($Devices | ForEach-Object {'{0:X}' -f $_}) -join '' }    # 012ABC
        Nsg { ($Devices | ForEach-Object { "-d " + $_}) -join ' ' }      # -d 0 -d 1 -d 2 -d 10 -d 11 -d 12
        Eth { $Devices -join ' ' }                                       # 0 1 2 10 11 12
        Count { $Devices.count }                                         # 6
        Mask { '{0:X}' -f [int]($Devices | ForEach-Object { [System.Math]::Pow(2, $_) } | Measure-Object -Sum).Sum }
    }
}

function Get-SystemInfo () {

    $OperatingSystem = Get-CimInstance Win32_OperatingSystem
    $Features = $($feat = @{}; switch -regex ((& .\Includes\CHKCPU32.exe /x) -split "</\w+>") {"^\s*<_?(\w+)>(\d+).*" {$feat.($matches[1]) = [int]$matches[2]}}; $feat)

    [PSCustomObject]@{
        OSName       = $OperatingSystem.Caption
        OSVersion    = [version]$OperatingSystem.Version
        ComputerName = $env:COMPUTERNAME
        CPUCores     = $Features.cores
        CPUThreads   = $Features.threads
        CPUFeatures  = $Features
    }
}

Function Write-Log {
    param(
        [Parameter()]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warn', 'Error', 'Debug')]
        [string]$Severity = 'Info',

        [Parameter()]
        [switch]$NoEcho = $false
    )
    if ($Message) {
        if ($LogFile) {
            $LogFile.WriteLine("$(Get-Date -f "HH:mm:ss.ff")`t$Severity`t$Message")
        }
        if ($NoEcho -eq $false) {
            switch ($Severity) {
                Info { Write-Host "$Message" -ForegroundColor Green }
                Warn { Write-Warning "$Message" }
                Error { Write-Error "$Message" }
            }
        }
    }
}
Set-Alias Log Write-Log

Function Read-KeyboardTimed {
    param(
        [Parameter(Mandatory = $true)]
        [int]$SecondsToWait,
        [Parameter(Mandatory = $true)]
        [array]$ValidKeys
    )

    $LoopStart = Get-Date
    $KeyPressed = $null

    while ((New-TimeSpan $LoopStart (Get-Date)).Seconds -le $SecondsToWait -and $ValidKeys -notcontains $KeyPressed) {
        if ($Host.UI.RawUI.KeyAvailable) {
            $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
            $KeyPressed = $Key.character
            while ($Host.UI.RawUI.KeyAvailable) {$Host.UI.RawUI.FlushInputBuffer()} #keyb buffer flush
        }
        Start-Sleep -Milliseconds 30
    }
    $KeyPressed
}

function Invoke-TCPRequest {
    param(
        [Parameter(Mandatory = $false)]
        [String]$Server = "localhost",
        [Parameter(Mandatory = $true)]
        [String]$Port,
        [Parameter(Mandatory = $true)]
        [String]$Request,
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 5 #seconds
    )

    try {
        $Client = New-Object System.Net.Sockets.TcpClient $Server, $Port
        $Stream = $Client.GetStream()
        $Writer = New-Object System.IO.StreamWriter $Stream
        $Reader = New-Object System.IO.StreamReader $Stream
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Writer.AutoFlush = $true

        $Writer.WriteLine($Request)
        $Response = $Reader.ReadLine()
    } catch { $Error.Remove($error[$Error.Count - 1])}
    finally {
        if ($Reader) {$Reader.Close()}
        if ($Writer) {$Writer.Close()}
        if ($Stream) {$Stream.Close()}
        if ($Client) {$Client.Close()}
    }
    $response
}

function Get-TCPResponse {
    param(
        [Parameter(Mandatory = $false)]
        [String]$Server = "localhost",
        [Parameter(Mandatory = $true)]
        [String]$Port,
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 5, #seconds
        [Parameter(Mandatory = $false)]
        [String]$Request
    )

    try {
        $Client = New-Object System.Net.Sockets.TcpClient $Server, $Port
        $Stream = $Client.GetStream()
        if ($Request) { $Writer = New-Object System.IO.StreamWriter $Stream }
        $Reader = New-Object System.IO.StreamReader $Stream
        $Client.SendTimeout = $Timeout * 1000
        $Client.ReceiveTimeout = $Timeout * 1000
        if ($Request) {
            $Writer.AutoFlush = $true
            $Writer.Write($Request)
        }

        $Response = $Reader.ReadToEnd()
    } catch { $Error.Remove($error[$Error.Count - 1])}
    finally {
        if ($Reader) {$Reader.Close()}
        if ($Writer) {$Writer.Close()}
        if ($Stream) {$Stream.Close()}
        if ($Client) {$Client.Close()}
    }
    $response
}

function Invoke-HTTPRequest {
    param(
        [Parameter(Mandatory = $false)]
        [String]$Server = "localhost",
        [Parameter(Mandatory = $true)]
        [String]$Port,
        [Parameter(Mandatory = $false)]
        [String]$Path,
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 5 #seconds
    )

    $ProgressPreference = 'SilentlyContinue' #No progress message on web requests

    try {
        $Response = Invoke-WebRequest "http://$($Server):$Port$Path" -UseBasicParsing -TimeoutSec $timeout
    } catch {
        $Error.Remove($error[$Error.Count - 1])
        $Response = $null
    }
    $Response
}

function Invoke-APIRequest {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Url,
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 5, # Request timeout in seconds
        [Parameter(Mandatory = $false)]
        [Int]$Retry = 3, # Amount of retries for request from origin
        [Parameter(Mandatory = $false)]
        [Int]$MaxAge = 10, # Max cache age if request failed, in minutes
        [Parameter(Mandatory = $false)]
        [Int]$Age = 3 # Cache age after which to request from origin, in minutes
    )

    $ProgressPreference = 'SilentlyContinue' #No progress message on web requests

    $UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36'
    $CachePath = '.\Cache\'
    $CacheFile = $CachePath + [System.Web.HttpUtility]::UrlEncode($Url) + '.json'

    if (-not (Test-Path -Path $CachePath)) { New-Item -Path $CachePath -ItemType directory -Force | Out-Null }
    if (Test-Path -LiteralPath $CacheFile -NewerThan (Get-Date).AddMinutes( - $Age)) {
        $Response = Get-Content -Path $CacheFile | ConvertFrom-Json
    } else {
        while ($Retry -gt 0) {
            try {
                $Retry--
                $Response = Invoke-RestMethod -Uri $Url -UserAgent $UserAgent -UseBasicParsing -TimeoutSec $Timeout
                if ($Response) {$Retry = 0}
            } catch {
                Start-Sleep -Seconds 2
                $Error.Remove($error[$Error.Count - 1])
            }
        }
        if ($Response) {
            if ($CacheFile.Length -lt 250) {$Response | ConvertTo-Json -Depth 100 | Set-Content -Path $CacheFile}
        } elseif (Test-Path -LiteralPath $CacheFile -NewerThan (Get-Date).AddMinutes( - $MaxAge)) {
            $Response = Get-Content -Path $CacheFile | ConvertFrom-Json
        } else {
            $Response = $null
        }
    }
    $Response
}

function Get-LiveHashRate {
    param(
        [Parameter(Mandatory = $true)]
        [Object]$Miner
    )

    try {
        switch ($Miner.Api) {

            "xgminer" {
                $Message = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request $Message

                if ($Request) {
                    $Data = $Request.Substring($Request.IndexOf("{"), $Request.LastIndexOf("}") - $Request.IndexOf("{") + 1) | ConvertFrom-Json

                    $HashRate = @(
                        [double]$Data.SUMMARY."HS 5s"
                        [double]$Data.SUMMARY."MHS 5s" * 1e6
                        [double]$Data.SUMMARY."KHS 5s" * 1e3
                        [double]$Data.SUMMARY."GHS 5s" * 1e9
                        [double]$Data.SUMMARY."THS 5s" * 1e12
                        [double]$Data.SUMMARY."PHS 5s" * 1e15
                    ) | Where-Object {$_ -gt 0} | Select-Object -First 1

                    if (-not $HashRate) {
                        $HashRate = @(
                            [double]$Data.SUMMARY."HS av"
                            [double]$Data.SUMMARY."MHS av" * 1e6
                            [double]$Data.SUMMARY."KHS av" * 1e3
                            [double]$Data.SUMMARY."GHS av" * 1e9
                            [double]$Data.SUMMARY."THS av" * 1e12
                            [double]$Data.SUMMARY."PHS av" * 1e15
                        ) | Where-Object {$_ -gt 0} | Select-Object -First 1
                    }
                }
            }

            "ccminer" {
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request "summary"
                if ($Request) {
                    $Data = $Request -split ";" | ConvertFrom-StringData
                    $HashRate = @(
                        [double]$Data.HS
                        [double]$Data.KHS * 1e3
                        [double]$Data.MHS * 1e6
                        [double]$Data.GHS * 1e9
                        [double]$Data.THS * 1e12
                        [double]$Data.PHS * 1e15
                    ) | Where-Object {$_ -gt 0} | Select-Object -First 1
                }
            }

            "ewbf" {
                $Message = @{id = 1; method = "getstat"} | ConvertTo-Json -Compress
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request $Message
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double](($Data.result.speed_sps) | Measure-Object -Sum).Sum
                }
            }

            "Claymore" {
                $Message = @{id = 0; jsonrpc = "2.0"; method = "miner_getstat1"} | ConvertTo-Json -Compress
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request $Message
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $Multiplier = 1
                    if ($Data.result[0] -notmatch "^TT-Miner") {
                        switch -wildcard ($Miner.Algorithm) {
                            Ethash* { $Multiplier *= 1000 }
                            NeoScrypt* { $Multiplier *= 1000 }
                            ProgPOW* { $Multiplier *= 1000 }
                            Ubqhash* { $Multiplier *= 1000 }
                        }
                    }
                    $HashRate = @(
                        [double]$Data.result[2].Split(";")[0] * $Multiplier
                        [double]$Data.result[4].Split(";")[0] * $Multiplier
                    )
                }
            }

            "wrapper" {
                $wrpath = ".\Wrapper_$($Miner.ApiPort).txt"
                $HashRate = [double]$(if (Test-Path -path $wrpath) {Get-Content $wrpath} else {0})
            }

            "castXMR" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]($Data.devices.hash_rate | Measure-Object -Sum).Sum / 1000
                }
            }

            "XMrig" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort -Path "/api.json"
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]$Data.HashRate.total[0]
                }
            }

            "BMiner" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort -Path "/api/v1/status/solver"
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = $Data.devices |
                        Get-Member -MemberType NoteProperty |
                        ForEach-Object {$Data.devices.($_.name).solvers} |
                        Group-Object algorithm |
                        ForEach-Object {
                        @(
                            $_.group.speed_info.hash_rate | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                            $_.group.speed_info.solution_rate | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                        ) | Where-Object {$_ -gt 0}
                    }
                }
            }

            "SRB" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = @(
                        [double]$Data.HashRate_total_now
                        [double]$Data.HashRate_total_5min
                    ) | Where-Object {$_ -gt 0} | Select-Object -First 1
                }
            }

            "JCE" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]$Data.HashRate.total
                }
            }

            "LOL" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort -Path "/summary"
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]$Data.'Session'.'Performance_Summary'
                }
            }

            "MiniZ" {
                $Message = '{"id":"0", "method":"getstat"}'
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request $Message
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double](($Data.result.speed_sps) | Measure-Object -Sum).Sum
                }
            }

            "GMiner" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort -Path "/stat"
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double](($Data.devices.speed) | Measure-Object -Sum).Sum
                }
            }

            "Mkx" {
                $Request = Get-TCPResponse -Port $Miner.ApiPort -Request 'stats'
                if ($Request) {
                    $Data = $Request.Substring($Request.IndexOf("{"), $Request.LastIndexOf("}") - $Request.IndexOf("{") + 1) | ConvertFrom-Json
                    $HashRate = [double]$Data.gpus.hashrate * 1e6
                }
            }

            "GrinPro" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort -Path "/api/status"
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double](($Data.workers.graphsPerSecond) | Measure-Object -Sum).Sum
                }
            }

            "NBMiner" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort -Path "/api/v1/status"
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = @(
                        [double]$Data.miner.total_hashrate_raw
                        [double]$Data.miner.total_hashrate2_raw
                    )
                }
            }

            "RH" {
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request ' '
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]($Data.infos.speed | Measure-Object -Sum).Sum
                }
            }
        } #end switch

        $HashRate
    } catch {}
}

function ConvertTo-Hash {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Hash
    )

    $Return = switch ([math]::truncate([math]::log($Hash, 1e3))) {
        1 {"{0:g4} kh" -f ($Hash / 1e3)}
        2 {"{0:g4} mh" -f ($Hash / 1e6)}
        3 {"{0:g4} gh" -f ($Hash / 1e9)}
        4 {"{0:g4} th" -f ($Hash / 1e12)}
        5 {"{0:g4} ph" -f ($Hash / 1e15)}
        default {"{0:g4} h" -f ($Hash)}
    }
    $Return
}

function Start-SubProcess {
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath,
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "",
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "",
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)] <# UselessGuru #>
        [String]$MinerWindowStyle = "Minimized", <# UselessGuru #>
        [Parameter(Mandatory = $false)] <# UselessGuru #>
        [String]$UseAlternateMinerLauncher = $true <# UselessGuru #>
    )

    $PriorityNames = @{
        -2 = "Idle"
        -1 = "BelowNormal"
        0  = "Normal"
        1  = "AboveNormal"
        2  = "High"
        3  = "RealTime"
    }

    if ($UseAlternateMinerLauncher) {

        $ShowWindow = @{
            Normal    = "SW_SHOW"
            Maximized = "SW_SHOWMAXIMIZE"
            Minimized = "SW_SHOWMINNOACTIVE"
        }

        $Job = Start-Job `
            -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)');. .\Includes\CreateProcess.ps1")) `
            -ArgumentList $PID, $FilePath, $ArgumentList, $ShowWindow.$MinerWindowStyle, $PriorityNames.$Priority, $WorkingDirectory {
            param($ControllerProcessID, $FilePath, $ArgumentList, $ShowWindow, $Priority, $WorkingDirectory)

            . .\Includes\CreateProcess.ps1
            $ControllerProcess = Get-Process -Id $ControllerProcessID
            if (-not $ControllerProcess) {return}

            $ProcessParams = @{
                Binary           = $FilePath
                Arguments        = $ArgumentList
                CreationFlags    = [CreationFlags]::CREATE_NEW_CONSOLE
                ShowWindow       = $ShowWindow
                StartF           = [STARTF]::STARTF_USESHOWWINDOW
                Priority         = $Priority
                WorkingDirectory = $WorkingDirectory
            }
            $Process = Invoke-CreateProcess @ProcessParams
            if (-not $Process) {
                [PSCustomObject]@{
                    ProcessId = $null
                }
                return
            }

            [PSCustomObject]@{
                ProcessId     = $Process.Id
                ProcessHandle = $Process.Handle
            }

            $null = $ControllerProcess.Handle
            $null = $Process.Handle

            do {
                if ($ControllerProcess.WaitForExit(1000)) {
                    $null = $Process.CloseMainWindow()
                }
            }
            while ($Process.HasExited -eq $false)
        }
    } else {
        $Job = Start-Job -ArgumentList $PID, $FilePath, $ArgumentList, $WorkingDirectory, $MinerWindowStyle {
            param($ControllerProcessID, $FilePath, $ArgumentList, $WorkingDirectory, $MinerWindowStyle)

            $ControllerProcess = Get-Process -Id $ControllerProcessID
            if (-not $ControllerProcess) {
                return
            }

            $ProcessParam = @{
                FilePath         = $FilePath
                WindowStyle      = $MinerWindowStyle
                ArgumentList     = $(if ($ArgumentList) {$ArgumentList})
                WorkingDirectory = $(if ($WorkingDirectory) {$WorkingDirectory})
            }

            $Process = Start-Process @ProcessParam -PassThru
            if (-not $Process) {
                [PSCustomObject]@{
                    ProcessId = $null
                }
                return
            }

            [PSCustomObject]@{
                ProcessId     = $Process.Id
                ProcessHandle = $Process.Handle
            }

            $null = $ControllerProcess.Handle
            $null = $Process.Handle

            do {
                if ($ControllerProcess.WaitForExit(1000)) {
                    $null = $Process.CloseMainWindow()
                }
            }
            while ($Process.HasExited -eq $false)

        }
    }

    do {
        Start-Sleep -Seconds 1
        $JobOutput = Receive-Job $Job
    }
    while (-not $JobOutput)

    if ($JobOutput.ProcessId -gt 0) {
        $Process = Get-Process | Where-Object Id -eq $JobOutput.ProcessId
        $null = $Process.Handle
        $Process

        if ($Process) {$Process.PriorityClass = $PriorityNames.$Priority}
    }
}

function Expand-WebRequest {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Uri,
        [Parameter(Mandatory = $true)]
        [String]$Path,
        [Parameter(Mandatory = $false)]
        [String]$SHA256
    )

    $DestinationFolder = $PSScriptRoot + $Path.Substring(1)
    $FileName = ([IO.FileInfo](Split-Path $Uri -Leaf)).name
    $CachePath = $PSScriptRoot + '\Downloads\'
    $FilePath = $CachePath + $Filename

    if (-not (Test-Path -LiteralPath $CachePath)) {$null = New-Item -Path $CachePath -ItemType directory}

    try {
        if (Test-Path -LiteralPath $FilePath) {
            if ($SHA256 -and (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash -ne $SHA256) {
                Log "Existing file hash doesn't match. Will re-download." -Severity Warn
                Remove-Item $FilePath
            }
        }
        if (-not (Test-Path -LiteralPath $FilePath)) {
            (New-Object System.Net.WebClient).DownloadFile($Uri, $FilePath)
        }
        if (Test-Path -LiteralPath $FilePath) {
            if ($SHA256 -and (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash -ne $SHA256) {
                Log "File hash doesn't match. Removing file." -Severity Warn
            } elseif (@('.msi', '.exe') -contains (Get-Item $FilePath).Extension) {
                Start-Process $FilePath "-qb" -Wait
            } else {
                $Command = 'x "' + $FilePath + '" -o"' + $DestinationFolder + '" -y -spe'
                Start-Process ".\includes\7z.exe" $Command -Wait
            }
        }
    } finally {
        # if (Test-Path $FilePath) {Remove-Item $FilePath}
    }
}

function Get-Pools {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Querymode,
        [Parameter(Mandatory = $false)]
        [array]$PoolsFilterList = $null,
        [Parameter(Mandatory = $false)]
        [array]$CoinFilterList,
        [Parameter(Mandatory = $false)]
        [string]$Location = $null,
        [Parameter(Mandatory = $false)]
        [array]$AlgoFilterList,
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Info
    )
    #in detail mode returns a line for each pool/algo/coin combination, in info mode returns a line for pool

    $PoolsFolderContent = Get-ChildItem ($PSScriptRoot + '\Pools\*') -File -Include '*.ps1' | Where-Object {$PoolsFilterList.Count -eq 0 -or (Compare-Object $PoolsFilterList $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}

    if ($null -eq $Info) { $Info = [PSCustomObject]@{}
    }

    if ($null -eq ($Info | Get-Member -MemberType NoteProperty | Where-Object name -eq location)) {$Info | Add-Member Location $Location}

    $Info | Add-Member SharedFile [string]$null

    $ChildItems = $PoolsFolderContent | ForEach-Object {

        $Basename = $_.BaseName
        $SharedFile = $PSScriptRoot + "\Cache\" + $Basename + [string](Get-Random -minimum 0 -maximum 9999999) + ".tmp"
        $Info.SharedFile = $SharedFile

        if (Test-Path $SharedFile) {Remove-Item $SharedFile}
        & $_.FullName -Querymode $Querymode -Info $Info
        if (Test-Path $SharedFile) {
            $Content = Get-Content $SharedFile | ConvertFrom-Json
            Remove-Item $SharedFile
        } else { $Content = $null }
        $Content | ForEach-Object {[PSCustomObject]@{Name = $Basename; Content = $_}}
    }

    $AllPools = $ChildItems | ForEach-Object {if ($_.Content) {$_.Content | Add-Member @{Name = $_.Name} -PassThru}}

    $AllPools | Add-Member LocationPriority 9999

    #Apply filters
    $AllPools2 = @()
    if ($Querymode -eq "Core" -or $Querymode -eq "Menu" ) {
        foreach ($Pool in $AllPools) {
            #must have wallet
            if (-not $Pool.User) {continue}

            # Include pool algos and coins
            if (
                (
                    $Config.("IncludeAlgos_" + $Pool.PoolName) -and
                    @($Config.("IncludeAlgos_" + $Pool.PoolName) -split ',') -notcontains $Pool.Algorithm
                ) -or (
                    $Config.("IncludeCoins_" + $Pool.PoolName) -and
                    @($Config.("IncludeCoins_" + $Pool.PoolName) -split ',') -notcontains $Pool.Info
                )
            ) {
                Log "Excluding $($Pool.Algorithm)/$($Pool.Info) on $($Pool.PoolName) due to Include filter" -Severity Debug
                continue
            }

            # Exclude pool algos and coins
            if (
                @($Config.("ExcludeAlgos_" + $Pool.PoolName) -split ',') -contains $Pool.Algorithm -or
                @($Config.("ExcludeCoins_" + $Pool.PoolName) -split ',') -contains $Pool.Info
            ) {
                Log "Excluding $($Pool.Algorithm)/$($Pool.Info) on $($Pool.PoolName) due to Exclude filter" -Severity Debug
                continue
            }

            #must be in algo filter list or no list
            if ($AlgoFilterList) {$Algofilter = Compare-Object $AlgoFilterList $Pool.Algorithm -IncludeEqual -ExcludeDifferent}
            if ($AlgoFilterList.count -eq 0 -or $Algofilter) {

                #must be in coin filter list or no list
                if ($CoinFilterList) {$CoinFilter = Compare-Object $CoinFilterList $Pool.info -IncludeEqual -ExcludeDifferent}
                if ($CoinFilterList.count -eq 0 -or $CoinFilter) {
                    if ($Pool.Location -eq $Location) {$Pool.LocationPriority = 1}
                    elseif ($Pool.Location -eq 'EU' -and $Location -eq 'US') {$Pool.LocationPriority = 2}
                    elseif ($Pool.Location -eq 'US' -and $Location -eq 'EU') {$Pool.LocationPriority = 2}

                    ## factor actual24h if price differs by factor of 10
                    if ($Pool.Actual24h) {
                        $factor = 0.2
                        if ($Pool.Price -gt ($Pool.Actual24h * 10)) {$Pool.Price = $Pool.Price * $factor + $Pool.Actual24h * (1 - $factor)}
                        if ($Pool.Price24h -gt ($Pool.Actual24h * 10)) {$Pool.Price24h = $Pool.Price24h * $factor + $Pool.Actual24h * (1 - $factor)}
                    }
                    ## Apply pool fees and pool factors
                    if ($Pool.Price) {
                        $Pool.Price *= 1 - [double]$Pool.Fee
                        $Pool.Price *= $(if ($Config."PoolProfitFactor_$($Pool.Name)") {[double]$Config."PoolProfitFactor_$($Pool.Name)"} else {1})
                    }
                    if ($Pool.Price24h) {
                        $Pool.Price24h *= 1 - [double]$Pool.Fee
                        $Pool.Price24h *= $(if ($Config."PoolProfitFactor_$($Pool.Name)") {[double]$Config."PoolProfitFactor_$($Pool.Name)"} else {1})
                    }
                    $AllPools2 += $Pool
                }
            }
        }
        $Return = $AllPools2
    } else { $Return = $AllPools }

    Remove-variable AllPools
    Remove-variable AllPools2

    $Return
}

function Get-Updates {
    try {
        $Request = Invoke-APIRequest -Url "https://api.github.com/repos/yuzi-co/$($Release.Application)/releases/latest" -Age 60
        $RemoteVersion = ($Request.tag_name -replace '[^\d.]')
        $Uri = $Request.assets | Where-Object Name -eq "$($Release.Application)-v$RemoteVersion.7z" | Select-Object -ExpandProperty browser_download_url

        if ([version]$RemoteVersion -gt [version]$Release.Version) {
            Log "$($Release.Application) v$($Release.Version) is out of date. There is an updated version available at $Uri" -Severity Warn
        } elseif ([version]$RemoteVersion -lt [version]$Release.Version) {
            Log "$($Release.Application) v$($Release.Version) is pre-release version. Use at your own risk" -Severity Warn
        }
    } catch {
        Log "Failed to get $($Release.Application) updates." -Severity Warn
    }
}

function Get-Config {

    $Result = @{}
    switch -regex -file config.ini {
        "^\s*(\w+)\s*=\s*(.*)" {
            $name, $value = $matches[1..2]
            $Result[$name] = switch -wildcard ($value.Trim()) {
                'enable*' {$true}
                'disable*' {$false}
                'on' {$true}
                'off' {$false}
                'yes' {$true}
                'no' {$false}
                Default {$value.Trim()}
            }
        }
    }
    $Result # Return Value
}

function Get-Wallets {

    $Result = @{}
    switch -regex -file config.ini {
        "^\s*WALLET_(\w+)\s*=\s*(.*)" {
            $name, $value = $matches[1..2]
            $Result[$name] = $value.Trim()
        }
    }
    $Result # Return Value
}

function Get-BestHashRateAlgo {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm
    )

    $Pattern = "*_" + $Algorithm + "_*_HashRate.csv"

    $BestHashRate = 0

    Get-ChildItem ($PSScriptRoot + "\Stats") -Filter $Pattern -File | ForEach-Object {
        $Content = ($_ | Get-Content | ConvertFrom-Csv )
        $Hrs = 0
        if ($null -ne $Content) {$Hrs = $($Content | Where-Object TimeSinceStartInterval -gt 60 | Measure-Object -property Speed -average).Average}

        if ($Hrs -gt $BestHashRate) {
            $BestHashRate = $Hrs
            $MinerName = ($_.pschildname -split '_')[0]
        }
        $Miner = [PSCustomObject]@{
            HashRate = $BestHashRate
            Miner    = $MinerName
        }
    }
    $Miner
}

function Set-ConsolePosition ([int]$x, [int]$y) {
    # Get current cursor position and store away
    $position = $host.ui.rawui.cursorposition
    # Store new X Co-ordinate away
    $position.x = $x
    $position.y = $y
    # Place modified location back to $HOST
    $host.ui.rawui.cursorposition = $position
    remove-variable position
}

function Get-ConsolePosition ([ref]$x, [ref]$y) {

    $position = $host.UI.RawUI.CursorPosition
    $x.value = $position.x
    $y.value = $position.y
    remove-variable position
}

function Out-HorizontalLine ([string]$Title) {

    $Width = $Host.UI.RawUI.WindowSize.Width
    if ([string]::IsNullOrEmpty($Title)) {$str = "-" * $Width}
    else {
        $str = '{white}' + ("-" * [math]::floor(($Width - $Title.Length - 4) / 2))
        $str += "{green}  " + $Title + "  "
        $str += '{white}' + ("-" * [math]::floor(($Width + 1 - $Title.Length - 4) / 2))
    }
    Write-Color $str
}

function Set-WindowSize ([int]$Width, [int]$Height) {
    #Buffer must be always greater than windows size

    $BSize = $Host.UI.RawUI.BufferSize
    if ($Width -ne 0 -and $Width -gt $BSize.Width) {$BSize.Width = $Width}
    if ($Height -ne 0 -and $Height -gt $BSize.Height) {$BSize.Width = $Height}

    $Host.UI.RawUI.BufferSize = $BSize

    $WSize = $Host.UI.RawUI.WindowSize
    if ($Width -ne 0) {$WSize.Width = $Width}
    if ($Height -ne 0) {$WSize.Height = $Height}

    $Host.UI.RawUI.WindowSize = $WSize
}

function Get-AlgoUnifiedName ([string]$Algo) {

    $Algo = $Algo -ireplace '[^\w]'
    if ($Algo) {
        $Algos = Get-Content -Path ".\Data\algorithms.json" | ConvertFrom-Json
        if ($Algos.$Algo) { $Algos.$Algo }
        else { $Algo }
    }
}

function Get-CoinUnifiedName ([string]$Coin) {

    if ($Coin) {
        $Coin = $Coin.Trim() -replace '[\s_]', '-'
        switch -wildcard ($Coin) {
            "Aur-*" { "Aurora" }
            "Auroracoin-*" { "Aurora" }
            "Bitcoin-*" { $_ -replace '-' }
            "Dgb-*" { "Digibyte" }
            "Digibyte-*" { "Digibyte" }
            "Ethereum-Classic" { "EthereumClassic" }
            "Haven-Protocol" { "Haven" }
            "Myriad-*" { "Myriad" }
            "Myriadcoin-*" { "Myriad" }
            "Shield-*" { "Verge" }
            "Verge-*" { "Verge" }
            Default { $Coin }
        }
    }
}

function Get-HashRates {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel
    )

    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}
    $Pattern = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_HashRate"

    if (-not (Test-Path -path "$Pattern.csv")) {
        if (Test-Path -path "$Pattern.txt") {
            $Content = (Get-Content -path "$Pattern.txt")
            try {$Content = $Content | ConvertFrom-Json} catch {
            } finally {
                if ($Content) {$Content | ConvertTo-Csv | Set-Content -Path "$Pattern.csv"}
                Remove-Item -path "$Pattern.txt"
            }
        }
    } else {
        $Content = (Get-Content -path "$Pattern.csv")
        try {
            $Content = $Content | ConvertFrom-Csv
        } catch {
            #if error from convert from json delete file
            Log "Corrupted file $Pattern.csv, deleting" -Severity Warn
            Remove-Item -path "$Pattern.csv"
        }
    }

    if ($Content) {
        $Content | ForEach-Object {
            $_.Speed = [decimal]$_.Speed
            $_.SpeedDual = [decimal]$_.SpeedDual
            $_.Power = [int]$_.Power

            if ($_.Activity) { $_.PSObject.Properties.Remove('Activity') }
            if ($_.Benchmarking) { $_.PSObject.Properties.Remove('Benchmarking') }
            if ($_.TimeSinceStartInterval) { $_.PSObject.Properties.Remove('TimeSinceStartInterval') }
            if ($_.BenchmarkIntervalTime) { $_.PSObject.Properties.Remove('BenchmarkIntervalTime') }
        }
    } else {
        $Content = @()
    }
    $Content
}

function Set-HashRates {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Value,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit
    )

    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}

    $Path = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_HashRate.csv"

    $Value | ConvertTo-Csv | Set-Content -Path $Path
}

function Get-Stats {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel
    )

    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}
    $Pattern = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_stats"

    if (-not (Test-Path -path "$Pattern.json")) {
        if (Test-Path -path "$Pattern.txt") {Rename-Item -Path "$Pattern.txt" -NewName "$Pattern.json"}
    } else {
        $Content = (Get-Content -path "$Pattern.json")
        try {$Content = $Content | ConvertFrom-Json} catch {
            #if error from convert from json delete file
            Log "Corrupted file $Pattern.json, deleting" -Severity Warn
            Remove-Item -path "$Pattern.json"
        }
    }
    $Content
}

function Set-Stats {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$value,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit
    )

    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}

    $Path = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_stats.json"

    $Value | ConvertTo-Json | Set-Content -Path $Path
}

function Start-Downloader {
    param(
        [Parameter(Mandatory = $true)]
        [String]$URI,
        [Parameter(Mandatory = $true)]
        [String]$ExtractionPath,
        [Parameter(Mandatory = $true)]
        [String]$Path,
        [Parameter(Mandatory = $false)]
        [String]$SHA256
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        try {
            if ($URI -and (Split-Path $URI -Leaf) -eq (Split-Path $Path -Leaf)) {
                # downloading a single file
                $null = New-Item (Split-Path $Path) -ItemType "Directory"
                (New-Object System.Net.WebClient).DownloadFile($URI, $Path)
                if ($SHA256 -and (Get-FileHash -Path $Path -Algorithm SHA256).Hash -ne $SHA256) {
                    Log "File hash doesn't match. Removing file." -Severity Warn
                    Remove-Item $Path
                }
            } else {
                # downloading an archive or installer
                Log "Downloading $URI" -Severity Info
                Expand-WebRequest -URI $URI -Path $ExtractionPath -SHA256 $SHA256 -ErrorAction Stop
            }
        } catch {
            $Message = "Cannot download $URI"
            Log $Message -Severity Warn
        }
    }
}

function Clear-Files {

    $Now = Get-Date
    $Days = "3"

    $TargetFolder = ".\Logs"
    $Extension = "*.log"
    $LastWrite = $Now.AddDays( - $Days)
    $Files = Get-Childitem $TargetFolder -Include $Extension -Exclude "empty.txt" -File -Recurse | Where-Object {$_.LastWriteTime -le "$LastWrite"}
    $Files | ForEach-Object {Remove-Item $_.fullname}

    $TargetFolder = "."
    $Extension = "wrapper_*.txt"
    $Files = Get-Childitem $TargetFolder -Include $Extension -File -Recurse
    $Files | ForEach-Object {Remove-Item $_.fullname}

    $TargetFolder = "."
    $Extension = "*.tmp"
    $Files = Get-Childitem $TargetFolder -Include $Extension -File -Recurse
    $Files | ForEach-Object {Remove-Item $_.fullname}

    $TargetFolder = ".\Cache"
    $Extension = "*.json"
    $LastWrite = $Now.AddDays( - $Days)
    $Files = Get-Childitem $TargetFolder -Include $Extension -Exclude "empty.txt" -File -Recurse | Where-Object {$_.LastWriteTime -le "$LastWrite"}
    $Files | ForEach-Object {Remove-Item $_.fullname}
}

function Get-CoinSymbol ([string]$Coin) {
    $Coin = $Coin -ireplace '[^\w]'
    if ($Coin) {
        $Coins = Get-Content -Path ".\Data\coins.json" | ConvertFrom-Json
        if ($Coins.$Coin) { $Coins.$Coin }
        else { $Coin }
    }
}

function Test-DeviceGroupsConfig ($Types) {
    $Devices = Get-DevicesInformation $Types
    $Types | Where-Object GroupType -ne 'CPU' | ForEach-Object {
        $DetectedDevices = @()
        $DetectedDevices += $Devices | Where-Object GroupName -eq $_.GroupName
        if ($DetectedDevices.Count -eq 0) {
            Log ("No Devices for group " + $_.GroupName + " was detected, activity based watchdog will be disabled for that group, this happen with AMD beta blockchain drivers, no Afterburner or incorrect GpuGroups config") -Severity Warn
            Start-Sleep -Seconds 5
        } elseif ($DetectedDevices.Count -ne $_.DevicesCount) {
            Log ("Mismatching Devices for group " + $_.GroupName + " was detected, check GpuGroups config and DeviceList.bat output") -Severity Warn
            Start-Sleep -Seconds 5
        }
    }
    $TotalMem = (($Types | Where-Object GroupType -ne 'CPU').OCLDevices.GlobalMemSize | Measure-Object -Sum).Sum / 1GB
    $TotalSwap = (Get-CimInstance Win32_PageFile | Select-Object -ExpandProperty FileSize | Measure-Object -Sum).Sum / 1GB
    if ($TotalMem -gt $TotalSwap) {
        Log "Make sure you have at least $TotalMem GB swap configured" -Severity Warn
        Start-Sleep -Seconds 5
    }
}

function Start-Autoexec {
    [cmdletbinding()]
    param(
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0
    )
    if (-not (Test-Path ".\Autoexec.txt") -and (Test-Path ".\Data\Autoexec.default.txt")) {Copy-Item ".\Data\Autoexec.default.txt" ".\Autoexec.txt" -Force -ErrorAction Ignore}
    [System.Collections.ArrayList]$Script:AutoexecCommands = @()
    foreach ($cmd in @(Get-Content ".\Autoexec.txt" -ErrorAction Ignore | Select-Object)) {
        if ($cmd -match "^[\s\t]*`"(.+?)`"(.*)$") {
            try {
                $Job = Start-SubProcess -FilePath "$($Matches[1])" -ArgumentList "$($Matches[2].Trim())" -WorkingDirectory (Split-Path "$($Matches[1])") -Priority $Priority
                if ($Job) {
                    $Job | Add-Member FilePath "$($Matches[1])" -Force
                    $Job | Add-Member Arguments "$($Matches[2].Trim())" -Force
                    $Job | Add-Member HasOwnMinerWindow $true -Force
                    Log "Autoexec command started: $($Matches[1]) $($Matches[2].Trim())" -Severity Info
                    $Script:AutoexecCommands.Add($Job) | Out-Null
                }
            } catch {}
        }
    }
}

function Stop-Autoexec {
    $Script:AutoexecCommands | Where-Object Process | Foreach-Object {
        Stop-SubProcess -Job $_ -Title "Autoexec command" -Name "$($_.FilePath) $($_.Arguments)"
    }
}

function Write-Color() {
    Param (
        [string] $text = $(Write-Error "You must specify some text"),
        [switch] $NoNewLine = $false
    )

    $startColor = $Host.UI.RawUI.ForegroundColor;

    $text.Split( [char]"{", [char]"}" ) | ForEach-Object { $i = 0; } {
        if ($i % 2 -eq 0) {
            Write-Host $_ -NoNewline;
        } else {
            if ([enum]::GetNames("ConsoleColor") -contains $_) {
                $Host.UI.RawUI.ForegroundColor = ($_ -as [System.ConsoleColor]);
            }
        }

        $i++;
    }

    if (-not $NoNewLine) {
        Write-Host
    }
    $Host.UI.RawUI.ForegroundColor = $startColor;
}
