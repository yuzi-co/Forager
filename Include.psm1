### Hardware

function Get-DevicesInfoAfterburner {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Types
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
                UtilizationMem    = [int]$($mem = $CardData | Where-Object SrcName -match "^(GPU\d* )?memory usage$"; if ($mem.MaxLimit) { $mem.Data / $mem.MaxLimit * 100 })
                Clock             = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?core clock$").Data
                ClockMem          = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?memory clock$").Data
                FanSpeed          = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?fan speed$").Data
                Temperature       = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?temperature$").Data
                PowerDraw         = [int]$($CardData | Where-Object { $_.SrcName -match "^(GPU\d* )?power$" -and $_.SrcUnits -eq 'W' }).Data
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
        [Parameter(Mandatory = $true)]
        [array]$Types
    )
    if ($IsWindows) {

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
        $Command = "./Includes/OverdriveN.exe"
        $Result = & $Command | Where-Object { $_ -notlike "*&???" -and $_ -notlike "*failed" } | ConvertFrom-Csv @CsvParams

        if (-not $global:AmdCardsTDP) {
            $global:AmdCardsTDP = Get-Content ./Data/amd-cards-tdp.json | ConvertFrom-Json
        }

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
}

function Get-DevicesInfoNvidiaSmi {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Types
    )

    $Params = @{
        Query = @(
            "gpu_name"
            "utilization.gpu"
            "utilization.memory"
            "temperature.gpu"
            "power.draw"
            "power.limit"
            "fan.speed"
            "pstate"
            "clocks.current.graphics"
            "clocks.current.memory"
            "power.max_limit"
            "power.default_limit"
        )
    }
    $Result = Invoke-NvidiaSmi @Params

    $DeviceId = 0
    $Devices = $Result | Where-Object { $_.pstate } | ForEach-Object {
        $GroupName = ($Types | Where-Object DevicesArray -contains $DeviceId).GroupName

        $Card = [PSCustomObject]@{
            GroupName         = $GroupName
            GroupType         = 'NVIDIA'
            Id                = $DeviceId
            Name              = $_.gpu_name
            Utilization       = [int]$(if ($_.utilization_gpu) { $_.utilization_gpu } else { 100 }) #If we dont have real Utilization, at least make the watchdog happy
            UtilizationMem    = [int]$($_.utilization_memory)
            Temperature       = [int]$($_.temperature_gpu)
            PowerDraw         = [int]$($_.power_draw)
            PowerLimit        = [int]$($_.power_limit)
            FanSpeed          = [int]$($_.fan_speed)
            Pstate            = $_.pstate
            Clock             = [int]$($_.clocks_current_graphics)
            ClockMem          = [int]$($_.clocks_current_memory)
            PowerMaxLimit     = [int]$($_.power_max_limit)
            PowerDefaultLimit = [int]$($_.power_default_limit)
        }
        if ($Card.PowerDefaultLimit -gt 0) { $Card | Add-Member PowerLimitPercent ([int](($Card.PowerLimit * 100) / $Card.PowerDefaultLimit)) }
        $Card
        $DeviceId++
    }
    @($Devices)
}

function Get-DevicesInfoCPU {

    if ($abMonitor) {
        $CpuData = @{
            Clock       = $($abMonitor.Entries | Where-Object SrcName -match '^(CPU\d* )clock' | Measure-Object -Property Data -Maximum).Maximum
            Utilization = $($abMonitor.Entries | Where-Object SrcName -match '^(CPU\d* )usage' | Measure-Object -Property Data -Average).Average
            PowerDraw   = $($abMonitor.Entries | Where-Object SrcName -eq 'CPU power').Data
            Temperature = $($abMonitor.Entries | Where-Object SrcName -match "^(CPU\d* )temperature" | Measure-Object -Property Data -Maximum).Maximum
        }
    } else {
        $CpuData = @{ }
    }

    $Devices = if ($IsWindows) {
        $CpuResult = @(Get-CimInstance Win32_Processor)
        $CpuResult | ForEach-Object {
            if (-not $CpuData.Utilization) {
                # Get-Counter is more accurate and is preferable, but currently not available in Poweshell 6
                if (Get-Command "Get-Counter" -Type Cmdlet -ErrorAction Ignore) {
                    # Language independent version of Get-Counter '\Processor(_Total)\% Processor Time'
                    try {
                        $CpuData.Utilization = (Get-Counter -Counter '\238(_Total)\6').CounterSamples.CookedValue
                    } catch { $CpuData.Utilization = $_.LoadPercentage }
                } else {
                    $CpuData.Utilization = $_.LoadPercentage
                }
            }
            if (-not $CpuData.PowerDraw) {
                if (-not $global:CpuTDP) {
                    $global:CpuTDP = Get-Content ./Data/cpu-tdp.json | ConvertFrom-Json
                }
                $CpuData.PowerDraw = $CpuTDP.($_.Name.Trim()) * $CpuData.Utilization / 100
            }
            if (-not $CpuData.Clock) { $CpuData.Clock = $_.MaxClockSpeed }
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
    } else {
        $Features = Get-CpuFeatures
        if (-not $global:CpuTDP) {
            $global:CpuTDP = Get-Content ./Data/cpu-tdp.json | ConvertFrom-Json
        }

        [int]$CpuData.Utilization = [math]::min((((& ps -A -o pcpu) -match "\d" | Measure-Object -Sum).Sum / $Features.Threads), 100)
        [int]$CpuData.PowerDraw = $CpuTDP.($Features.Name) * $CpuData.Utilization / 100
        [PSCustomObject]@{
            GroupName   = 'CPU'
            GroupType   = 'CPU'
            Id          = 0
            Name        = $Features.Name
            Cores       = $Features.Cores
            Threads     = $Features.Threads
            CacheL3     = $Features.CacheL3 / 1024
            Clock       = $Features.Clock
            Utilization = $CpuData.Utilization
            PowerDraw   = $CpuData.PowerDraw
        }
    }
    @($Devices)
}

function Get-DevicesInformation {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Types
    )
    if ($abMonitor) { $abMonitor.ReloadAll() }
    if ($abControl) { $abControl.ReloadAll() }

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
        Get-DevicesInfoNvidiaSmi -Types ($Types | Where-Object GroupType -eq 'NVIDIA')
    }

    # CPU
    if ($Types | Where-Object GroupType -eq 'CPU') {
        Get-DevicesInfoCPU
    }
}

function Out-DevicesInformation {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Devices
    )

    $Devices | Where-Object GroupType -ne 'CPU' | Sort-Object GroupType | Format-Table -Wrap (
        @{Label = "Id"; Expression = { $_.Id }; Align = 'right' },
        @{Label = "Group"; Expression = { $_.GroupName }; Align = 'right' },
        @{Label = "Name"; Expression = { $_.Name } },
        @{Label = "Load"; Expression = { [string]$_.Utilization + "%" }; Align = 'right' },
        @{Label = "Power"; Expression = { [string]$_.PowerDraw + "W" }; Align = 'right' },
        @{Label = "Temp"; Expression = { $_.Temperature }; Align = 'right' },
        @{Label = "Clock"; Expression = { [string]$_.Clock + "Mhz" }; Align = 'right' },
        @{Label = "ClkMem"; Expression = { [string]$_.ClockMem + "Mhz" }; Align = 'right' },
        @{Label = "Mem"; Expression = { [string]$_.UtilizationMem + "%" }; Align = 'right' },
        @{Label = "Fan"; Expression = { [string]$_.FanSpeed + "%" }; Align = 'right' },
        @{Label = "PwLim"; Expression = { [string]$_.PowerLimitPercent + '%' }; Align = 'right' },
        @{Label = "Pstate"; Expression = { $_.pstate }; Align = 'right' }
    ) -GroupBy GroupType | Out-Host

    $Devices | Where-Object GroupType -eq 'CPU' | Format-Table -Wrap (
        @{Label = "Id"; Expression = { $_.Id }; Align = 'right' },
        @{Label = "Group"; Expression = { $_.GroupName }; Align = 'right' },
        @{Label = "Name"; Expression = { $_.Name } },
        @{Label = "Load"; Expression = { [string]$_.Utilization + "%" }; Align = 'right' },
        @{Label = "Power"; Expression = { [string]$_.PowerDraw + "W" }; Align = 'right' },
        @{Label = "Temp"; Expression = { $_.Temperature }; Align = 'right' },
        @{Label = "Clock"; Expression = { [string]$_.Clock + "Mhz" }; Align = 'right' },
        @{Label = "Cores"; Expression = { $_.Cores } },
        @{Label = "Threads"; Expression = { $_.Threads } },
        @{Label = "CacheL3"; Expression = { [string]$_.CacheL3 + "MB" }; Align = 'right' }
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
                    PlatformId  = $null
                    DeviceIndex = 0
                    Name        = 'CPU'
                    Vendor      = 'Generic'
                    Type        = 'Cpu'
                }
            }
        }
        if ($GroupType -eq 'NVIDIA' -and -not $DeviceList) {
            $DeviceList = Get-NvidiaSmiDevices
        }

        $DeviceList | Group-Object @GroupBy | ForEach-Object {
            if ($_.Group) {
                $Devices = $_.Group | Select-Object -Property PlatformId, Name, Vendor, GlobalMemSize, MaxComputeUnits -First 1
                $GroupName = $GroupType
                if ($Config.GroupGpuByType -and $GroupType -ne 'CPU') {
                    $GroupName = $Devices.Name -replace "[^\w]"
                    if ($GroupType -eq 'AMD') {
                        $GroupName += '_' + $Devices.MaxComputeUnits + 'cu' + [int]($Devices.GlobalMemSize / 1GB) + 'gb'
                    }
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

function Get-NvidiaSmiDevices {

    $Params = @{
        Query = @(
            "index"
            "gpu_name"
            "memory.total"
        )
    }
    $SmiDevices = Invoke-NvidiaSmi @Params

    $DeviceList = $SmiDevices | Where-Object {$_.gpu_name} | ForEach-Object {
        @{
            Type          = 'Gpu'
            Vendor        = 'NVIDIA'
            PlatformId    = $null
            DeviceIndex   = [int]$_.index
            GlobalMemSize = [int]$_.memory_total * 1MB
            Name          = $_.gpu_name
        }
    }

    @($DeviceList)
}

function Get-OpenCLDevices {

    if (-not ('OpenCl.Platform' -as [Type])) {
        Add-Type -Path ./Includes/OpenCL/*.cs
    }
    try {
        $OCLPlatforms = [OpenCl.Platform]::GetPlatformIds()
    } catch {
        Log "Error during OpenCL platform detection!" -Severity Debug
    }
    if ($null -ne $OCLPlatforms) {
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
    } else {
        Log "No OpenCL devices detected!" -Severity Debug
    }

    $OCLDevices
}

function Get-CpuFeatures {
    if ($IsWindows) {
        $Features = $($feat = @{ }; switch -regex ((& "$PSScriptRoot/Includes/CHKCPU32.exe" /x) -split "</\w+>") { "^\s*<_?(\w+)>(\d+).*" { $feat.($matches[1]) = [int]$matches[2] } }; $feat)
    } elseif ($IsLinux) {
        $Data = Get-Content /proc/cpuinfo
        $Features = $($feat = @{ }; (($Data | Where-Object { $_ -like "flags*" })[0] -split ":")[1].Trim() -split " " | ForEach-Object { $feat.$_ = 1 }; $feat)
        $Features.threads = [int]($Data | Where-Object { $_ -like 'processor*' }).count
        $Features.cores = [int](($Data | Where-Object { $_ -like 'cpu cores*' })[0] -split ":")[1].Trim()
        $Features.name = (($Data | Where-Object { $_ -like 'model name*' })[0] -split ":")[1].Trim()
        $Features.cachel3 = ((($Data | Where-Object { $_ -like 'cache size*' })[0] -split ":")[1].Trim() -split " ")[0].Trim()
        $Features.clock = [int](($Data | Where-Object { $_ -like 'cpu MHz*' })[0] -split ":")[1].Trim()
    }
    return $Features
}

function Get-MiningTypes () {
    param(
        [Parameter(Mandatory = $false)]
        [array]$Filter = @(),
        [Parameter(Mandatory = $false)]
        [switch]$All = $false
    )

    if ($Config.ContainsKey('GpuGroups') -and -not $All) {
        # GpuGroups not empty, parse it
        if ($Config.GpuGroups.Length -gt 0) {
            [array]$Devices = $Config.GpuGroups | ConvertFrom-Json
        }
    } else {
        # Autodetection on
        [array]$Devices = Get-Devices -Types AMD, NVIDIA
    }
    if ($Config.CpuMining -or $All) {
        [array]$Devices += Get-Devices -Types CPU
    }

    $Devices | ForEach-Object {
        if ($null -eq $_.Enabled) { $_ | Add-Member Enabled $true }
    }

    if ($Devices | Where-Object { $_.GroupType -eq 'CPU' }) {

        $Features = Get-CpuFeatures
        $Devices | Where-Object { $_.GroupType -eq 'CPU' } | ForEach-Object {
            $_ | Add-Member Devices "0" -Force
            $_ | Add-Member Features $Features
            if ($Features.Name -and (-not $_.Name -or $_.Name -eq 'CPU')) {
                $_ | Add-Member Name $Features.Name -Force
            }
        }
    }

    $OCLDevices = Get-OpenCLDevices
    $NvidiaDevices = Get-NvidiaSmiDevices

    $TypeID = 0
    $DeviceGroups = $Devices | ForEach-Object {
        if (-not $Filter -or $Filter -contains $_.GroupName) {

            $_ | Add-Member ID $TypeID
            $TypeID++

            $_ | Add-Member DevicesArray @([int[]]($_.Devices -split ',' | ForEach-Object { $_.Trim() }))   # @(0,1,2,10,11,12)
            $_ | Add-Member DevicesCount ($_.DevicesArray.count)             # 6

            $Pattern = switch ($_.GroupType) {
                'AMD' { @('Advanced Micro Devices, Inc.') }
                'NVIDIA' { @('NVIDIA Corporation') }
                'INTEL' { @('Intel(R) Corporation') }
                'CPU' { @('GenuineIntel', 'AuthenticAMD') }
            }
            $OCLDevice = @($OCLDevices | Where-Object { $Pattern -contains $_.Vendor })[$_.DevicesArray]
            if ($OCLDevice) {
                if ($null -eq $_.PlatformId) { $_ | Add-Member PlatformId ($OCLDevice.PlatformId | Select-Object -First 1) }
                if ($null -eq $_.MemoryGB) { $_ | Add-Member MemoryGB ([math]::Round((($OCLDevice | Measure-Object -Property GlobalMemSize -Minimum).Minimum / 1GB ), 2)) }
                $_ | Add-Member OCLDeviceId @($OCLDevice.OCLDeviceId)
                $_ | Add-Member OCLGpuId @($OCLDevice.OCLGpuId)
            } elseif ($_.GroupType -eq 'NVIDIA') {
                if ($null -eq $_.MemoryGB) { $_ | Add-Member MemoryGB ([math]::Round(((@($NvidiaDevices)[$_.DevicesArray] | Measure-Object -Property GlobalMemSize -Minimum).Minimum / 1GB ), 2)) }
            }

            if ($_.PowerLimits -is [string] -and $_.PowerLimits.Length -gt 0) {
                $_ | Add-Member PowerLimits @([int[]]($_.PowerLimits -split ',' | ForEach-Object { $_.Trim() } ) | Sort-Object -Descending -Unique) -Force
            } else {
                $_ | Add-Member PowerLimits @(0) -Force
            }

            if ($_.GroupType -eq 'AMD' -and -not $abControl) {
                $_ | Add-Member PowerLimits @(0) -Force
            }

            $_ | Add-Member MinProfit ([decimal]$Config.("MinProfit_" + $_.GroupName))
            $_ | Add-Member Algorithms @($Config.("Algorithms_" + $_.GroupName) -split ',' | ForEach-Object { $_.Trim() })

            $ApiPorts = @{
                'AMD'    = 4028
                'CPU'    = 4048
                'NVIDIA' = 4068
            }

            $_ | Add-Member ApiPort $($ApiPorts.($_.GroupType) + [array]::indexof(@($Devices | Where-Object GroupType -eq $_.GroupType), $_))

            $_ #return
        }
    }
    return $DeviceGroups
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
        $Devices = @($List -split ',')
    }

    switch ($Type) {
        Clay { ($Devices | ForEach-Object { '{0:X}' -f $_ }) -join '' }  # 012ABC
        Nsg { ($Devices | ForEach-Object { "-d " + $_ }) -join ' ' }     # -d 0 -d 1 -d 2 -d 10 -d 11 -d 12
        Eth { $Devices -join ' ' }                                       # 0 1 2 10 11 12
        Count { $Devices.count }                                         # 6
        Mask { '{0:X}' -f [int]($Devices | ForEach-Object { [System.Math]::Pow(2, $_) } | Measure-Object -Sum).Sum }
    }
}

function Set-OsFlags {
    if ($null -eq $IsWindows) {
        # Define flags for non-Core Powershell
        if ([System.Environment]::OSVersion.Platform -eq "Win32NT") {
            # Just making sure, since only Windows has non-Core Poweshell
            $Global:IsWindows = $true
            $Global:IsLinux = $false
            $Global:IsMacOS = $false
        }
    }
}

function Test-Admin {
    $Result = switch ($PSVersionTable.Platform) {
        'Win32NT' { (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) }
        'Unix' { [bool]((id -u) -eq 0) }
    }
    $Result
}

function Get-NvidiaSmi {

    if ($IsLinux -or (Get-Command "nvidia-smi" -ErrorAction Ignore)) {
        $Command = "nvidia-smi"
    } elseif ($IsWindows) {
        $Command = "./Includes/nvidia-smi.exe"
    }
    if ($Command) {
        (Get-Command $Command).Source
    }
}

function Invoke-NvidiaSmi {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $False)]
        [String[]]$Query = @(),
        [Parameter(Mandatory = $False)]
        [String[]]$Arguments = @(),
        [Parameter(Mandatory = $False)]
        [Switch]$Runas
    )

    if (-not ($NVSMI = Get-NvidiaSmi)) { return }

    if ($Query) {
        $Arguments += @(
            "--query-gpu=$($Query -join ',')"
            "--format=csv,noheader,nounits"
        )
        $CsvParams = @{
            Header = @(
                $Query | Foreach-Object { $_ -replace "[^a-z_-]", "_" -replace "_+", "_" } | Select-Object
            )
        }
        & $NVSMI $Arguments | ConvertFrom-Csv @CsvParams | Foreach-Object {
            $obj = $_
            $obj.PSObject.Properties.Name | Foreach-Object {
                $v = $obj.$_
                if ($v -match '(error|supported)') { $v = $null }
                elseif ($_ -match "^(clocks|fan|index|memory|temperature|utilization)") {
                    $v = $v -replace "[^\d\.]"
                    if ($v -notmatch "^(\d+|\.\d+|\d+\.\d+)$") { $v = $null }
                    else { $v = [int]$v }
                } elseif ($_ -match "^(power)") {
                    $v = $v -replace "[^\d\.]"
                    if ($v -notmatch "^(\d+|\.\d+|\d+\.\d+)$") { $v = $null }
                    else { $v = [double]$v }
                }
                $obj.$_ = $v
            }
            $obj
        }
    } elseif ($RunAs) {
        $SMIProcess = New-Object System.Diagnostics.ProcessStartInfo $NVSMI
        $SMIProcess.Verb = "runas"
        $SMIProcess.Arguments = $Arguments -join " "
        [System.Diagnostics.Process]::Start($SMIProcess) | Out-Null
        if ($SMIProcess) { Remove-Variable SMIProcess }
    } else {
        & $NVSMI $Arguments
    }
}

function Get-CudaVersion {
    $Ver = Invoke-NvidiaSmi | Where-Object { $_ -match "CUDA Version: (\d+\.\d+)" } | ForEach-Object { $Matches[1] } | Select-Object -First 1
    if (-not $Ver) {
        # try OpenCL detection
        $OclDevices = Get-OpenCLDevices | Where-Object { $_.Type -eq 'Gpu' -and $_.Vendor -like 'NVIDIA*' }
        if ($OclDevices -and $OclDevices[0].Platform.Version -match "CUDA\s+(\d\+.\d+)") {
            $Ver = $Matches[1]
        }
    }
    if ($Ver) {
        [version]"$Ver.0"
    }
}

function Get-SystemInfo () {
    $Features = Get-CpuFeatures
    $CudaVersion = Get-CudaVersion

    $SystemInfo = [PSCustomObject]@{
        OSName       = [System.Environment]::OSVersion.Platform
        OSVersion    = [System.Environment]::OSVersion.Version
        ComputerName = [System.Environment]::MachineName
        Processors   = [System.Environment]::ProcessorCount
        CpuFeatures  = $Features
        CudaVersion  = $CudaVersion
    }
    if ($IsWindows) {
        $SystemInfo.ComputerName = (Get-Culture).TextInfo.ToTitleCase($SystemInfo.ComputerName.ToLower()) #Windows capitalizes this
    }

    return $SystemInfo
}

function Test-DeviceGroupsConfig ($Types) {
    if ($IsWindows) {
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
}

function Set-NvidiaPowerLimit {
    param(
        [int]$PowerLimitPercent,

        [validaterange(50, 150)]
        [int]$PowerLimitWatt,

        [parameter(mandatory = $true)]
        [string]$Devices
    )

    if (-not $IsAdmin) {
        Log "To change PowerLimits you must to run Forager as Admin/Sudo" -Severity Warn
        return
    }

    foreach ($Device in @($Devices -split ',')) {
        $Params = @{
            Arguments = @(
                "--id=$Device"
            )
            Query     = @(
                "power.default_limit"
                "power.min_limit"
                "power.max_limit"
                "power.limit"
            )
        }
        $Limits = Invoke-NvidiaSmi @Params

        if ($PowerLimitPercent -gt 0) {
            $PLim = [int]($PowerLimitPercent / 100 * [int]$Limits.power_default_limit)
        } elseif ($PowerLimitWatt -gt 0) {
            $PLim = [int]$PowerLimitWatt
        }
        $PLim = [math]::max($PLim, [int]$Limits.power_min_limit)
        $PLim = [math]::min($PLim, [int]$Limits.power_max_limit)

        if ($PLim -ne [int]$Limits.power_limit) {
            #powerlimit change must run in admin mode
            $Params = @{
                Arguments = @(
                    "--id=$Device"
                    "--power-limit=$PLim"
                )
                Runas     = $true
            }

            Invoke-NvidiaSmi @Params
        }
    }
}



### Miners

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

function Get-LiveHashRate {
    param(
        [Parameter(Mandatory = $true)]
        [Object]$Miner
    )

    $HashRate = $Shares = @($null, $null)

    try {
        switch ($Miner.Api) {

            "xgminer" {
                $Message = @{command = "summary"; parameter = "" } | ConvertTo-Json -Compress
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request $Message -Quiet

                if ($Request) {
                    $Data = $Request.Substring($Request.IndexOf("{"), $Request.LastIndexOf("}") - $Request.IndexOf("{") + 1) | ConvertFrom-Json

                    $HashRate = @(
                        [double]$Data.SUMMARY."HS 5s"
                        [double]$Data.SUMMARY."MHS 5s" * 1e6
                        [double]$Data.SUMMARY."KHS 5s" * 1e3
                        [double]$Data.SUMMARY."GHS 5s" * 1e9
                        [double]$Data.SUMMARY."THS 5s" * 1e12
                        [double]$Data.SUMMARY."PHS 5s" * 1e15
                    ) | Where-Object { $_ -gt 0 } | Select-Object -First 1

                    if (-not $HashRate) {
                        $HashRate = @(
                            [double]$Data.SUMMARY."HS av"
                            [double]$Data.SUMMARY."MHS av" * 1e6
                            [double]$Data.SUMMARY."KHS av" * 1e3
                            [double]$Data.SUMMARY."GHS av" * 1e9
                            [double]$Data.SUMMARY."THS av" * 1e12
                            [double]$Data.SUMMARY."PHS av" * 1e15
                        ) | Where-Object { $_ -gt 0 } | Select-Object -First 1
                    }
                    $Shares = @(
                        [int]$Data.SUMMARY.Accepted
                        [int]$Data.SUMMARY.Rejected
                    )
                }
            }

            "ccminer" {
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request "summary" -Quiet
                if ($Request) {
                    $Data = $Request -split ";" | ConvertFrom-StringData
                    $HashRate = @(
                        [double]$Data.HS
                        [double]$Data.KHS * 1e3
                        [double]$Data.MHS * 1e6
                        [double]$Data.GHS * 1e9
                        [double]$Data.THS * 1e12
                        [double]$Data.PHS * 1e15
                    ) | Where-Object { $_ -gt 0 } | Select-Object -First 1
                    $Shares = @(
                        [int64]$Data.ACC
                        [int64]$Data.REJ
                    )
                }
            }

            "ewbf" {
                $Message = @{id = 1; method = "getstat" } | ConvertTo-Json -Compress
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request $Message -Quiet
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double](($Data.result.speed_sps) | Measure-Object -Sum).Sum
                }
            }

            "Claymore" {
                $Message = @{id = 0; jsonrpc = "2.0"; method = "miner_getstat1" } | ConvertTo-Json -Compress
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request $Message -Quiet
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
                    $R = $Data.result[2].Split(";")
                    $S = $Data.result[4].Split(";")
                    $HashRate = @(
                        [double]$Multiplier * $R[0]
                        [double]$Multiplier * $S[0]
                    )
                    $Shares = @(
                        [int64]$R[1]
                        [int64]$R[2]
                        $(if ($HashRate[1] -gt 0) {
                                [int64]$S[1]
                                [int64]$S[2]
                            })
                    )
                }
            }

            "wrapper" {
                $wrpath = "./Wrapper_$($Miner.ApiPort).txt"
                $HashRate = [double]$(if (Test-Path -path $wrpath) { Get-Content $wrpath } else { 0 })
            }

            "castXMR" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]($Data.devices.hash_rate | Measure-Object -Sum).Sum / 1000
                    $Shares = @(
                        [int64]$Data.shares.num_accepted
                        [int64]$Data.shares.num_rejected + [int64]$Data.shares.num_rejected + [int64]$Data.shares.num_network_fail + [int64]$Data.shares.num_outdated
                    )
                }
            }

            "XMrig" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort -Path "/api.json"
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]$Data.hashrate.total[0]
                    if ($Data.algo -eq 'WildKeccak') {
                        $HashRate *= 1000
                    }
                    $Shares = @(
                        [int64]$Data.results.shares_good
                        [int64]$Data.results.shares_total - [int64]$Data.results.shares_good
                    )
                }
            }

            "BMiner" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort -Path "/api/v1/status/solver"
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = $Data.devices |
                    Get-Member -MemberType NoteProperty |
                    ForEach-Object { $Data.devices.($_.name).solvers } |
                    Group-Object algorithm |
                    ForEach-Object {
                        @(
                            $_.group.speed_info.hash_rate | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                            $_.group.speed_info.solution_rate | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                        ) | Where-Object { $_ -gt 0 }
                    }
                }
                if ($HashRate -ne $null) {
                    $Request = Invoke-HTTPRequest -Port $Miner.ApiPort -Path "/api/v1/status/stratum"
                    if ($Request) {
                        $Data = $Request | ConvertFrom-Json
                        $Shares = $Data.stratums |
                        Get-Member -MemberType NoteProperty |
                        ForEach-Object {
                            @(
                                $Data.stratums.($_.name).accepted_shares
                                $Data.stratums.($_.name).rejected_shares
                            )
                        }
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
                    ) | Where-Object { $_ -gt 0 } | Select-Object -First 1
                    $Shares = @(
                        [int64]$Data.shares.accepted
                        [int64]$Data.shares.rejected
                    )
                }
            }

            "JCE" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]$Data.HashRate.total
                    $Shares = @(
                        [int64]$Data.results.shares_good
                        [int64]$Data.results.shares_total - [int64]$Data.results.shares_good
                    )
                }
            }

            "LOL" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort -Path "/summary"
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]$Data.Session.Performance_Summary
                    $Shares = @(
                        [int64]$Data.Session.Accepted
                        [int64]$Data.Session.Submitted - [int64]$Data.Session.Accepted
                    )
                }
            }

            "MiniZ" {
                $Message = '{"id":"0", "method":"getstat"}'
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request $Message -Quiet
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double](($Data.result.speed_sps) | Measure-Object -Sum).Sum
                    $Shares = @(
                        [int64]($Data.result.accepted_shares | Measure-Object -Sum).Sum
                        [int64]($Data.result.rejected_shares | Measure-Object -Sum).Sum
                    )
                }
            }

            "GMiner" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort -Path "/stat"
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double](($Data.devices.speed) | Measure-Object -Sum).Sum
                    $Shares = @(
                        [int64]$($Data.devices.accepted_shares | Measure-Object -Sum).Sum
                        [int64]$($Data.devices.rejected_shares | Measure-Object -Sum).Sum
                    )
                }
            }

            "Mkx" {
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request 'stats' -ReadToEnd -Quiet
                if ($Request) {
                    $Data = $Request.Substring($Request.IndexOf("{"), $Request.LastIndexOf("}") - $Request.IndexOf("{") + 1) | ConvertFrom-Json
                    $HashRate = [double]$Data.gpus.hashrate * 1e6
                }
            }

            "Luk" {
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -ReadToEnd -Quiet
                if ($Request) {
                    $Data = $Request -replace 'LOG:' | ConvertFrom-StringData
                    $HashRate = [double]$Data.hash_rate
                    $Shares = @(
                        [int64]$Data.num_shares_accepted
                    )
                }
            }

            "GrinPro" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort -Path "/api/status"
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double](($Data.workers.graphsPerSecond) | Measure-Object -Sum).Sum
                    $Shares = @(
                        [int64]$Data.shares.accepted
                        [int64]$Data.shares.submitted - [int64]$Data.shares.accepted
                    )
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
                    $Shares = @(
                        [int64]$Data.stratum.accepted_shares
                        [int64]$Data.stratum.rejected_shares
                    )
                }
            }

            "KBMiner" {
                $Request = Invoke-HTTPRequest -Port $Miner.ApiPort
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = @(
                        [double]$Data.hashrates
                    )
                }
            }

            "RH" {
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request ' ' -Quiet
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]($Data.infos.speed | Measure-Object -Sum).Sum
                    $Shares = @(
                        [int64]$($Data.infos.accepted | Measure-Object -Sum).Sum
                        [int64]$($Data.infos.rejected | Measure-Object -Sum).Sum
                    )
                }
            }

            "NHEQ" {
                $Request = Invoke-TCPRequest -Port $Miner.ApiPort -Request "status" -Quiet
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = $Data.result.speed_ips * 1e6
                    $Shares = @(
                        [int64]([int64]$Data.result.accepted_per_minute * ((Get-Date) - $Miner.Process.StartTime).TotalMinutes)
                        [int64]([int64]$Data.result.rejected_per_minute * ((Get-Date) - $Miner.Process.StartTime).TotalMinutes)
                    )
                }
            }

        } #end switch

        return @{
            HashRates = @($HashRate)
            Shares    = @($Shares)
        }

    } catch { }
}




### Helper

function Get-NextFreePort {
    param(
        [Parameter(Mandatory = $true)]
        [int]$LastUsedPort
    )

    if ($LastUsedPort -lt 2000) { $FreePort = 2001 } else { $FreePort = $LastUsedPort + 1 } #not allow use of <2000 ports
    while (Test-TCPPort -Server 127.0.0.1 -Port $FreePort -timeout 100) { $FreePort = $LastUsedPort + 1 }
    $FreePort
}

function Test-TCPPort {
    param([string]$Server, [int]$Port, [int]$Timeout)

    $Connection = New-Object System.Net.Sockets.TCPClient

    try {
        $Connection.SendTimeout = $Timeout
        $Connection.ReceiveTimeout = $Timeout
        $Connection.Connect($Server, $Port) | Out-Null
        $Connection.Close
        $Connection.Dispose
        return $true #port is occupied
    } catch {
        $Error.Remove($error[$Error.Count - 1])
        return $false #port is free
    }
}

function Stop-SubProcess {
    param(
        [Parameter(Mandatory = $true)]
        $Process
    )

    $SubProcs = Get-Process | Where-Object { $_.Parent.Id -eq $Process.Id }

    @($Process, $SubProcs) | ForEach-Object {
        $_.CloseMainWindow() | Out-Null
    }
    Start-Sleep -Seconds 1

    @($Process, $SubProcs) | Where-Object HasExited -eq $false | ForEach-Object {
        Stop-Process -InputObject $_ -Force
    }

    # $sw = [Diagnostics.Stopwatch]::new()
    # try {
    #     $Process.CloseMainWindow() | Out-Null
    #     $sw.Start()
    #     do {
    #         if ($sw.Elapsed.TotalSeconds -gt 1) {
    #             Stop-Process -InputObject $Process -Force
    #         }
    #         if (-not $Process.HasExited) {
    #             Start-Sleep -Milliseconds 1
    #         }
    #     } while (-not $Process.HasExited)
    # } finally {
    #     $sw.Stop()
    #     if (-not $Process.HasExited) {
    #         Stop-Process -InputObject $Process -Force
    #     }
    # }
    # Remove-Variable sw
}

function Invoke-TcpRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Server = "localhost",
        [Parameter(Mandatory = $true)]
        [String]$Port,
        [Parameter(Mandatory = $false)]
        [String]$Request,
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 10, #seconds,
        [Parameter(Mandatory = $false)]
        [Switch]$DoNotSendNewline,
        [Parameter(Mandatory = $false)]
        [Switch]$Quiet,
        [Parameter(Mandatory = $false)]
        [Switch]$WriteOnly,
        [Parameter(Mandatory = $false)]
        [Switch]$ReadToEnd
    )
    $Response = $null
    if ($Server -eq "localhost") { $Server = "127.0.0.1" }
    #try {$ipaddress = [ipaddress]$Server} catch {$ipaddress = [system.Net.Dns]::GetHostByName($Server).AddressList | select-object -index 0}
    try {
        $Client = New-Object System.Net.Sockets.TcpClient $Server, $Port
        $Stream = $Client.GetStream()
        $Writer = New-Object System.IO.StreamWriter $Stream
        if (-not $WriteOnly) { $Reader = New-Object System.IO.StreamReader $Stream }
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Writer.AutoFlush = $true

        if ($Request) {
            if ($DoNotSendNewline) {
                $Writer.Write($Request)
            } else {
                $Writer.WriteLine($Request)
            }
        }
        if (-not $WriteOnly) {
            if ($ReadToEnd) {
                $Response = $Reader.ReadToEnd()
            } else {
                $Response = $Reader.ReadLine()
            }
        }
    } catch {
        if ($Error.Count) { $Error.RemoveAt(0) }
        if (-not $Quiet) { Log "Could not request from $($Server):$($Port)" -Severity Warn }
    } finally {
        if ($Reader) { $Reader.Close(); $Reader.Dispose() }
        if ($Writer) { $Writer.Close(); $Writer.Dispose() }
        if ($Stream) { $Stream.Close(); $Stream.Dispose() }
        if ($Client) { $Client.Close(); $Client.Dispose() }
    }
    $Response
}

function Invoke-HTTPRequest {
    param(
        [Parameter(Mandatory = $false)]
        [String]$Server = "127.0.0.1",
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
    $CachePath = "./Cache/"
    $CacheFile = $CachePath + [System.Web.HttpUtility]::UrlEncode($Url)
    $CacheFile = $CacheFile.subString(0, [math]::min(200, $CacheFile.Length)) + '.json'
    $Response = $null

    if (-not (Test-Path -Path $CachePath)) { New-Item -Path $CachePath -ItemType directory -Force | Out-Null }
    if (Test-Path $CacheFile -NewerThan (Get-Date).AddMinutes( - $Age)) {
        $Response = Get-Content -Path $CacheFile | ConvertFrom-Json
    } else {
        while ($Retry -gt 0) {
            try {
                $Retry--
                $Response = Invoke-RestMethod -Uri $Url -UserAgent $UserAgent -UseBasicParsing -TimeoutSec $Timeout
                if ($Response) { $Retry = 0 }
            } catch {
                Start-Sleep -Seconds 1
                $Error.Remove($error[$Error.Count - 1])
            }
        }
        if ($Response) {
            $Response | ConvertTo-Json -Depth 100 | Set-Content -Path $CacheFile
        } elseif (Test-Path -Path $CacheFile -NewerThan (Get-Date).AddMinutes( - $MaxAge)) {
            $Response = Get-Content -Path $CacheFile | ConvertFrom-Json
        } else {
            $Response = $null
        }
    }
    $Response
    Remove-Variable Response
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
        [bool]$UseAlternateMinerLauncher = $true <# UselessGuru #>
    )

    $PriorityNames = @{
        -2 = "Idle"
        -1 = "BelowNormal"
        0  = "Normal"
        1  = "AboveNormal"
        2  = "High"
        3  = "RealTime"
    }

    $JobParams = @{
        ArgumentList = $PID, $FilePath, $ArgumentList, $MinerWindowStyle, $WorkingDirectory, $UseAlternateMinerLauncher
    }

    if ($UseAlternateMinerLauncher -and $IsWindows) {
        $JobParams.InitializationScript = $([scriptblock]::Create("Set-Location('$(Get-Location)');. ./Includes/CreateProcess.ps1"))
    }

    if (-not (Get-Command $FilePath -ErrorAction SilentlyContinue)) {
        Log "$FilePath not found!" -Severity Warn
        return
    }

    $Job = Start-Job @JobParams {
        param($ControllerProcessID, $FilePath, $ArgumentList, $MinerWindowStyle, $WorkingDirectory, $UseAlternateMinerLauncher)

        $ControllerProcess = Get-Process -Id $ControllerProcessID
        if (-not $ControllerProcess) {
            return
        }

        $ProcessParams = @{
            FilePath         = $FilePath
            ArgumentList     = $ArgumentList
            WorkingDirectory = $WorkingDirectory
        }

        if ($IsWindows) {
            $ProcessParams.WindowStyle = $MinerWindowStyle
        }

        if ($UseAlternateMinerLauncher -and $IsWindows) {
            $ProcessParams.CreationFlags = [CreationFlags]::CREATE_NEW_CONSOLE
            $ProcessParams.StartF = [STARTF]::STARTF_USESHOWWINDOW

            $Process = Invoke-CreateProcess @ProcessParams
        } else {
            $ProcessParams.PassThru = $true

            if ($IsLinux) {
                # Linux requires output redirection, otherwise Receive-Job fails
                $ProcessParams.RedirectStandardOutput = $WorkingDirectory + "/console.log"
                $ProcessParams.RedirectStandardError = $WorkingDirectory + "/error.log"

                # Fix executable permissions
                & chmod +x $FilePath | Out-Null

                # Set lib path to local
                $env:LD_LIBRARY_PATH = $env:LD_LIBRARY_PATH + ":./"
            }

            $Process = Start-Process @ProcessParams
        }

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

        $ControllerProcess.Handle | Out-Null
        $Process.Handle | Out-Null

        do {
            if ($ControllerProcess.WaitForExit(1000)) {
                $Process.CloseMainWindow() | Out-Null
            }
        } until ($Process.HasExited)
    } # End job definition

    do {
        Start-Sleep -Seconds 1
        $JobOutput = Receive-Job $Job
    } while (-not $JobOutput)

    if ($JobOutput.ProcessId -gt 0) {
        $Process = Get-Process | Where-Object Id -eq $JobOutput.ProcessId
        $Process.Handle | Out-Null
        $Process

        if ($Process) { $Process.PriorityClass = $PriorityNames.$Priority }
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

    $FileName = ([IO.FileInfo](Split-Path $Uri -Leaf)).name
    $CachePath = "./Downloads/"
    $FilePath = $CachePath + $Filename

    if (-not (Test-Path -LiteralPath $CachePath)) { $null = New-Item -Path $CachePath -ItemType directory }

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
                Log "Unpacking to $Path"
                if (-not (Test-Path $Path)) { $null = New-Item -Path $Path -ItemType directory }

                if ($IsLinux) {
                    if (($FileName -split '\.')[-2] -eq 'tar') {
                        $Params = @{
                            FilePath     = "tar"
                            ArgumentList = "-xa -f $FilePath -C $Path"
                        }
                    } elseif (($FileName -split '\.')[-1] -in @('tgz')) {
                        $Params = @{
                            FilePath     = "tar"
                            ArgumentList = "-xz -f $FilePath -C $Path"
                        }
                    } else {
                        $Params = @{
                            FilePath               = "7z"
                            ArgumentList           = "x `"$FilePath`" -o`"$Path`" -y"
                            RedirectStandardOutput = Join-Path "./Logs" "7z-console.log"
                            RedirectStandardError  = Join-Path "./Logs" "7z-error.log"
                        }
                    }
                } else {
                    $Params = @{
                        FilePath     = "./includes/7z.exe"
                        ArgumentList = "x `"$FilePath`" -o`"$Path`" -y -spe"
                    }
                }
                $Params.Wait = $true
                if (Get-Command $Params.FilePath -ErrorAction SilentlyContinue) {
                    Start-Process @Params
                } else {
                    Log "$($Params.FilePath) not found!" -Severity Warn
                }
            }
        }
    } finally {
        # if (Test-Path $FilePath) {Remove-Item $FilePath}
    }
}

function Get-Pools {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Core', 'Wallet', 'ApiKey', 'Speed')]
        [string]$Querymode,

        [Parameter(Mandatory = $false)]
        [array]$PoolsFilterList = @(),

        [Parameter(Mandatory = $false)]
        [array]$CoinFilterList,

        [Parameter(Mandatory = $false)]
        [string]$Location = $null,

        [Parameter(Mandatory = $false)]
        [array]$AlgoFilterList,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$Info = @{ }
    )
    #in detail mode returns a line for each pool/algo/coin combination, in info mode returns a line for pool

    $PoolsFolderContent = Get-ChildItem ./Pools/* -File -Include '*.ps1' | Where-Object {
        $PoolsFilterList.Count -eq 0 -or $PoolsFilterList -icontains $_.BaseName
    }

    if ($null -eq ($Info | Get-Member -MemberType NoteProperty | Where-Object Name -eq Location)) {
        $Info | Add-Member Location $Location
    }

    $ChildItems = $PoolsFolderContent | ForEach-Object {
        $StopWatch = [system.diagnostics.stopwatch]::StartNew()
        $BaseName = $_.BaseName
        $Content = & $_.FullName -Querymode $Querymode -Info $Info
        $Content | ForEach-Object {
            [PSCustomObject]@{
                Name    = $BaseName
                Content = $_
            }
        }
        $StopWatch.Stop()
        Log "Pool $Querymode $BaseName responded in $($StopWatch.Elapsed.TotalSeconds) sec." -Severity Debug
    }

    $AllPools = $ChildItems | ForEach-Object {
        if ($_.Content) {
            $_.Content | Add-Member @{Name = $_.Name } -PassThru -Force
        }
    }

    $AllPools | Add-Member LocationPriority 9999 -Force

    #Apply filters
    $AllPools2 = @()
    if ($Querymode -eq "Core" -or $Querymode -eq "Menu" ) {
        foreach ($Pool in ($AllPools | Where-Object User)) {

            # Include pool algos and coins
            if (
                (
                    $Config.("IncludeAlgos_" + $Pool.PoolName) -and
                    @($Config.("IncludeAlgos_" + $Pool.PoolName) -split ',' | ForEach-Object { $_.Trim() }) -notcontains $Pool.Algorithm
                ) -or (
                    $Config.("IncludeCoins_" + $Pool.PoolName) -and
                    @($Config.("IncludeCoins_" + $Pool.PoolName) -split ',' | ForEach-Object { $_.Trim() }) -notcontains $Pool.Info
                )
            ) {
                Log "Excluding $($Pool.Algorithm)/$($Pool.Info) on $($Pool.PoolName) due to Include filter" -Severity Debug
                continue
            }

            # Exclude pool algos and coins
            if (
                @($Config.("ExcludeAlgos_" + $Pool.PoolName) -split ',' | ForEach-Object { $_.Trim() }) -contains $Pool.Algorithm -or
                @($Config.("ExcludeCoins_" + $Pool.PoolName) -split ',' | ForEach-Object { $_.Trim() }) -contains $Pool.Info
            ) {
                Log "Excluding $($Pool.Algorithm)/$($Pool.Info) on $($Pool.PoolName) due to Exclude filter" -Severity Debug
                continue
            }

            #must be in algo filter list or no list
            if ($AlgoFilterList) { $Algofilter = Compare-Object $AlgoFilterList $Pool.Algorithm -IncludeEqual -ExcludeDifferent }
            if ($AlgoFilterList.count -eq 0 -or $Algofilter) {

                #must be in coin filter list or no list
                if ($CoinFilterList) { $CoinFilter = Compare-Object $CoinFilterList $Pool.info -IncludeEqual -ExcludeDifferent }
                if ($CoinFilterList.count -eq 0 -or $CoinFilter) {
                    if ($Pool.Location -eq $Location) { $Pool.LocationPriority = 1 }
                    elseif ($Pool.Location -eq 'EU' -and $Location -eq 'US') { $Pool.LocationPriority = 2 }
                    elseif ($Pool.Location -eq 'US' -and $Location -eq 'EU') { $Pool.LocationPriority = 2 }

                    ## factor actual24h if price differs by factor of 10
                    if ($Pool.Actual24h) {
                        $factor = 0.2
                        if ($Pool.Price -gt ($Pool.Actual24h * 10)) { $Pool.Price = $Pool.Price * $factor + $Pool.Actual24h * (1 - $factor) }
                        if ($Pool.Price24h -gt ($Pool.Actual24h * 10)) { $Pool.Price24h = $Pool.Price24h * $factor + $Pool.Actual24h * (1 - $factor) }
                    }
                    ## Apply pool fees and pool factors
                    if ($Pool.Price) {
                        $Pool.Price *= 1 - [double]$Pool.Fee
                        $Pool.Price *= $(if ($Config."PoolProfitFactor_$($Pool.Name)") { [double]$Config."PoolProfitFactor_$($Pool.Name)" } else { 1 })
                    }
                    if ($Pool.Price24h) {
                        $Pool.Price24h *= 1 - [double]$Pool.Fee
                        $Pool.Price24h *= $(if ($Config."PoolProfitFactor_$($Pool.Name)") { [double]$Config."PoolProfitFactor_$($Pool.Name)" } else { 1 })
                    }
                    $AllPools2 += $Pool
                }
            }
        }
        $Return = $AllPools2
    } else { $Return = $AllPools }

    Remove-Variable AllPools
    Remove-Variable AllPools2

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

    $Result = @{ }

    $File = "./Config/Config.ini"

    if (-not (Test-Path $File) -and (Test-Path ./Config.ini)) {
        Move-Item ./Config.ini $File -Force -ErrorAction Ignore
        Log "Config file moved to /Config/Config.ini" -Severity Warn
    }

    if (-not (Test-Path $File)) {
        Log "No config file! Please copy /Config/Config-SAMPLE.ini to /Config/Config.ini and edit it!" -Severity Error
        Exit
    }

    switch -regex -file $File {
        "^\s*(\w+)\s*=\s*(.*)" {
            $name, $value = $matches[1..2]
            $Result[$name] = switch -wildcard ($value.Trim()) {
                'enable*' { $true }
                'disable*' { $false }
                'on' { $true }
                'off' { $false }
                'yes' { $true }
                'no' { $false }
                Default { $value.Trim() }
            }
        }
    }
    $Result # Return Value
}

function Get-Wallets {

    $Result = @{ }
    $File = "./Config/Config.ini"

    if (-not (Test-Path $File) -and (Test-Path ./Config.ini)) {
        Move-Item ./Config.ini $File -Force -ErrorAction Ignore
        Log "Config file moved to /Config/Config.ini" -Severity Warn
    }

    if (-not (Test-Path $File)) {
        Log "No config file! Please copy /Config/Config-SAMPLE.ini to /Config/Config.ini and edit it!" -Severity Error
        Exit
    }

    switch -regex -file $File {
        "^\s*WALLET_(\w+)\s*=\s*(.*)" {
            $name, $value = $matches[1..2]
            $Result[$name] = $value.Trim()
        }
    }
    $Result # Return Value
}

function Get-MinerParameters {

    if (-not (Test-Path ./Config/MinerParameters.json) -and (Test-Path ./Data/MinerParameters.default.json)) {
        Copy-Item ./Data/MinerParameters.default.json ./Config/MinerParameters.json -Force -ErrorAction Ignore
    }

    $DefaultParams = Get-Content ./Data/MinerParameters.default.json | ConvertFrom-Json
    $CustomParams = Get-Content ./Config/MinerParameters.json | ConvertFrom-Json

    # Populate Config/MinerParameters.json with new miners/algos
    $DefaultParams | Get-Member -MemberType NoteProperty -PipelineVariable Miner | ForEach-Object {
        if ($CustomParams.($Miner.Name)) {
            $DefaultParams.($Miner.Name) | Get-Member -MemberType NoteProperty -PipelineVariable Algo | ForEach-Object {
                if ($CustomParams.($Miner.Name).($Algo.Name) -isnot [string]) {
                    $CustomParams.($Miner.Name) | Add-Member $Algo.Name $DefaultParams.($Miner.Name).($Algo.Name)
                }
            }
        } else {
            $CustomParams | Add-Member $Miner.Name $DefaultParams.($Miner.Name)
        }
    }
    $CustomParams | ConvertTo-Json | Set-Content ./Config/MinerParameters.json

    $CustomParams # Return Value
}

function Get-BestHashRateAlgo {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm
    )

    $Pattern = "*_" + $Algorithm + "_*_HashRate.csv"

    Get-ChildItem ./Stats -File | Where-Object Name -ilike $Pattern | ForEach-Object {
        $Content = Get-Content $_.FullName | ConvertFrom-Csv
        [PSCustomObject]@{
            HashRate = $Content.Speed | Measure-Object -Average | Select-Object -ExpandProperty Average
            Miner    = ($_.BaseName -split '_')[0]
        }
    } | Sort-Object HashRate -Descending | Select-Object -First 1
}

function Get-AlgoUnifiedName ([string]$Algo) {

    $Algo = $Algo -ireplace '[^\w]'
    if ($Algo) {

        if (-not $global:AlgosTable) {
            $global:AlgosTable = Get-Content -Path ./Data/algorithms.json | ConvertFrom-Json
        }
        if ($AlgosTable.$Algo) { $AlgosTable.$Algo }
        else { $Algo }
    } else {
        $null
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
            "Pascalcoin" { "Pascal" }
            "Ravencoin" { "Raven" }
            "Shield-*" { "Verge" }
            "Verge-*" { "Verge" }
            Default { $Coin }
        }
    } else {
        $null
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

    if ($AlgoLabel -eq "") { $AlgoLabel = 'X' }
    $Pattern = "./Stats/" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_HashRate"

    if (Test-Path -path "$Pattern.csv") {
        try {
            $Content = Get-Content -path "$Pattern.csv" | ConvertFrom-Csv
        } catch {
            # If error - delete file
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

    if ($AlgoLabel -eq "") { $AlgoLabel = 'X' }

    $Path = "./Stats/" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_HashRate.csv"

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

    if ($AlgoLabel -eq "") { $AlgoLabel = 'X' }
    $Pattern = "./Stats/" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_stats"

    if (Test-Path -path "$Pattern.json") {
        $Content = (Get-Content -path "$Pattern.json")
        try {
            $Content = $Content | ConvertFrom-Json
        } catch {
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

    if ($AlgoLabel -eq "") { $AlgoLabel = 'X' }

    $Path = "./Stats/" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_stats.json"

    $Value | ConvertTo-Json | Set-Content -Path $Path
}

function Start-Downloader {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Uri,
        [Parameter(Mandatory = $true)]
        [String]$ExtractionPath,
        [Parameter(Mandatory = $true)]
        [String]$Path,
        [Parameter(Mandatory = $false)]
        [String]$SHA256
    )

    if (-not (Test-Path $Path)) {
        try {
            if ($Uri -and (Split-Path $Uri -Leaf) -eq (Split-Path $Path -Leaf)) {
                # downloading a single file
                $null = New-Item (Split-Path $Path) -ItemType "Directory"
                (New-Object System.Net.WebClient).DownloadFile($Uri, $Path)
                if ($SHA256 -and (Get-FileHash -Path $Path -Algorithm SHA256).Hash -ne $SHA256) {
                    Log "File hash doesn't match. Removing file." -Severity Warn
                    Remove-Item $Path
                }
            } else {
                # downloading an archive or installer
                Log "Downloading $URI" -Severity Info
                Expand-WebRequest -Uri $Uri -Path $ExtractionPath -SHA256 $SHA256 -ErrorAction Stop
            }
        } catch {
            $Message = "Cannot download $Uri"
            Log $Message -Severity Warn
        }
    }
}

function Clear-Files {
    $Now = Get-Date

    $Files = @(
        $TargetFolder = "."
        $LastWrite = $Now.AddDays(-3)
        Get-ChildItem $TargetFolder -Include "*.log" -File -Recurse | Where-Object LastWriteTime -le $LastWrite

        $TargetFolder = "."
        Get-ChildItem $TargetFolder -File | Where-Object Name -ilike "wrapper_*.txt"

        $TargetFolder = "."
        Get-ChildItem $TargetFolder -File -Include "*.tmp" -Recurse

        $TargetFolder = "./Cache"
        $LastWrite = $Now.AddDays(-1)
        Get-ChildItem $TargetFolder -File -Include "*.json" -Recurse | Where-Object LastWriteTime -le $LastWrite
    )
    $Files | Remove-Item
}

function Get-CoinSymbol ([string]$Coin) {
    $Coin = $Coin -ireplace '[^\w]'
    if ($Coin) {
        if (-not $global:CoinsTable) {
            $global:CoinsTable = Get-Content -Path ./Data/coins.json | ConvertFrom-Json
        }
        if ($CoinsTable.$Coin) { $CoinsTable.$Coin }
        else { $Coin }
    }
}

function Start-Autoexec {
    [cmdletbinding()]
    param(
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0
    )
    if (-not (Test-Path ./Config/Autoexec.txt) -and (Test-Path ./Autoexec.txt)) {
        Move-Item ./Autoexec.txt ./Config/Autoexec.txt -Force -ErrorAction Ignore
        Log "Autoexec file moved to /Config/Autoexec.txt" -Severity Warn
    }
    if (-not (Test-Path ./Config/Autoexec.txt) -and (Test-Path ./Data/Autoexec.default.txt)) {
        Copy-Item ./Data/Autoexec.default.txt ./Config/Autoexec.txt -Force -ErrorAction Ignore
    }
    [System.Collections.ArrayList]$Script:AutoexecCommands = @()
    foreach ($cmd in @(Get-Content ./Config/Autoexec.txt -ErrorAction Ignore | Select-Object)) {
        if ($cmd -match "^[\s\t]*`"(.+?)`"(.*)$") {
            try {
                $Params = @{
                    FilePath                  = Convert-Path $Matches[1]
                    ArgumentList              = $Matches[2].Trim()
                    WorkingDirectory          = Split-Path (Convert-Path $Matches[1])
                    Priority                  = $Priority
                    UseAlternateMinerLauncher = $false
                }
                $Job = Start-SubProcess @Params
                if ($Job) {
                    $Job | Add-Member FilePath $Params.FilePath -Force
                    $Job | Add-Member Arguments $Params.ArgumentList -Force
                    $Job | Add-Member HasOwnMinerWindow $true -Force
                    Log "Autoexec command started: $($Params.FilePath) $($Params.ArgumentList)" -Severity Info
                    $Script:AutoexecCommands.Add($Job) | Out-Null
                }
            } catch { }
        }
    }
}

function Stop-Autoexec {
    $Script:AutoexecCommands | Where-Object Process | ForEach-Object {
        Stop-SubProcess -Job $_ -Title "Autoexec command" -Name "$($_.FilePath) $($_.Arguments)"
    }
}

function Get-WhatToMineURL {
    $f = 10
    'https://whattomine.com/coins.json?' + (
        @(
            "bcd=true&factor[bcd_hr]=$f&factor[bcd_p]=0" #BCD
            "bk14=true&factor[bk14_hr]=$f&factor[bk14_p]=0" #Decred
            "cn=true&factor[cn_hr]=$f&factor[cn_p]=0" #CryptoNight
            "cn7=true&factor[cn7_hr]=$f&factor[cn7_p]=0" #CryptoNightV7
            "cn8=true&factor[cn8_hr]=$f&factor[cn8_p]=0" #CryptoNightV8
            "cnf=true&factor[cnf_hr]=$f&factor[cnf_p]=0" #CryptoNightFast
            "cnh=true&factor[cnh_hr]=$f&factor[cnh_p]=0" #CryptoNightHeavy
            "cnhn=true&factor[cnhn_hr]=$f&factor[cnhn_p]=0" #CryptoNightHaven
            "cns=true&factor[cns_hr]=$f&factor[cns_p]=0" #CryptoNightSaber
            "cr29=true&factor[cr29_hr]=$f&factor[cr29_p]=0" #Cuckaroo29
            "eq=true&factor[eq_hr]=$f&factor[eq_p]=0" #Equihash
            "eqa=true&factor[eqa_hr]=$f&factor[eqa_p]=0" #AION (Equihash210)
            "eth=true&factor[eth_hr]=$f&factor[eth_p]=0" #Ethash
            "grof=true&factor[gro_hr]=$f&factor[gro_p]=0" #Groestl
            "hx=true&factor[hx_hr]=$f&factor[hx_p]=0" #Hex
            "l2z=true&factor[l2z_hr]=$f&factor[l2z_p]=0" #Lyra2z
            "lbry=true&factor[lbry_hr]=$f&factor[lbry_p]=0" #Lbry
            "lre=true&factor[lrev2_hr]=$f&factor[lrev2_p]=0" #Lyra2v2
            "lrev3=true&factor[lrev3_hr]=$f&factor[lrev3_p]=0" #Lyra2v3
            "mtp=true&factor[mtp_hr]=$f&factor[mtp_p]=0" #MTP
            "n5=true&factor[n5_hr]=$f&factor[n5_p]=0" #Nist5
            "ns=true&factor[ns_hr]=$f&factor[ns_p]=0" #NeoScrypt
            "pas=true&factor[pas_hr]=$f&factor[pas_p]=0" #Pascal
            "phi=true&factor[phi_hr]=$f&factor[phi_p]=0" #PHI
            "phi2=true&factor[phi2_hr]=$f&factor[phi2_p]=0" #PHI2
            "ppw=true&factor[ppw_hr]=$f&factor[ppw_p]=0" #ProgPOW
            "skh=true&factor[skh_hr]=$f&factor[skh_p]=0" #Skunk
            "tt10=true&factor[tt10_hr]=$f&factor[tt10_p]=0" #TimeTravel10
            "x11gf=true&factor[x11g_hr]=$f&factor[x11g_p]=0" #X11gost
            "x16r=true&factor[x16r_hr]=$f&factor[x16r_p]=0" #X16r
            "x22i=true&factor[x22i_hr]=$f&factor[x22i_p]=0" #X22i
            "xn=true&factor[xn_hr]=$f&factor[xn_p]=0" #Xevan
            "zh=true&factor[zh_hr]=$f&factor[zh_p]=0" #ZHash (Equihash144)
        ) -join '&'
    )
}
function Get-WhatToMineFactor {
    param (
        [string]$Algo
    )
    $f = 10
    if ($Algo) {
        if (-not $global:WTMFactorTable) {
            $global:WTMFactorTable = Get-Content -Path ./Data/wtm_factor.json | ConvertFrom-Json
        }
        if ($WTMFactorTable.$Algo) {
            $WTMFactorTable.$Algo * $f
        }
    }
}



### Console and logging

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

    do {
        if ($Host.UI.RawUI.KeyAvailable) {
            $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
            $KeyPressed = $Key.character
        }
        Start-Sleep -Milliseconds 30
    } until ((New-TimeSpan $LoopStart (Get-Date)).Seconds -gt $SecondsToWait -or $ValidKeys -contains $KeyPressed)

    $KeyPressed
}

function ConvertTo-Hash {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Hash
    )

    $Return = switch ([math]::truncate([math]::log($Hash, 1e3))) {
        1 { "{0:g4} kh" -f ($Hash / 1e3) }
        2 { "{0:g4} mh" -f ($Hash / 1e6) }
        3 { "{0:g4} gh" -f ($Hash / 1e9) }
        4 { "{0:g4} th" -f ($Hash / 1e12) }
        5 { "{0:g4} ph" -f ($Hash / 1e15) }
        default { "{0:g4} h" -f ($Hash) }
    }
    $Return
}

function Write-Color() {
    Param (
        [string] $text = $(Write-Error "You must specify some text"),
        [switch] $NoNewLine = $false
    )

    $startColor = $Host.UI.RawUI.ForegroundColor;

    $text.Split( [char]"{", [char]"}" ) | ForEach-Object -Begin { $i = 0; } -Process {
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

function Set-ConsolePosition ([int]$x, [int]$y) {
    # Get current cursor position and store away
    $position = $host.ui.rawui.cursorposition
    # Store new X Co-ordinate away
    $position.x = $x
    $position.y = $y
    # Place modified location back to $HOST
    $host.ui.rawui.cursorposition = $position
    Remove-Variable position
}

function Get-ConsolePosition ([ref]$x, [ref]$y) {

    $position = $host.UI.RawUI.CursorPosition
    $x.value = $position.x
    $y.value = $position.y
    Remove-Variable position
}

function Out-HorizontalLine ([string]$Title) {
    $MaxWidth = 170
    $Width = [math]::min($Host.UI.RawUI.WindowSize.Width, $MaxWidth) - 1
    if ([string]::IsNullOrEmpty($Title)) { $str = "-" * $Width }
    else {
        $str = '{white}' + ("-" * [math]::floor(($Width - $Title.Length - 4) / 2))
        $str += "{green}  " + $Title + "  "
        $str += '{white}' + ("-" * [math]::floor(($Width + 1 - $Title.Length - 4) / 2))
    }
    Write-Color $str
}

function Clear-Lines ([int]$Lines) {
    $x = $y = [ref]0
    Get-ConsolePosition ([ref]$x) ([ref]$y)
    $Width = $Host.UI.RawUI.WindowSize.Width
    Write-Host (" " * $Width * $Lines)
    Set-ConsolePosition $x $y
    Remove-Variable x
    Remove-Variable y
}

function Write-Message {
    param(
        [string]$Message,
        [int]$Line,
        [switch]$AlignRight,
        [switch]$AlignCenter
    )
    $MaxWidth = 170
    $Width = [math]::min($Host.UI.RawUI.WindowSize.Width, $MaxWidth) - 1
    if ($AlignRight) {
        [int]$X = ($Width - ($Message -replace "({\w+})").Length)
    } elseif ($AlignCenter) {
        [int]$X = ($Width - ($Message -replace "({\w+})").Length) / 2
    }
    Set-ConsolePosition $X $Line
    Write-Color $Message
}

function Set-WindowSize ([int]$Width, [int]$Height) {
    #Buffer must be always greater than windows size

    $BSize = $Host.UI.RawUI.BufferSize
    if ($Width -ne 0 -and $Width -gt $BSize.Width) { $BSize.Width = $Width }
    if ($Height -ne 0 -and $Height -gt $BSize.Height) { $BSize.Width = $Height }

    $Host.UI.RawUI.BufferSize = $BSize

    $WSize = $Host.UI.RawUI.WindowSize
    if ($Width -ne 0) { $WSize.Width = $Width }
    if ($Height -ne 0) { $WSize.Height = $Height }

    $Host.UI.RawUI.WindowSize = $WSize
}
