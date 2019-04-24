param(
    [parameter(mandatory = $true)]
    [validateset('Automatic', 'Automatic24h', 'Manual')]
    [string]$MiningMode,

    [parameter(mandatory = $true)]
    [array]$PoolsName,

    [parameter(mandatory = $false)]
    [array]$Algorithm,

    [parameter(mandatory = $false)]
    [array]$CoinsName,

    [parameter(mandatory = $false)]
    [array]$GroupNames
)

# Requires -Version 5.0

$Error.Clear()
Import-Module ./Include.psm1

Set-OsFlags

if ($IsWindows) {
    try { Set-WindowSize 170 50 } catch { }
}

# Start log file
$LogPath = "./Logs/"
if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType directory | Out-Null }
$LogName = $LogPath + "forager-$(Get-Date -Format "yyyyMMdd-HHmmss").log"
Start-Transcript $LogName  #for start log msg
Stop-Transcript | Out-Null
$global:LogFile = [System.IO.StreamWriter]::new( $LogName, $true )
$LogFile.AutoFlush = $true

Clear-Files

if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
    [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
}

# Force Culture to en-US
$culture = [System.Globalization.CultureInfo]::CreateSpecificCulture("en-US")
$culture.NumberFormat.NumberDecimalSeparator = "."
$culture.NumberFormat.NumberGroupSeparator = ","
[System.Threading.Thread]::CurrentThread.CurrentCulture = $culture

$ErrorActionPreference = "Continue"

$Global:Release = @{
    Application = "Forager"
    Version     = "19.04.1"
}
Log "$($Release.Application) v$($Release.Version)"

$Global:SystemInfo = Get-SystemInfo
Log "System Info: $($SystemInfo | ConvertTo-Json  -Depth 1)" -Severity Debug

$Host.UI.RawUI.WindowTitle = "$($Release.Application) v$($Release.Version)"

if ($env:CUDA_DEVICE_ORDER -ne 'PCI_BUS_ID') { $env:CUDA_DEVICE_ORDER = 'PCI_BUS_ID' } # Align CUDA id with nvidia-smi order

if ($env:GPU_FORCE_64BIT_PTR -ne 1) { $env:GPU_FORCE_64BIT_PTR = 1 }               # For AMD
if ($env:GPU_MAX_HEAP_SIZE -ne 100) { $env:GPU_MAX_HEAP_SIZE = 100 }               # For AMD
if ($env:GPU_USE_SYNC_OBJECTS -ne 1) { $env:GPU_USE_SYNC_OBJECTS = 1 }             # For AMD
if ($env:GPU_MAX_ALLOC_PERCENT -ne 100) { $env:GPU_MAX_ALLOC_PERCENT = 100 }       # For AMD
if ($env:GPU_SINGLE_ALLOC_PERCENT -ne 100) { $env:GPU_SINGLE_ALLOC_PERCENT = 100 } # For AMD
if ($env:GPU_MAX_WORKGROUP_SIZE -ne 256) { $env:GPU_MAX_WORKGROUP_SIZE = 256 }     # For AMD

# Set process priority to BelowNormal to avoid hash rate drops on systems with weak CPUs
(Get-Process -Id $PID).PriorityClass = "BelowNormal"

if ($IsWindows) {
    Import-Module NetSecurity -ErrorAction SilentlyContinue
    Import-Module Defender -ErrorAction SilentlyContinue
    Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction SilentlyContinue
    Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction SilentlyContinue

    if (Get-Command "Unblock-File" -ErrorAction SilentlyContinue) { Get-ChildItem . -Recurse | Unblock-File }
    if ((Get-Command "Get-MpPreference" -ErrorAction SilentlyContinue) -and (Get-MpComputerStatus -ErrorAction SilentlyContinue) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {
        Start-Process (@{desktop = "powershell"; core = "pwsh" }.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1'; Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs
    }
}

$ActiveMiners = @()
$ShowBestMinersOnly = $true

$Interval = @{
    Current   = $null
    Last      = $null
    Duration  = $null
    LastTime  = $null
    Benchmark = $null
    StartTime = Get-Date # First initialization
}

$Global:Config = Get-Config

$Params = @{
    Querymode       = "Info"
    PoolsFilterList = $PoolsName
    CoinFilterList  = $CoinsName
    Location        = $Config.Location
    AlgoFilterList  = $Algorithm
}

$PoolsChecking = Get-Pools @Params

$PoolsErrors = $PoolsChecking | Where-Object "ActiveOn$($MiningMode)Mode" -eq $false
if ($PoolsErrors) {
    $PoolsErrors | ForEach-Object {
        Log "$MiningMode MiningMode is not valid for pool $($_.Name)" -Severity Warn
    }
    Exit
}

if ($MiningMode -eq 'Manual' -and ($CoinsName -split ',').Count -ne 1) {
    Log "On manual mode one coin must be selected" -Severity Warn
    Exit
}

if ($MiningMode -eq 'Manual' -and ($Algorithm -split ',').Count -ne 1) {
    Log "On manual mode one algorithm must be selected" -Severity Warn
    Exit
}

# Initial Parameters
$InitialParams = @{
    Algorithm  = $Algorithm
    PoolsName  = $PoolsName
    CoinsName  = $CoinsName
    MiningMode = $MiningMode
}

$Msg = @("Initial Parameters: "
    "Algorithm: " + [string]($Algorithm -join ",")
    "PoolsName: " + [string]($PoolsName -join ",")
    "CoinsName: " + [string]($CoinsName -join ",")
    "MiningMode: " + $MiningMode
    "GroupNames: " + [string]($GroupNames -join ",")
) -join ' //'

Log $Msg -Severity Debug

Start-Autoexec

# Initialize MSI Afterburner
if ($Config.Afterburner -and $IsWindows) {
    . "$PSScriptRoot/Includes/Afterburner.ps1"
}

$Screen = 'Profits'

$StatsPath = "./Stats/"
$BinPath = $(if ($IsLinux) { "./BinLinux/" } else { "./Bin/" })
$MinersPath = $(if ($IsLinux) { "./MinersLinux/" } else { "./Miners/" })
if (-not (Test-Path $BinPath)) { New-Item -Path $BinPath -ItemType directory -Force | Out-Null }
if (-not (Test-Path $StatsPath)) { New-Item -Path $StatsPath -ItemType directory -Force | Out-Null }

Send-ErrorsToLog $LogFile

# This loop will be running forever
while ($Quit -ne $true) {

    $Global:Config = Get-Config
    Log "Config File: $($Config | ConvertTo-Json -Depth 1)" -Severity Debug

    $Global:MinerParameters = Get-MinerParameters

    Clear-Host
    $RepaintScreen = $true

    Get-Updates

    # Get mining types
    $DeviceGroupsConfig = Get-MiningTypes -Filter $GroupNames
    Test-DeviceGroupsConfig $DeviceGroupsConfig
    if ($null -ne $DeviceGroups) {
        $DeviceGroupsConfig | ForEach-Object {
            if ($DeviceGroups.GroupName -contains $_.GroupName) {
                $_.Enabled = $DeviceGroups | Where-Object GroupName -eq $_.GroupName | Select-Object -ExpandProperty Enabled -First 1
            }
        }
    } else {
        Log "Device List: $($DeviceGroupsConfig | ConvertTo-Json -Depth 1)" -Severity Debug
        Log "Device Information: $(Get-DevicesInformation $DeviceGroupsConfig | ConvertTo-Json -Depth 1)" -Severity Debug
    }

    $DeviceGroups = $DeviceGroupsConfig

    $DeviceGroupsCount = $DeviceGroups | Measure-Object | Select-Object -ExpandProperty Count
    if ($DeviceGroupsCount -gt 0) {
        $InitialProfitsScreenLimit = [Math]::Floor(30 / $DeviceGroupsCount) - 5
    }
    if ($null -eq $ProfitsScreenLimit) {
        $ProfitsScreenLimit = $InitialProfitsScreenLimit
    }

    # Get electricity cost for current time
    ($Config.ElectricityCost | ConvertFrom-Json) | ForEach-Object {
        if ((
                $_.HourStart -lt $_.HourEnd -and
                @(($_.HourStart)..($_.HourEnd)) -contains (Get-Date).Hour
            ) -or (
                $_.HourStart -gt $_.HourEnd -and (
                    @(($_.HourStart)..23) -contains (Get-Date).Hour -or
                    @(0..($_.HourEnd)) -contains (Get-Date).Hour
                )
            )
        ) {
            $PowerCost = [decimal]$_.CostKwh
        }
    }

    Log "New interval starting"

    $Interval.Last = $Interval.Current
    $Interval.LastTime = (Get-Date) - $Interval.StartTime
    $Interval.StartTime = Get-Date

    # Donation
    $DonationsFile = "./Data/donations.json"
    $DonationStat = if (Test-Path $DonationsFile) { Get-Content $DonationsFile | ConvertFrom-Json } else { @(0, 0) }
    $Config.DonateMinutes = [math]::Max($Config.DonateMinutes, 10)
    $MiningTime = $DonationStat[0]
    $DonatedTime = $DonationStat[1]
    switch ($Interval.Last) {
        "Mining" { $MiningTime += $Interval.LastTime.TotalMinutes }
        "Donate" { $DonatedTime += $Interval.LastTime.TotalMinutes }
    }

    if ($DonatedTime -ge $Config.DonateMinutes) {
        $MiningTime = 0
        $DonatedTime = 0
    }

    @($MiningTime, $DonatedTime) | ConvertTo-Json | Set-Content $DonationsFile

    # Activate or deactivate donation
    if ($MiningTime -gt 24 * 60) {
        # Donation interval
        $Interval.Current = "Donate"

        $Global:Config.UserName = "ffwd"
        $Global:Config.WorkerName = "Donate"
        $Global:Wallets = @{
            BTC = "3NoVvkGSNjPX8xBMWbP2HioWYK395wSzGL"
            LTC = "MXCsACfauv4zAub3jcM64weqEpG979uArm"
        }
        $Global:Config.Currency_Zpool = "LTC"
        $Global:Config.Currency_Zergpool = "LTC"

        $DonateInterval = [math]::min(($Config.DonateMinutes - $DonatedTime), 5) * 60

        $Algorithm = $null
        $PoolsName = @("NiceHash", "Zpool", "Zergpool")
        $CoinsName = $null
        $MiningMode = "Automatic"
        $PowerCost = 0

        Log "Next interval you will be donating for $DonateInterval seconds, thanks for your support"
    } else {
        # Mining interval
        $Interval.Current = "Mining"

        $Algorithm = $InitialParams.Algorithm
        $PoolsName = $InitialParams.PoolsName
        $CoinsName = $InitialParams.CoinsName
        $MiningMode = $InitialParams.MiningMode
        if (-not $Config.WorkerName) { $Config.WorkerName = $SystemInfo.ComputerName }

        $Global:Wallets = Get-Wallets
    }

    Send-ErrorsToLog $LogFile

    Log "Loading Pools Information"

    # Load information about the Pools
    do {
        $Params = @{
            Querymode       = "Core"
            PoolsFilterList = $PoolsName
            CoinFilterList  = $CoinsName
            Location        = $Config.Location
            AlgoFilterList  = $Algorithm
        }
        $AllPools = Get-Pools @Params
        if ($AllPools.Count -eq 0) {
            Log "NO POOLS! Retry in 30 seconds" -Severity Warn
            Log "If you are mining on anonymous pool without exchage, like YIIMP, NANOPOOL or similar, you must set wallet for at least one pool coin in config.ini" -Severity Warn
            Start-Sleep 30
        }
    } while ($AllPools.Count -eq 0)

    $AllPools | Select-Object -ExpandProperty Name -Unique | ForEach-Object { Log "Pool $_ was responsive" }

    Log "Found $($AllPools.Count) pool/algo variations"

    # Filter by MinWorkers variable (only if there is any pool greater than minimum)
    $Pools = ($AllPools | Where-Object {
            $_.PoolWorkers -eq $null -or
            $_.PoolWorkers -ge $(if ($Config.('MinWorkers_' + $_.PoolName) -ne $null) { $Config.('MinWorkers_' + $_.PoolName) } else { $Config.MinWorkers })
        }
    )
    if ($Pools.Count -ge 1) {
        Log "$($Pools.Count) pools left after MinWorkers filter"
    } else {
        $Pools = $AllPools
        Log "No pools matching MinWorkers config, filter ignored"
    }

    # Select highest paying pool for each algo and check if pool is alive.
    Log "Select top paying pool for each algo in config"
    if ($Config.PingPools) { Log "Checking pool availability" }

    if ($DeviceGroups | Where-Object { -not $_.Algorithms }) {
        $AlgoList = $null
    } else {
        $AlgoList = $DeviceGroups.Algorithms | ForEach-Object { $_ -split '_' } | Select-Object -Unique
    }

    $PoolsFiltered = $Pools |
    Group-Object -Property Algorithm |
    Where-Object { $null -eq $AlgoList -or $AlgoList -contains $_.Name } |
    ForEach-Object {
        $NeedPool = $true
        # Order by price (profitability)
        $_.Group | Select-Object *, @{Name = "Estimate"; Expression = { if ($MiningMode -eq 'Automatic24h' -and $_.Price24h) { [decimal]$_.Price24h } else { [decimal]$_.Price } } } |
        Sort-Object -Property `
        @{Expression = "Estimate"; Descending = $true },
        @{Expression = "LocationPriority"; Ascending = $true } | ForEach-Object {
            if ($NeedPool) {
                # test tcp connection to pool
                if (-not $Config.PingPools -or (Test-TCPPort -Server $_.Host -Port $_.Port -Timeout 100)) {
                    $NeedPool = $false
                    $_  # return result
                } else {
                    Log "$($_.PoolName): $($_.Host):$($_.Port) is not responding!" -Severity Warn
                }
            }
        }
    }
    $Pools = $PoolsFiltered

    Log "$($Pools.Count) pools left"
    Remove-Variable PoolsFiltered

    # Call API for local currenry convertion rates
    try {
        $CDKResponse = Invoke-APIRequest -Url "https://api.coindesk.com/v1/bpi/currentprice/$($Config.LocalCurrency).json" -MaxAge 60 |
        Select-Object -ExpandProperty BPI
        $LocalBTCvalue = $CDKResponse.$($Config.LocalCurrency).rate_float
        Log "CoinDesk API was responsive"
    } catch {
        Log "Coindesk API not responding, no local coin conversion" -Severity Warn
    }

    # Load Miners
    $Miners = @()

    $Params = @{
        Path    = $MinersPath + "*"
        Include = "*.json"
    }
    $MinersFolderContent = Get-ChildItem @Params

    Log "Files in miner folder: $($MinersFolderContent.count)" -Severity Debug
    Log "Number of device groups: $(($DeviceGroups | Where-Object Enabled).Count)/$($DeviceGroups.Count)" -Severity Debug

    foreach ($MinerFile in $MinersFolderContent) {
        try {
            $Miner = $MinerFile | Get-Content | ConvertFrom-Json
        } catch {
            Log "Badly formed JSON: $MinerFile" -Severity Warn
            Start-Sleep -Seconds 10
            Continue
        }

        foreach ($DeviceGroup in ($DeviceGroups | Where-Object GroupType -eq $Miner.Type)) {
            if (
                $Config.("ExcludeMiners_" + $DeviceGroup.GroupName) -and
                ($Config.("ExcludeMiners_" + $DeviceGroup.GroupName).Split(',') | Where-Object { $MinerFile.BaseName -ilike $_.Trim() })
            ) {
                Log "$($MinerFile.BaseName) is Excluded for $($DeviceGroup.GroupName). Skipping" -Severity Debug
                Continue
            }
            Log "$($MinerFile.BaseName) is valid for $($DeviceGroup.GroupName)" -Severity Debug

            foreach ($Algo in $Miner.Algorithms.PSObject.Properties) {

                $AlgoTmp, $AlgoLabel = $Algo.Name -split "\|"
                $AlgoName, $AlgoNameDual = $AlgoTmp -split "_" | ForEach-Object { Get-AlgoUnifiedName $_ }
                $Algorithms = @($AlgoName, $AlgoNameDual) -ne $null -join '_'

                if ($null -ne $DeviceGroup.CUDAVersion -and $null -ne $Miner.CUDA) {
                    if ([version]("$($Miner.CUDA).0") -gt [version]$DeviceGroup.CUDAVersion) {
                        Log "$($MinerFile.BaseName) skipped due to CUDA version constraints" -Severity Debug
                        Continue
                    }
                }
                if ($null -ne $DeviceGroup.MemoryGB -and $Miner.Mem -gt $DeviceGroup.MemoryGB) {
                    Log "$($MinerFile.BaseName) skipped due to memory constraints" -Severity Debug
                    Continue
                }

                if ($DeviceGroup.GroupType -eq 'CPU' -and $Config.CpuThreads -gt 0) {
                    $AlgoLabel += 't' + $Config.CpuThreads
                    $CpuThreads = $Config.CpuThreads
                } else {
                    $CpuThreads = $null
                }

                if ($DeviceGroup.Algorithms -and $DeviceGroup.Algorithms -notcontains $Algorithms) { Continue } #check config has this algo as minable

                foreach ($Pool in ($Pools | Where-Object Algorithm -eq $AlgoName)) {

                    # Search pools for that algo
                    if (-not $AlgoNameDual -or ($Pools | Where-Object Algorithm -eq $AlgoNameDual)) {

                        # Set flag if both Miner and Pool support SSL
                        $EnableSSL = [bool]($Miner.SSL -and $Pool.SSL)

                        # Replace placeholder patterns
                        $WorkerNameMain = $Config.WorkerName + '_' + $DeviceGroup.GroupName

                        if ($Pool.PoolName -eq 'Nicehash') {
                            $WorkerNameMain = $WorkerNameMain -replace '[^\w\.]', '_' # Nicehash requires alphanumeric WorkerNames
                        }

                        $PoolUser = $Pool.User -replace '#WorkerName#', $WorkerNameMain
                        $PoolPass = $Pool.Pass -replace '#WorkerName#', $WorkerNameMain

                        $MinerFee = $ExecutionContext.InvokeCommand.ExpandString($Miner.Fee)
                        $NoCpu = $ExecutionContext.InvokeCommand.ExpandString($Miner.NoCpu)
                        $CustomParams = $ExecutionContext.InvokeCommand.ExpandString($Miner.Custom)

                        if ($Algo.Value -is [string]) {
                            $AlgoParams = $ExecutionContext.InvokeCommand.ExpandString($Algo.Value)
                        } else {
                            $AlgoParams = $ExecutionContext.InvokeCommand.ExpandString($Algo.Value.Params)
                            if ($Algo.Value.PSObject.Properties['Custom']) {
                                $CustomParams = $ExecutionContext.InvokeCommand.ExpandString($Algo.Value.Custom)
                            }
                            if ($Algo.Value.PSObject.Properties['Fee']) {
                                $MinerFee = $ExecutionContext.InvokeCommand.ExpandString($Algo.Value.Fee)
                            }
                            if ($Algo.Value.PSObject.Properties['NoCpu']) {
                                $NoCpu = $ExecutionContext.InvokeCommand.ExpandString($Algo.Value.NoCpu)
                            }

                            # Limitations
                            if (
                                $Algo.Value.Enabled -eq $false -or
                                $Algo.Value.NH -eq $false -and $Pool.PoolName -eq 'NiceHash' -or
                                ($Algo.Value.Mem -gt $DeviceGroup.MemoryGB * $(if ($SystemInfo.OSVersion.Major -eq 10) { 0.9 } else { 1 }) -and $DeviceGroup.MemoryGB -gt 0)
                            ) {
                                Continue
                            }
                        }

                        if ($MinerParameters.($MinerFile.BaseName).($Algo.Name) -is [string] ) {
                            $CustomParams = $MinerParameters.($MinerFile.BaseName).($Algo.Name)
                        }

                        $Params = @{
                            '#AlgorithmParameters#' = $AlgoParams
                            '#CustomParameters#'    = $CustomParams
                            '#Algorithm#'           = $AlgoName

                            '#Protocol#'            = $(if ($EnableSSL) { $Pool.ProtocolSSL } else { $Pool.Protocol })
                            '#Server#'              = $(if ($EnableSSL) { $Pool.HostSSL } else { $Pool.Host })
                            '#Port#'                = $(if ($EnableSSL) { $Pool.PortSSL } else { $Pool.Port })
                            '#Login#'               = $PoolUser
                            '#Password#'            = $PoolPass
                            '#EMail#'               = $Config.EMail
                            '#WorkerName#'          = $WorkerNameMain
                            '#EthStMode#'           = $Pool.EthStMode

                            '#GPUPlatform#'         = $DeviceGroup.PlatformId
                            '#Devices#'             = $DeviceGroup.Devices
                            '#DevicesClayMode#'     = Format-DeviceList -List $DeviceGroup.Devices -Type Clay
                            '#DevicesETHMode#'      = Format-DeviceList -List $DeviceGroup.Devices -Type Eth
                            '#DevicesNsgMode#'      = Format-DeviceList -List $DeviceGroup.Devices -Type Nsg
                            '#GroupName#'           = $DeviceGroup.GroupName
                        }

                        $Arguments = $Miner.Arguments -join " "
                        $Arguments = $Arguments -replace '#AlgorithmParameters#', $AlgoParams
                        foreach ($P in $Params.Keys) { $Arguments = $Arguments -replace $P, $Params.$P }
                        foreach ($P in $Params.Keys) { $Arguments = $Arguments -replace $P, $Params.$P }
                        $PatternConfigFile = $Miner.PatternConfigFile -replace '#Algorithm#', $AlgoName -replace '#GroupName#', $DeviceGroup.GroupName
                        if ($PatternConfigFile -and (Test-Path -Path "./Data/Patterns/$PatternConfigFile")) {
                            $ConfigFileArguments = Edit-ForEachDevice (Get-Content "./Data/Patterns/$PatternConfigFile" -raw) -Devices $DeviceGroup
                            foreach ($P in $Params.Keys) { $ConfigFileArguments = $ConfigFileArguments -replace $P, $Params.$P }
                            foreach ($P in $Params.Keys) { $ConfigFileArguments = $ConfigFileArguments -replace $P, $Params.$P }
                        } else { $ConfigFileArguments = $null }

                        # Search for DualMining pool
                        if ($AlgoNameDual) {
                            $PoolDual = $Pools |
                            Where-Object Algorithm -eq $AlgoNameDual |
                            Sort-Object Estimate -Descending |
                            Select-Object -First 1

                            # Set flag if both Miner and Pool support SSL
                            $EnableDualSSL = ($Miner.SSL -and $PoolDual.SSL)

                            # Replace placehoder patterns
                            $WorkerNameDual = $Config.WorkerName + '_' + $DeviceGroup.GroupName + 'D'

                            if ($Pool.PoolName -eq 'Nicehash') {
                                $WorkerNameDual = $WorkerNameDual -replace '[^\w\.]', '_' # Nicehash requires alphanumeric WorkerNames
                            }

                            $PoolUserDual = $PoolDual.User -replace '#WorkerNameDual#', $WorkerNameDual
                            $PoolPassDual = $PoolDual.Pass -replace '#WorkerNameDual#', $WorkerNameDual

                            $Params = @{
                                '#PortDual#'       = $(if ($EnableDualSSL) { $PoolDual.PortSSL } else { $PoolDual.Port })
                                '#ServerDual#'     = $(if ($EnableDualSSL) { $PoolDual.HostSSL } else { $PoolDual.Host })
                                '#ProtocolDual#'   = $(if ($EnableDualSSL) { $PoolDual.ProtocolSSL } else { $PoolDual.Protocol })
                                '#LoginDual#'      = $PoolUserDual
                                '#PasswordDual#'   = $PoolPassDual
                                '#AlgorithmDual#'  = $AlgoNameDual
                                '#WorkerNameDual#' = $WorkerNameDual
                            }
                            foreach ($P in $Params.Keys) { $Arguments = $Arguments -replace $P, $Params.$P }
                            foreach ($P in $Params.Keys) { $Arguments = $Arguments -replace $P, $Params.$P }
                            if ($PatternConfigFile -and (Test-Path -Path "./Data/Patterns/$PatternConfigFile")) {
                                foreach ($P in $Params.Keys) { $ConfigFileArguments = $ConfigFileArguments -replace $P, $Params.$P }
                                foreach ($P in $Params.Keys) { $ConfigFileArguments = $ConfigFileArguments -replace $P, $Params.$P }
                            }
                        } else {
                            $PoolDual = $null
                            $PoolUserDual = $null
                        }

                        # SubMiner are variations of miner that not need to relaunch
                        # Creates a "SubMiner" object for each PL
                        $SubMiners = @()
                        foreach ($PowerLimit in ($DeviceGroup.PowerLimits)) {
                            # Always create as least a power limit 0

                            # Check ActiveMiners if the miner exists already to conserve some properties and not read files
                            $FoundMiner = $ActiveMiners | Where-Object {
                                $_.Name -eq $MinerFile.BaseName -and
                                $_.Algorithm -eq $AlgoName -and
                                $_.AlgorithmDual -eq $AlgoNameDual -and
                                $_.AlgoLabel -eq $AlgoLabel -and
                                $_.Pool.PoolName -eq $Pool.PoolName -and
                                $_.PoolDual.PoolName -eq $PoolDual.PoolName -and
                                $_.Pool.Info -eq $Pool.Info -and
                                $_.PoolDual.Info -eq $PoolDual.Info -and
                                $_.DeviceGroup.GroupName -eq $DeviceGroup.GroupName
                            }

                            if ($FoundMiner) { $FoundMiner.DeviceGroup = $DeviceGroup }

                            $FoundSubMiner = $FoundMiner.SubMiners | Where-Object { $_.PowerLimit -eq $PowerLimit }

                            if (-not $FoundSubMiner) {
                                $Params = @{
                                    Algorithm  = $Algorithms
                                    MinerName  = $MinerFile.BaseName
                                    GroupName  = $DeviceGroup.GroupName
                                    PowerLimit = $PowerLimit
                                    AlgoLabel  = $AlgoLabel
                                }
                                [array]$Hrs = Get-HashRates @Params
                            } else {
                                [array]$Hrs = $FoundSubMiner.SpeedReads
                            }

                            if ($Hrs.Count -gt 10) {
                                # Remove 10 percent of lowest and highest rate samples which may skew the average
                                $Hrs = $Hrs | Sort-Object Speed
                                $p5Index = [math]::Ceiling($Hrs.Count * 0.05)
                                $p95Index = [math]::Ceiling($Hrs.Count * 0.95)
                                $Hrs = $Hrs[$p5Index..$p95Index] | Sort-Object SpeedDual, Speed
                                $p5Index = [math]::Ceiling($Hrs.Count * 0.05)
                                $p95Index = [math]::Ceiling($Hrs.Count * 0.95)
                                $Hrs = $Hrs[$p5Index..$p95Index]

                                $PowerValue = [decimal]($Hrs | Measure-Object -property Power -average).average
                                $HashRateValue = [decimal]($Hrs | Measure-Object -property Speed -average).average
                                $HashRateValueDual = [decimal]($Hrs | Measure-Object -property SpeedDual -average).average
                            } else {
                                $PowerValue = 0
                                $HashRateValue = 0
                                $HashRateValueDual = 0
                            }

                            # Calculate revenue
                            $SubMinerRevenue = [decimal]($HashRateValue * $Pool.Estimate)
                            $SubMinerRevenueDual = [decimal]($HashRateValueDual * $PoolDual.Estimate)

                            # Apply fee to revenue
                            $SubMinerRevenue *= (1 - $MinerFee)

                            if (-not $FoundSubMiner) {
                                $Params = @{
                                    Algorithm  = $Algorithms
                                    MinerName  = $MinerFile.BaseName
                                    GroupName  = $DeviceGroup.GroupName
                                    PowerLimit = $PowerLimit
                                    AlgoLabel  = $AlgoLabel
                                }
                                $StatsHistory = Get-Stats @Params
                            } else {
                                $StatsHistory = $FoundSubMiner.StatsHistory
                            }
                            $Stats = [PSCustomObject]@{
                                BestTimes        = 0
                                BenchmarkedTimes = 0
                                LastTimeActive   = [DateTime]0
                                ActivatedTimes   = 0
                                ActiveTime       = 0
                                FailedTimes      = 0
                                StatsTime        = [DateTime]0
                            }
                            if (-not $StatsHistory) { $StatsHistory = $Stats }

                            if ($SubMiners.Count -eq 0 -or $SubMiners[0].StatsHistory.BestTimes -gt 0) {
                                # Only add a SubMiner (distinct from first if first was best at some time)
                                $SubMiners += [PSCustomObject]@{
                                    Id                     = $SubMiners.Count
                                    Best                   = $false
                                    BestBySwitch           = ""
                                    HashRate               = $HashRateValue
                                    HashRateDual           = $HashRateValueDual
                                    NeedBenchmark          = [bool]($HashRateValue -eq 0 -or ($AlgorithmDual -and $HashRateValueDual -eq 0))
                                    PowerAvg               = $PowerValue
                                    PowerLimit             = [int]$PowerLimit
                                    PowerLive              = 0
                                    Profits                = (($SubMinerRevenue + $SubMinerRevenueDual) * $localBTCvalue) - ($PowerCost * ($PowerValue * 24) / 1000) # Profit is revenue minus electricity cost
                                    ProfitsLive            = 0
                                    Revenue                = $SubMinerRevenue
                                    RevenueDual            = $SubMinerRevenueDual
                                    RevenueLive            = 0
                                    RevenueLiveDual        = 0
                                    SharesLive             = @($null, $null)
                                    SpeedLive              = 0
                                    SpeedLiveDual          = 0
                                    SpeedReads             = if ($null -ne $Hrs) { [array]$Hrs } else { @() }
                                    Status                 = 'Idle'
                                    Stats                  = $Stats
                                    StatsHistory           = $StatsHistory
                                    TimeSinceStartInterval = [TimeSpan]0
                                }
                            }
                        } # End foreach PowerLimit

                        $Miners += [PSCustomObject] @{
                            AlgoLabel           = $AlgoLabel
                            Algorithm           = $AlgoName
                            AlgorithmDual       = $AlgoNameDual
                            Algorithms          = $Algorithms
                            Api                 = $Miner.Api
                            ApiPort             = $( if (-not $Config.ForceDynamicPorts) { $DeviceGroup.ApiPort } )
                            Arguments           = $ExecutionContext.InvokeCommand.ExpandString($Arguments)
                            BenchmarkArg        = $ExecutionContext.InvokeCommand.ExpandString($Miner.BenchmarkArg)
                            ConfigFileArguments = $ExecutionContext.InvokeCommand.ExpandString($ConfigFileArguments)
                            DeviceGroup         = $DeviceGroup
                            ExtractionPath      = $BinPath + $MinerFile.BaseName + "/"
                            GenerateConfigFile  = $(if ($PatternConfigFile) { $BinPath + $MinerFile.BaseName + "/" + $($Miner.GenerateConfigFile -replace '#GroupName#', $DeviceGroup.GroupName -replace '#Algorithm#', $AlgoName) })
                            MinerFee            = [decimal]$MinerFee
                            Name                = $MinerFile.BaseName
                            NoCpu               = $NoCpu
                            Path                = $BinPath + $MinerFile.BaseName + "/" + $ExecutionContext.InvokeCommand.ExpandString($Miner.Path)
                            Pool                = $Pool
                            PoolDual            = $PoolDual
                            PrelaunchCommand    = $Miner.PrelaunchCommand
                            SHA256              = $Miner.SHA256
                            SubMiners           = $SubMiners
                            URI                 = $Miner.URI
                            UserName            = $PoolUser
                            UserNameDual        = $PoolUserDual
                            WorkerName          = $WorkerNameMain
                            WorkerNameDual      = $WorkerNameDual
                        }
                    } # Dualmining
                } # End foreach pool
            } # End foreach algo
        } # End foreach DeviceGroup
    } # End foreach Miner

    Log "Miners/Pools combinations detected: $($Miners.Count)"

    # Launch download of miners
    $Miners |
    Where-Object {
        -not [string]::IsNullOrEmpty($_.Uri) -and
        -not [string]::IsNullOrEmpty($_.ExtractionPath) -and
        -not [string]::IsNullOrEmpty($_.Path) } |
    Select-Object Uri, ExtractionPath, Path, SHA256 -Unique |
    ForEach-Object {
        if (-not (Test-Path $_.Path)) {
            Start-Downloader -Uri $_.Uri -ExtractionPath $_.ExtractionPath -Path $_.Path -SHA256 $_.SHA256
        }
    }

    Send-ErrorsToLog $LogFile

    # Show no miners message
    $Miners = $Miners | Where-Object { Test-Path $_.Path }
    if ($Miners.Count -eq 0) {
        Log "NO MINERS! Retry in 30 seconds" -Severity Warn
        Start-Sleep -Seconds 30
        Continue
    }

    # Update the active miners list which exists for all execution time
    foreach ($ActiveMiner in ($ActiveMiners | Sort-Object [int]id)) {
        # Search existing miners to update data
        $Miner = $Miners | Where-Object {
            $_.Name -eq $ActiveMiner.Name -and
            $_.Algorithm -eq $ActiveMiner.Algorithm -and
            $_.AlgorithmDual -eq $ActiveMiner.AlgorithmDual -and
            $_.AlgoLabel -eq $ActiveMiner.AlgoLabel -and
            $_.Pool.PoolName -eq $ActiveMiner.Pool.PoolName -and
            $_.PoolDual.PoolName -eq $ActiveMiner.PoolDual.PoolName -and
            $_.Pool.Info -eq $ActiveMiner.Pool.Info -and
            $_.PoolDual.Info -eq $ActiveMiner.PoolDual.Info -and
            $_.DeviceGroup.Id -eq $ActiveMiner.DeviceGroup.Id
        }

        if (($Miner | Measure-Object).count -gt 1) {
            Log "DUPLICATE MINER $($Miner.Algorithms) in $($Miner.Name)" -Severity Warn
            Exit
        }

        if ($Miner) {
            # We found that miner
            $ActiveMiner.Arguments = $Miner.Arguments
            $ActiveMiner.Pool = $Miner.Pool
            $ActiveMiner.PoolDual = $Miner.PoolDual
            $ActiveMiner.IsValid = $true

            foreach ($SubMiner in $Miner.SubMiners) {
                if (($ActiveMiner.SubMiners | Where-Object { $_.Id -eq $SubMiner.Id }).Count -eq 0) {
                    $SubMiner | Add-Member IdF $ActiveMiner.Id
                    $ActiveMiner.SubMiners += $SubMiner
                } else {
                    $ActiveMiner.SubMiners[$SubMiner.Id].HashRate = $SubMiner.HashRate
                    $ActiveMiner.SubMiners[$SubMiner.Id].HashRateDual = $SubMiner.HashRateDual
                    $ActiveMiner.SubMiners[$SubMiner.Id].NeedBenchmark = $SubMiner.NeedBenchmark
                    $ActiveMiner.SubMiners[$SubMiner.Id].PowerAvg = $SubMiner.PowerAvg
                    $ActiveMiner.SubMiners[$SubMiner.Id].Profits = $SubMiner.Profits
                    $ActiveMiner.SubMiners[$SubMiner.Id].Revenue = $SubMiner.Revenue
                    $ActiveMiner.SubMiners[$SubMiner.Id].RevenueDual = $SubMiner.RevenueDual
                }
            }
        } else {
            # An existing miner is not found now
            $ActiveMiner.IsValid = $false
        }
    }

    # Add new miners to list
    foreach ($Miner in $Miners) {

        $ActiveMiner = $ActiveMiners | Where-Object {
            $_.Name -eq $Miner.Name -and
            $_.Algorithm -eq $Miner.Algorithm -and
            $_.AlgorithmDual -eq $Miner.AlgorithmDual -and
            $_.AlgoLabel -eq $Miner.AlgoLabel -and
            $_.Pool.PoolName -eq $Miner.Pool.PoolName -and
            $_.PoolDual.PoolName -eq $Miner.PoolDual.PoolName -and
            $_.Pool.Info -eq $Miner.Pool.Info -and
            $_.PoolDual.Info -eq $Miner.PoolDual.Info -and
            $_.DeviceGroup.Id -eq $Miner.DeviceGroup.Id
        }

        if (-not $ActiveMiner) {
            $Miner.SubMiners | Add-Member IdF $ActiveMiners.Count
            $ActiveMiners += [PSCustomObject]@{
                AlgoLabel           = $Miner.AlgoLabel
                Algorithm           = $Miner.Algorithm
                AlgorithmDual       = $Miner.AlgorithmDual
                Algorithms          = $Miner.Algorithms
                Api                 = $Miner.Api
                ApiPort             = $Miner.ApiPort
                Arguments           = $Miner.Arguments
                BenchmarkArg        = $Miner.BenchmarkArg
                ConfigFileArguments = $Miner.ConfigFileArguments
                DeviceGroup         = $Miner.DeviceGroup
                GenerateConfigFile  = $Miner.GenerateConfigFile
                Id                  = $ActiveMiners.Count
                IsValid             = $true
                MinerFee            = $Miner.MinerFee
                Name                = $Miner.Name
                NoCpu               = $Miner.NoCpu
                Path                = Convert-Path $Miner.Path
                Pool                = $Miner.Pool
                PoolDual            = $Miner.PoolDual
                PrelaunchCommand    = $Miner.PrelaunchCommand
                Process             = $null
                SubMiners           = $Miner.SubMiners
                UserName            = $Miner.UserName
                UserNameDual        = $Miner.UserNameDual
                WorkerName          = $Miner.WorkerName
                WorkerNameDual      = $Miner.WorkerNameDual
            }
        }
    }

    # Reset failed miners after 2 hours
    $ActiveMiners.SubMiners | Where-Object { $_.Status -eq 'Failed' -and $_.Stats.LastTimeActive -lt (Get-Date).AddHours(-2) } | ForEach-Object {
        $_.Status = 'Idle'
        $_.Stats.FailedTimes = 0
        Log "Reset failed miner status: $($ActiveMiners[$_.IdF].Name)/$($ActiveMiners[$_.IdF].Algorithms)"
    }

    Log "Active Miners-Pools: $(($ActiveMiners | Where-Object IsValid | Select-Object -ExpandProperty SubMiners | Where-Object Status -ne 'Failed').Count)"
    Send-ErrorsToLog $LogFile
    Log "Pending benchmarks: $(($ActiveMiners | Where-Object IsValid | Select-Object -ExpandProperty SubMiners | Where-Object NeedBenchmark | Select-Object -ExpandProperty Id).Count)"

    $Msg = ($ActiveMiners.SubMiners | ForEach-Object {
            "$($_.IdF)-$($_.Id), " +
            "$($ActiveMiners[$_.IdF].DeviceGroup.GroupName), " +
            "$(if ($ActiveMiners[$_.IdF].IsValid) {'Valid'} else {'Invalid'}), " +
            "PL $($_.PowerLimit), " +
            "$($_.Status), " +
            "$($ActiveMiners[$_.IdF].Name), " +
            "$($ActiveMiners[$_.IdF].Algorithms), " +
            "$($ActiveMiners[$_.IdF].Pool.Info), " +
            "$($ActiveMiners[$_.IdF].Process.Id)"
        }) | ConvertTo-Json
    Log $Msg -Severity Debug

    $BestLastMiners = $ActiveMiners.SubMiners | Where-Object { @("Running", "PendingStop", "PendingFail") -contains $_.Status }

    # Check if must cancel miner/algo/coin combo
    $BestLastMiners | Where-Object {
        $_.Status -eq 'PendingFail' -and
        ($ActiveMiners[$_.IdF].SubMiners.Stats.FailedTimes | Measure-Object -Sum).Sum -ge 3
    } | ForEach-Object {
        $ActiveMiners[$_.IdF].SubMiners | ForEach-Object { $_.Status = 'Failed' }
        Log "Detected 3 fails, disabling $($ActiveMiners[$_.IdF].DeviceGroup.GroupName)/$($ActiveMiners[$_.IdF].Name)/$($ActiveMiners[$_.IdF].Algorithms)" -Severity Warn
    }

    # Select miners that need Benchmark, or if running in Manual mode, or highest Profit above zero.
    $BestNowCandidates = $ActiveMiners | Where-Object { $_.IsValid -and $_.UserName -and $_.DeviceGroup.Enabled } |
    Group-Object { $_.DeviceGroup.GroupName } | ForEach-Object {
        $_.Group.Subminers | Where-Object {
            $_.Status -ne 'Failed' -and
            (
                $_.NeedBenchmark -or
                $MiningMode -eq "Manual" -or
                $Interval.Current -eq "Donate" -or
                $_.Profits -gt $ActiveMiners[$_.IdF].DeviceGroup.MinProfit -or
                -not $LocalBTCvalue -gt 0
            )
        } | Sort-Object -Descending NeedBenchmark, { $(if ($MiningMode -eq "Manual") { $_.HashRate } elseif ($LocalBTCvalue -gt 0) { $_.Profits } else { $_.Revenue + $_.RevenueDual }) }, PowerLimit
    }

    if ($Interval.Current -eq "Donate") {
        # Don't use unbenchmarked miners during donation unless there is no benchmarked miner
        $DonateBest = $BestNowCandidates | Where-Object NeedBenchmark -ne $true
        if ($null -ne $DonateBest) {
            $BestNowCandidates = $DonateBest
        }
        Remove-Variable DonateBest
    }

    $BestNowMiners = $BestNowCandidates | Group-Object {
        $ActiveMiners[$_.IdF].DeviceGroup.GroupName
    } | ForEach-Object { $_.Group | Select-Object -First 1 }

    # If GPU miner prevents CPU mining, check if it's more probitable to skip such miner or mine GPU only
    if ($DeviceGroups.GroupType -contains 'CPU' -and ($BestNowMiners | Where-Object { $ActiveMiners[$_.IdF].NoCpu })) {
        $AltBestNowMiners = $BestNowCandidates | Where-Object {
            $ActiveMiners[$_.IdF].NoCpu -ne $true
        } | Group-Object {
            $ActiveMiners[$_.IdF].DeviceGroup.GroupName
        } | ForEach-Object { $_.Group | Select-Object -First 1 }

        $BestNowProfits = ($BestNowMiners | Where-Object { $ActiveMiners[$_.IdF].DeviceGroup.GroupType -ne 'CPU' }).Profits | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        $AltBestNowProfits = $AltBestNowMiners.Profits | Measure-Object -Sum | Select-Object -ExpandProperty Sum

        if ($AltBestNowMiners.NeedBenchmark -contains $true -or ($AltBestNowProfits -gt $BestNowProfits -and $BestNowMiners.NeedBenchmark -notcontains $true)) {
            $BestNowMiners = $AltBestNowMiners
            Log "Skipping miners that prevent CPU mining" -Severity Warn
        } else {
            $BestNowMiners = $BestNowMiners | Where-Object { $ActiveMiners[$_.IdF].DeviceGroup.GroupType -ne 'CPU' }
            Log "Miner prevents CPU mining. Will not mine on CPU" -Severity Warn
        }
    }

    # For each type, select most profitable miner, not benchmarked has priority, new miner is only lauched if new profit is greater than old by PercentToSwitch
    # This section changes SubMiner
    foreach ($DeviceGroup in $DeviceGroups) {

        # Look for best miner from last Interval
        $BestLast = $BestLastMiners | Where-Object { $ActiveMiners[$_.IdF].DeviceGroup.GroupName -eq $DeviceGroup.GroupName }

        if ($BestLast) {
            $ProfitLast = $BestLast.Profits
            $BestLastLogMsg = @(
                "$($DeviceGroup.GroupName)"
                "$($ActiveMiners[$BestLast.IdF].Name)"
                "$($ActiveMiners[$BestLast.IdF].Algorithms)"
                "$($ActiveMiners[$BestLast.IdF].AlgoLabel)"
                "PL$($BestLast.PowerLimit)"
            ) -join '/'

            # Cancel miner if current pool workers below MinWorkers
            if (
                $null -ne $ActiveMiners[$BestLast.IdF].PoolWorkers -and
                $ActiveMiners[$BestLast.IdF].PoolWorkers -le $(if ($null -ne $Config.("MinWorkers_" + $ActiveMiners[$BestLast.IdF].Pool.PoolName)) { $Config.("MinWorkers_" + $ActiveMiners[$BestLast.IdF].Pool.PoolName) }else { $Config.MinWorkers })
            ) {
                $BestLast.Status = 'PendingStop'
                Log "Cancelling miner due to low worker count"
            }
        } else {
            $ProfitLast = 0
        }

        if ($BestLast -and $Config.SessionStatistics) {
            $BestLast | Select-Object -Property `
            @{Name = "Date"                 ; Expression = { Get-Date -f "yyyy-MM-dd" } },
            @{Name = "Time"                 ; Expression = { Get-Date -f "HH:mm:ss" } },
            @{Name = "Group"                ; Expression = { $DeviceGroup.GroupName } },
            @{Name = "Name"                 ; Expression = { $ActiveMiners[$_.IdF].Name } },
            @{Name = "Algorithm"            ; Expression = { $ActiveMiners[$_.IdF].Algorithm } },
            @{Name = "AlgorithmDual"        ; Expression = { $ActiveMiners[$_.IdF].AlgorithmDual } },
            @{Name = "AlgoLabel"            ; Expression = { $ActiveMiners[$_.IdF].AlgoLabel } },
            @{Name = "Coin"                 ; Expression = { $ActiveMiners[$_.IdF].Pool.Info } },
            @{Name = "CoinDual"             ; Expression = { $ActiveMiners[$_.IdF].PoolDual.Info } },
            @{Name = "PoolName"             ; Expression = { $ActiveMiners[$_.IdF].Pool.PoolName } },
            @{Name = "PoolNameDual"         ; Expression = { $ActiveMiners[$_.IdF].PoolDual.PoolName } },
            @{Name = "PowerLimit"           ; Expression = { $_.PowerLimit } },
            @{Name = "HashRate"             ; Expression = { [decimal]$_.HashRate } },
            @{Name = "HashRateDual"         ; Expression = { [decimal]$_.HashRateDual } },
            @{Name = "Revenue"              ; Expression = { [decimal]$_.Revenue } },
            @{Name = "RevenueDual"          ; Expression = { [decimal]$_.RevenueDual } },
            @{Name = "Profits"              ; Expression = { [decimal]$_.Profits } },
            @{Name = "IntervalRevenue"      ; Expression = { [decimal]$_.Revenue * $Interval.LastTime.TotalSeconds / (24 * 60 * 60) } },
            @{Name = "IntervalRevenueDual"  ; Expression = { [decimal]$_.RevenueDual * $Interval.LastTime.TotalSeconds / (24 * 60 * 60) } },
            @{Name = "Interval"             ; Expression = { [int]$Interval.LastTime.TotalSeconds } } |
            Export-Csv -Path $("./Logs/Stats-" + (Get-Process -PID $PID).StartTime.tostring('yyyy-MM-dd_HH-mm-ss') + ".csv") -Append -NoTypeInformation
        }

        # Check for best for next interval
        $BestNow = $BestNowMiners | Where-Object { $ActiveMiners[$_.IdF].DeviceGroup.GroupName -eq $DeviceGroup.GroupName }

        if ($BestNow) {
            $BestNowLogMsg = @(
                "$($DeviceGroup.GroupName)"
                "$($ActiveMiners[$BestNow.IdF].Name)"
                "$($ActiveMiners[$BestNow.IdF].Algorithms)"
                "$($ActiveMiners[$BestNow.IdF].AlgoLabel)"
                "PL$($BestNow.PowerLimit)"
            ) -join '/'

            $ProfitNow = $BestNow.Profits

            if ($BestNow.NeedBenchmark -eq $false) {
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].BestBySwitch = ""
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.BestTimes++
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.BestTimes++
            }

            Log ("Current best: $BestNowLogMsg")
        } else {
            Log "No valid candidate for device group $($DeviceGroup.GroupName)" -Severity Warn
        }

        if (
            $BestLast.IdF -ne $BestNow.IdF -or
            $BestLast.Id -ne $BestNow.Id -or
            @('PendingStop', 'PendingFail', 'Failed') -contains $BestLast.Status -or
            $Interval.Current -ne $Interval.Last -or
            -not $BestNow
        ) {
            # Something changes or some miner error
            if (
                $Interval.Current -ne $Interval.Last -or
                -not $BestLast -or
                -not $BestNow -or
                -not $ActiveMiners[$BestLast.IdF].IsValid -or
                $BestNow.NeedBenchmark -or
                @('PendingStop', 'PendingFail', 'Failed') -contains $BestLast.Status -or
                (@('Running') -contains $BestLast.Status -and $ProfitNow -gt ($ProfitLast * (1 + ($Config.PercentToSwitch / 100)))) -or
                (($ActiveMiners[$BestLast.IdF].NoCpu -or $ActiveMiners[$BestNow.IdF].NoCpu) -and $BestLast -ne $BestNow)
            ) {
                # Must launch other miner and/or stop actual

                # Stop old miner
                if ($BestLast) {

                    if (
                        $ActiveMiners[$BestLast.IdF].Process -and
                        $ActiveMiners[$BestLast.IdF].Process.Id -gt 0
                    ) {
                        Log "Stopping miner $BestLastLogMsg with PID $($ActiveMiners[$BestLast.IdF].Process.Id)"
                        do {
                            Stop-SubProcess $ActiveMiners[$BestLast.IdF].Process
                        } while (
                            # Test-TCPPort -Server 127.0.0.1 -Port $ActiveMiners[$BestLast.IdF].ApiPort
                            ($IsWindows -and (Get-NetTCPConnection | Where-Object { $_.State -eq "Listen" -and $_.LocalPort -eq $ActiveMiners[$BestLast.IdF].ApiPort })) -or
                            ($IsLinux -and (lsof -i -P -n | Where-Object { $_ -match ".*:$($ActiveMiners[$BestLast.IdF].ApiPort) \(LISTEN\)" }))
                        )
                    }

                    $ActiveMiners[$BestLast.IdF].Process = $null
                    $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Best = $false
                    $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = switch ($BestLast.Status) {
                        'Running' { 'Idle' }
                        'PendingStop' { 'Idle' }
                        'PendingFail' { 'Idle' }
                        'Failed' { 'Failed' }
                        Default { $BestLast.Status }
                    }
                }

                # Start new miner
                if ($BestNow) {

                    if (
                        $BestNow.PowerLimit -gt 0 -and
                        $BestNow.PowerLimit -ne $BestLast.PowerLimit
                    ) {
                        if ($abControl) {
                            Set-AfterburnerPowerLimit -PowerLimitPercent $BestNow.PowerLimit -DeviceGroup $ActiveMiners[$BestNow.IdF].DeviceGroup
                        } else {
                            switch ($ActiveMiners[$BestNow.IdF].DeviceGroup.GroupType) {
                                'NVIDIA' {
                                    Set-NvidiaPowerLimit -PowerLimitPercent $BestNow.PowerLimit -Devices $ActiveMiners[$BestNow.IdF].DeviceGroup.Devices
                                }
                                Default { }
                            }
                        }
                    }

                    $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Best = $true

                    if ($null -eq $ActiveMiners[$BestNow.IdF].ApiPort) {
                        $ActiveMiners[$BestNow.IdF].ApiPort = Get-NextFreePort (Get-Random -minimum 4000 -maximum 6000)
                    }
                    $ActiveMiners[$BestNow.IdF].Arguments = $ActiveMiners[$BestNow.IdF].Arguments -replace '#APIPort#', $ActiveMiners[$BestNow.IdF].ApiPort

                    if ($ActiveMiners[$BestNow.IdF].GenerateConfigFile) {
                        $ActiveMiners[$BestNow.IdF].ConfigFileArguments = $ActiveMiners[$BestNow.IdF].ConfigFileArguments -replace '#APIPort#', $ActiveMiners[$BestNow.IdF].ApiPort
                        $ActiveMiners[$BestNow.IdF].ConfigFileArguments | Set-Content ($ActiveMiners[$BestNow.IdF].GenerateConfigFile)
                    }

                    if ($ActiveMiners[$BestNow.IdF].PrelaunchCommand) { Invoke-Expression $ActiveMiners[$BestNow.IdF].PrelaunchCommand } # Run prelaunch command

                    $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.ActivatedTimes++
                    $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.ActivatedTimes++

                    $Arguments = $ActiveMiners[$BestNow.IdF].Arguments
                    if ($ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].NeedBenchmark -and $ActiveMiners[$BestNow.IdF].BenchmarkArg) { $Arguments += " " + $ActiveMiners[$BestNow.IdF].BenchmarkArg }

                    if ($ActiveMiners[$BestNow.IdF].Api -eq "Wrapper") {
                        $ProcessParams = @{
                            FilePath     = (Get-Process -Id $Global:PID).Path
                            ArgumentList = @{
                                ExecutionPolicy     = Bypass
                                Command             = . $(Convert-Path ./Wrapper.ps1)
                                ControllerProcessID = $PID
                                Id                  = $ActiveMiners[$BestNow.IdF].ApiPort
                                FilePath            = $ActiveMiners[$BestNow.IdF].Path
                                ArgumentList        = $Arguments
                                WorkingDirectory    = Split-Path $ActiveMiners[$BestNow.IdF].Path
                            }
                        }
                    } else {
                        $ProcessParams = @{
                            FilePath     = $ActiveMiners[$BestNow.IdF].Path
                            ArgumentList = $Arguments
                        }
                    }
                    $CommonParams = @{
                        WorkingDirectory = Split-Path $ActiveMiners[$BestNow.IdF].Path
                        MinerWindowStyle = $Config.MinerWindowStyle
                        Priority         = if ($ActiveMiners[$BestNow.IdF].DeviceGroup.GroupType -eq "CPU") { -2 } else { 0 }
                        # CPU miners run at low priority
                    }
                    Log "Starting $BestNowLogMsg --> $($ActiveMiners[$BestNow.IdF].Path) $($ActiveMiners[$BestNow.IdF].Arguments)" -Severity Debug
                    $ActiveMiners[$BestNow.IdF].Process = Start-SubProcess @ProcessParams @CommonParams

                    Log "Started $BestNowLogMsg with PID $($ActiveMiners[$BestNow.IdF].Process.Id)" -Severity Debug

                    $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Status = 'Running'
                    $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].BestBySwitch = ""
                    $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.LastTimeActive = Get-Date
                    $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.StatsTime = Get-Date
                    $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.LastTimeActive = Get-Date
                    $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].TimeSinceStartInterval = [TimeSpan]0
                }
            } else {
                # Must keep last miner by switch
                $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Best = $true
                if ($ProfitLast -lt $ProfitNow) {
                    $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].BestBySwitch = "*"
                    Log "$BestNowLogMsg Continue mining due to PercentToSwitch value"
                }
            }
        }

        if ($BestNow) {
            $Params = @{
                Algorithm  = $ActiveMiners[$BestNow.IdF].Algorithms
                MinerName  = $ActiveMiners[$BestNow.IdF].Name
                GroupName  = $ActiveMiners[$BestNow.IdF].DeviceGroup.GroupName
                AlgoLabel  = $ActiveMiners[$BestNow.IdF].AlgoLabel
                PowerLimit = $BestNow.PowerLimit
                Value      = $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory
            }
            Set-Stats @Params
        }
    }

    if ($Interval.Current -eq "Donate") {
        $Interval.Benchmark = $false
        $Interval.Duration = $DonateInterval
    } elseif ($ActiveMiners | Where-Object IsValid | Select-Object -ExpandProperty Subminers | Where-Object { $_.NeedBenchmark -and $_.Status -ne 'Failed' }) {
        $Interval.Benchmark = $true
        $Interval.Duration = $Config.BenchmarkTime
    } else {
        $Interval.Benchmark = $false
        $Interval.Duration = $ActiveMiners.SubMiners | Where-Object Status -eq 'Running' | Select-Object -ExpandProperty IdF | ForEach-Object {
            $PoolInterval = $Config.("Interval_" + $ActiveMiners[$_].Pool.RewardType)
            Log "Interval for pool $($ActiveMiners[$_].Pool.PoolName) is $PoolInterval" -Severity Debug
            $PoolInterval  # Return value
        } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
    }
    if (-not $Interval.Duration) { $Interval.Duration = 60 } # When no best miners available, retry every minute
    Log "Next interval: $($Interval.Duration)"

    $FirstLoopExecution = $true
    $LoopStartTime = Get-Date
    $SwitchLoop = 0
    $ActivityAverages = @()

    Send-ErrorsToLog $LogFile

    Clear-Host
    $RepaintScreen = $true

    # Interval loop to update info and check if miner is running, Exit loop is forced inside
    $ExitLoop = $false
    while ($ExitLoop -ne $true) {


        if ($Config.HardwareMonitoring) {
            $Devices = Get-DevicesInformation $DeviceGroups
        } else {
            $Devices = $null
        }

        #############################################################

        #Check Live Speed and record benchmark if necessary
        $ActiveMiners.SubMiners | Where-Object Best | ForEach-Object {

            if ($FirstLoopExecution -and $_.NeedBenchmark) {
                $_.Stats.BenchmarkedTimes++
                $_.StatsHistory.BenchmarkedTimes++
            }
            $_.SpeedLive = 0
            $_.SpeedLiveDual = 0
            $_.ProfitsLive = 0
            $_.RevenueLive = 0
            $_.RevenueLiveDual = 0

            $MinerHashRates = $null
            $MinerStats = Get-LiveHashRate -Miner $ActiveMiners[$_.IdF]
            $MinerHashRates = $MinerStats.HashRates
            $MinerShares = $MinerStats.Shares

            if ($MinerHashRates) {
                $_.SpeedLive = [decimal]($MinerHashRates[0])
                $_.SpeedLiveDual = [decimal]($MinerHashRates[1])
                $_.SharesLive = $MinerShares
                $_.RevenueLive = $_.SpeedLive * $ActiveMiners[$_.IdF].Pool.Estimate
                $_.RevenueLiveDual = $_.SpeedLiveDual * $ActiveMiners[$_.IdF].PoolDual.Estimate

                $_.ProfitsLive = ($_.RevenueLive * (1 - $ActiveMiners[$_.IdF].MinerFee) + $_.RevenueLiveDual) * $LocalBTCvalue

                $_.PowerLive = ($Devices | Where-Object GroupName -eq ($ActiveMiners[$_.IdF].DeviceGroup.GroupName) | Measure-Object -Property PowerDraw -sum).sum
                if ($_.PowerLive) { $_.ProfitsLive -= ($PowerCost * ($_.PowerLive * 24) / 1000) }

                $_.TimeSinceStartInterval = (Get-Date) - $_.Stats.LastTimeActive
                $TimeSinceStartInterval = [int]$_.TimeSinceStartInterval.TotalSeconds

                if (
                    $_.SpeedLive -and
                    ($_.SpeedLiveDual -or -not $ActiveMiners[$_.IdF].AlgorithmDual)
                ) {
                    if ($_.Stats.StatsTime) { $_.Stats.ActiveTime += ((Get-Date) - $_.Stats.StatsTime).TotalSeconds }
                    $_.Stats.StatsTime = Get-Date

                    [array]$_.SpeedReads = $_.SpeedReads

                    if ($_.SpeedReads.Count -le 10 -or $_.SpeedLive -le ((($_.SpeedReads | Measure-Object -Property Speed -Average).average) * 100)) {
                        #for avoid miners peaks recording

                        $_.SpeedReads += [PSCustomObject]@{
                            Speed     = [decimal]$_.SpeedLive
                            SpeedDual = [decimal]$_.SpeedLiveDual
                            Power     = [int]$_.PowerLive
                            Date      = (Get-Date).DateTime
                        }
                    }
                    if ($_.SpeedReads.Count -gt 100) {
                        # Remove 10 percent of lowest and highest rate samples which may skew the average
                        $_.SpeedReads = $_.SpeedReads | Sort-Object Speed
                        $p5Index = [math]::Ceiling($_.SpeedReads.Count * 0.05)
                        $p95Index = [math]::Ceiling($_.SpeedReads.Count * 0.95)
                        $_.SpeedReads = $_.SpeedReads[$p5Index..$p95Index] | Sort-Object SpeedDual, Speed
                        $p5Index = [math]::Ceiling($_.SpeedReads.Count * 0.05)
                        $p95Index = [math]::Ceiling($_.SpeedReads.Count * 0.95)
                        $_.SpeedReads = $_.SpeedReads[$p5Index..$p95Index] | Sort-Object Date
                    }

                    if ($_.NeedBenchmark) {

                        if ($_.SpeedReads.Count -gt 20) {
                            ### If average of last 2 periods is within SpeedDelta, we can stop benchmarking
                            $SpeedDelta = 0.01
                            $pIndex = [math]::Ceiling($_.SpeedReads.Count * 0.1)

                            $AvgPrev = $_.SpeedReads[($pIndex * 2)..($pIndex * 6)] | Measure-Object -Property Speed -Average | Select-Object -ExpandProperty Average
                            $AvgCurr = $_.SpeedReads[($pIndex * 6)..($_.SpeedReads.count - 1)] | Measure-Object -Property Speed -Average | Select-Object -ExpandProperty Average

                            $AvgPrevDual = $_.SpeedReads[($pIndex * 2)..($pIndex * 6)] | Measure-Object -Property SpeedDual -Average | Select-Object -ExpandProperty Average
                            $AvgCurrDual = $_.SpeedReads[($pIndex * 6)..($_.SpeedReads.count - 1)] | Measure-Object -Property SpeedDual -Average | Select-Object -ExpandProperty Average

                            if (
                                [math]::Abs($AvgPrev / $AvgCurr - 1) -le $SpeedDelta -and
                                ($AvgPrevDual -eq 0 -or [math]::Abs($AvgPrevDual / $AvgCurrDual - 1) -le $SpeedDelta)
                            ) {
                                $_.SpeedReads = $_.SpeedReads[($pIndex * 2)..($_.SpeedReads.count - 1)]
                                $_.NeedBenchmark = $false
                            }
                        }

                        $Params = @{
                            Algorithm  = $ActiveMiners[$_.IdF].Algorithms
                            MinerName  = $ActiveMiners[$_.IdF].Name
                            GroupName  = $ActiveMiners[$_.IdF].DeviceGroup.GroupName
                            AlgoLabel  = $ActiveMiners[$_.IdF].AlgoLabel
                            PowerLimit = $_.PowerLimit
                            Value      = $_.SpeedReads
                        }
                        Set-HashRates @Params
                    }
                }
            }

            if ($Devices) {
                # WATCHDOG
                $GroupDevices = @()
                $GroupDevices += $Devices | Where-Object GroupName -eq $ActiveMiners[$_.IdF].DeviceGroup.GroupName

                $ActivityAverages += [PSCustomObject]@{
                    DeviceGroup     = $ActiveMiners[$_.IdF].DeviceGroup.GroupName
                    Average         = ($GroupDevices | Measure-Object -property Utilization -average).average
                    NumberOfDevices = $GroupDevices.count
                }

                if ($ActivityAverages.count -gt 20 -and ($ActiveMiners.SubMiners | Where-Object Best).count -gt 0) {
                    $ActivityAverages = $ActivityAverages[($ActivityAverages.Count - 20)..($ActivityAverages.Count - 1)]
                    $ActivityAverage = ($ActivityAverages | Where-Object DeviceGroup -eq $ActiveMiners[$_.IdF].DeviceGroup.GroupName | Measure-Object -property Average -maximum).maximum
                    $ActivityDeviceCount = ($ActivityAverages | Where-Object DeviceGroup -eq $ActiveMiners[$_.IdF].DeviceGroup.GroupName | Measure-Object -property NumberOfDevices -maximum).maximum
                    # Log "Last 20 reads maximum Device activity is $ActivityAverage for DeviceGroup $($ActiveMiners[$_.IdF].DeviceGroup.GroupName)" -Severity Debug
                } else { $ActivityAverage = 100 } #only want watchdog works with at least 20 reads
            }

            ## HashRate Watchdog
            $WatchdogHashRateFail = $false
            if (
                $Config.WatchdogHashRate -gt 0 -and
                @($Config.WatchdogExcludeAlgos -split ',' | ForEach-Object { $_.Trim() }) -notcontains $ActiveMiners[$_.IdF].Algorithm -and
                $_.HashRate -gt 0 -and
                $_.SpeedReads.count -gt 20
            ) {
                $AvgCurr = $_.SpeedReads[-10..-1] | Measure-Object -Average -Property Speed | Select-Object -ExpandProperty Average
                $AvgCurrDual = $_.SpeedReads[-10..-1] | Measure-Object -Average -Property SpeedDual | Select-Object -ExpandProperty Average
                if (
                    ($_.HashRate / $AvgCurr - 1) -ge ($Config.WatchdogHashRate / 100) -and
                    (-not $_.HashRateDual -or ($_.HashRateDual / $AvgCurrDual - 1) -ge ($Config.WatchdogHashRate / 100))
                ) {
                    # Remove failing SpeedReads from statistics to prevent average skewing
                    $_.SpeedReads = $_.SpeedReads[0..($_.SpeedReads.count - 10)]
                    $WatchdogHashRateFail = $true
                    Log "Detected low hashrate $($ActiveMiners[$_.IdF].Name)/$($ActiveMiners[$_.IdF].Algorithm) : $(ConvertTo-Hash $AvgCurr) vs $(ConvertTo-Hash $_.HashRate)" -Severity Warn
                }
            }

            if (
                ($Config.WatchdogHashRate -and $WatchdogHashRateFail) -or
                $ActiveMiners[$_.IdF].Process -eq $null -or
                $ActiveMiners[$_.IdF].Process.HasExited -or
                ($Devices -and $ActivityAverage -le 40 -and $TimeSinceStartInterval -gt 100 -and $ActivityDeviceCount -gt 0)
            ) {
                $ExitLoop = $true
                $_.Status = "PendingFail"
                $_.Stats.FailedTimes++
                $_.StatsHistory.FailedTimes++
                Log "Detected miner error $($ActiveMiners[$_.IdF].Name)/$($ActiveMiners[$_.IdF].Algorithm) --> $($ActiveMiners[$_.IdF].Path) $($ActiveMiners[$_.IdF].Arguments)" -Severity Warn
            }
        } # End foreach active (best) subminer

        #############################################################

        if ($Interval.Benchmark -and ($ActiveMiners | Where-Object IsValid | Select-Object -ExpandProperty SubMiners | Where-Object { $_.NeedBenchmark -and $_.Best }).Count -eq 0) {
            Log "Benchmark completed early"
            $ExitLoop = $true
        }

        # Loop that will be invoked at reduced rate to not saturate external services.
        if ($SwitchLoop -eq 0) {

            $CurrentAlgos = (
                $ActiveMiners.SubMiners |
                Where-Object Best |
                Sort-Object { $ActiveMiners[$_.IdF].DeviceGroup.GroupType -eq 'CPU' } |
                ForEach-Object {
                    @($ActiveMiners[$_.IdF].Pool.Symbol, $ActiveMiners[$_.IdF].PoolDual.Symbol) -ne $null -join "_"
                }
            ) -join '/'

            $RunTime = $(Get-Date) - $(Get-Process -Pid $Global:PID | Select-Object -ExpandProperty StartTime)
            $Host.UI.RawUI.WindowTitle = $(if ($RunTime.TotalDays -lt 1) { "{0:hh\:mm}" -f $RunTime } else { "{0:d\d\ hh\:mm}" -f $RunTime }) + " : " + $CurrentAlgos

            # Report stats
            if ($Config.MinerStatusURL -and $Config.MinerStatusKey) {
                if ($ReportJob.State -eq 'Completed') {
                    $ReportJob | Remove-Job -ErrorAction SilentlyContinue
                }
                if ($null -eq $ReportJob -or $ReportJob.State -eq 'Completed') {
                    $Params = @{
                        WorkerName     = $SystemInfo.ComputerName
                        ActiveMiners   = $ActiveMiners
                        MinerStatusKey = $Config.MinerStatusKey
                        MinerStatusURL = $Config.MinerStatusURL
                    }
                    $R = Resolve-Path ./Includes/ReportStatus.ps1
                    $ReportJob = Start-Job {
                        & $using:R @using:Params
                    }
                }
            }

            # Get pool speed
            $Candidates = ($ActiveMiners.SubMiners | Where-Object Best | Select-Object IdF).IdF
            $PoolsSpeed = @(
                @(
                    $ActiveMiners |
                    Where-Object { $Candidates -contains $_.Id } |
                    Select-Object @{Name = "PoolName"; Expression = { $_.Pool.PoolName } },
                    @{Name = "WalletSymbol"; Expression = { $_.Pool.WalletSymbol } },
                    @{Name = "Coin"; Expression = { $_.Pool.Info } },
                    UserName, WorkerName -Unique

                    #Dual miners
                    $ActiveMiners |
                    Where-Object { $_.PoolDual.PoolName -and $Candidates -contains $_.Id } |
                    Select-Object @{Name = "PoolName"; Expression = { $_.PoolDual.PoolName } },
                    @{Name = "WalletSymbol"; Expression = { $_.PoolDual.WalletSymbol } },
                    @{Name = "Coin"; Expression = { $_.PoolDual.Info } },
                    @{Name = "UserName"; Expression = { $_.UserNameDual } },
                    WorkerName -Unique

                ) | ForEach-Object {
                    [PSCustomObject]@{
                        User       = $_.UserName
                        PoolName   = $_.PoolName
                        ApiKey     = $PoolConfig.($_.PoolName).ApiKey
                        Symbol     = $_.WalletSymbol
                        Coin       = $_.Coin
                        WorkerName = $_.WorkerName
                    }
                }
            ) | ForEach-Object { Get-Pools -Querymode "Speed" -PoolsFilterList $_.PoolName -Info $_ }

            foreach ($Candidate in $Candidates) {
                $Me = $PoolsSpeed | Where-Object { $_.PoolName -eq $ActiveMiners[$Candidate].Pool.PoolName -and $_.WorkerName -eq $ActiveMiners[$Candidate].WorkerName }
                if ($Me) {
                    if ($null -eq $ActiveMiners[$Candidate].Pool.HashRate) {
                        $ActiveMiners[$Candidate].Pool | Add-Member HashRate ($Me.HashRate | Measure-Object -Maximum).Maximum -Force
                    } else {
                        $ActiveMiners[$Candidate].Pool.HashRate = ($Me.HashRate | Measure-Object -Maximum).Maximum
                    }
                }

                $MeDual = $PoolsSpeed | Where-Object { $_.PoolName -eq $ActiveMiners[$Candidate].PoolDual.PoolName -and $_.WorkerName -eq $ActiveMiners[$Candidate].WorkerNameDual }
                if ($MeDual) {
                    if ($null -eq $ActiveMiners[$Candidate].PoolDual.HashRate) {
                        $ActiveMiners[$Candidate].PoolDual | Add-Member HashRate ($MeDual.HashRate | Measure-Object -Maximum).Maximum -Force
                    } else {
                        $ActiveMiners[$Candidate].PoolDual.HashRate = ($MeDual.HashRate | Measure-Object -Maximum).Maximum
                    }
                }
            }
        } # End Switchloop

        $SwitchLoop++
        if ($SwitchLoop -gt 5) { $SwitchLoop = 0 } # Reduces ratio of execution

        $ScreenOut = $ActiveMiners.Subminers |
        Where-Object Best | Sort-Object `
        @{expression = { $ActiveMiners[$_.IdF].DeviceGroup.GroupName -eq 'CPU' }; Ascending = $true },
        @{expression = { $ActiveMiners[$_.IdF].DeviceGroup.GroupName }; Ascending = $true } |
        ForEach-Object {
            $M = $ActiveMiners[$_.IdF]
            [PSCustomObject]@{
                Group       = $M.DeviceGroup.GroupName
                Algorithm   = (@($M.Algorithms, $M.AlgoLabel) -ne $null -join "|") + $_.BestBySwitch
                Coin        = @($M.Pool.Symbol, $M.PoolDual.Symbol) -ne $null -join "_"
                Miner       = $M.Name
                LocalSpeed  = (@($_.SpeedLive, $_.SpeedLiveDual) -gt 0 | ForEach-Object { ConvertTo-Hash $_ }) -join "/"
                Shares      = @($_.SharesLive) -ne $null -join '/'
                PLim        = $(if ($_.PowerLimit -ne 0) { $_.PowerLimit })
                Watt        = if ($_.PowerLive -gt 0) { [string]$_.PowerLive + 'W' } else { $null }
                EfficiencyW = if ($_.PowerLive -gt 0) { ($_.ProfitsLive / $_.PowerLive).tostring("n4") } else { $null }
                mbtcDay     = (($_.RevenueLive + $_.RevenueLiveDual) * 1000).tostring("n5")
                RevDay      = (($_.RevenueLive + $_.RevenueLiveDual) * $localBTCvalue ).tostring("n2")
                ProfitDay   = ($_.ProfitsLive).tostring("n2")
                PoolSpeed   = (@($M.Pool.HashRate, $M.PoolDual.HashRate) -gt 0 | ForEach-Object { ConvertTo-Hash $_ }) -join "/"
                Workers     = @($M.Pool.PoolWorkers, $M.PoolDual.PoolWorkers) -ne $null -join "/"
                Pool        = @(($M.Pool.PoolName + "-" + $M.Pool.Location), ($M.PoolDual.PoolName + "-" + $M.PoolDual.Location)) -ne "-" -join "/"
            }
        }

        # Log Miners
        Log ($ScreenOut | ConvertTo-Json -Compress) -Severity Debug

        if ($RepaintScreen) { Clear-Host }

        # Display interval
        $TimeToNextInterval = New-TimeSpan (Get-Date) ($LoopStartTime.AddSeconds($Interval.Duration))
        $TimeToNextIntervalSeconds = [int]$TimeToNextInterval.TotalSeconds
        if ($TimeToNextIntervalSeconds -lt 0) { $TimeToNextIntervalSeconds = 0 }

        # Display header
        Set-ConsolePosition 0 0
        Out-HorizontalLine
        Clear-Lines -Lines 1
        Write-Message -Message (
            @(
                "{green}$($Release.Application) {white}$($Release.Version)"
                "{white}|"
                "{green}P{white}rofits"
                "{green}S{white}tats"
                "{green}H{white}istory"
                "{green}C{white}urrent"
                "{green}W{white}allets"
                "{white}|"
                "{green}E{white}nd Interval"
                "{green}Q{white}uit"
                "{green}$([string[]]$DeviceGroups.Id -join '/'){white} Group toggle"
            ) -join "  "
        ) -Line 1

        Write-Message -Message "{white}  | Next Interval: {green}$TimeToNextIntervalSeconds{white} sec" -AlignRight -Line 1
        Out-HorizontalLine

        # Display donation message
        if ($Interval.Current -eq "Donate") {
            Write-Message -Message "{yellow}This interval you are donating. You can change donation in config.ini. Thank you for your support!" -Line 3 -AlignCenter
        }

        # Display current mining info
        if ($ScreenOut) {
            Clear-Lines -Lines ($ScreenOut.Count + 4)
            $ScreenOut | Format-Table (
                @{Label = "Group"                       ; Expression = { $_.Group } },
                @{Label = "Algorithm"                   ; Expression = { $_.Algorithm } },
                @{Label = "Coin"                        ; Expression = { $_.Coin } },
                @{Label = "Miner"                       ; Expression = { $_.Miner } },
                @{Label = "LocalSpeed"                  ; Expression = { $_.LocalSpeed } ; Align = 'right' },
                @{Label = "Acc/Rej"                     ; Expression = { $_.Shares } ; Align = 'right' },
                @{Label = "PLim"                        ; Expression = { $_.PLim } ; Align = 'right' },
                @{Label = "Watt"                        ; Expression = { $_.Watt } ; Align = 'right' },
                @{Label = $Config.LocalCurrency + "/W"  ; Expression = { $_.EfficiencyW }  ; Align = 'right' },
                @{Label = "mBTC/Day"                    ; Expression = { $_.mbtcDay } ; Align = 'right' },
                @{Label = $Config.LocalCurrency + "/Day"; Expression = { $_.RevDay } ; Align = 'right' },
                @{Label = "Profit/Day"                  ; Expression = { $_.ProfitDay } ; Align = 'right' },
                @{Label = "PoolSpeed"                   ; Expression = { $_.PoolSpeed } ; Align = 'right' },
                @{Label = "Workers"                     ; Expression = { $_.Workers } ; Align = 'right' },
                @{Label = "Pool"                        ; Expression = { $_.Pool } ; Align = 'left' }
            ) | Out-Host
        } else {
            Write-Warning "No profitable miners"
        }

        $XToWrite = [ref]0
        $YToWrite = [ref]0
        Get-ConsolePosition ([ref]$XToWrite) ([ref]$YToWrite)
        Set-ConsolePosition $XToWrite ($YToWrite - 1)
        $YToWriteMessages = $YToWrite
        $YToWriteData = $YToWrite
        Remove-Variable XToWrite
        Remove-Variable YToWrite

        Out-HorizontalLine $Screen

        # Display profits screen
        if ($Screen -eq "Profits" -and $RepaintScreen) {

            Write-Message -Message "{green}B{white}est Miners  {green}T{white}op $($InitialProfitsScreenLimit)/All" -AlignRight -Line $YToWriteMessages
            Set-ConsolePosition 0 $YToWriteData

            $ProfitMiners = @(
                $Candidates = $ActiveMiners.SubMiners | Where-Object { $ActiveMiners[$_.IdF].IsValid } | ForEach-Object {
                    $ProfitMiner = $ActiveMiners[$_.IdF] | Select-Object * -ExcludeProperty SubMiners
                    $ProfitMiner | Add-Member SubMiner $_
                    $ProfitMiner | Add-Member GroupName "[$($ProfitMiner.DeviceGroup.Id)] $($ProfitMiner.DeviceGroup.GroupName)" #needed for groupby
                    $ProfitMiner | Add-Member NeedBenchmark $ProfitMiner.SubMiner.NeedBenchmark #needed for sort
                    $ProfitMiner | Add-Member Profits $ProfitMiner.SubMiner.Profits #needed for sort
                    $ProfitMiner | Add-Member Revenue ($ProfitMiner.SubMiner.Revenue + $ProfitMiner.SubMiner.RevenueDual) #needed for sort
                    $ProfitMiner | Add-Member Status $ProfitMiner.SubMiner.Status #needed for sort
                    $ProfitMiner
                }
                $Candidates | Where-Object NeedBenchmark
                $Candidates | Where-Object NeedBenchmark -eq $false | Group-Object { $_.GroupName + $_.Algorithm + $_.AlgorithmDual } | ForEach-Object {
                    $_.Group | Sort-Object Profits, Revenue -Descending | Select-Object -First $(if ($ShowBestMinersOnly) { 1 } else { 1000 })
                }
            ) | Group-Object GroupName | ForEach-Object { $_.Group | Sort-Object NeedBenchmark, Profits, Revenue -Descending | Select-Object -First $ProfitsScreenLimit }

            $ProfitMiners | Sort-Object `
            @{expression = { $_.GroupName -like '*CPU' }; Ascending = $true },
            @{expression = "GroupName"; Ascending = $true },
            @{expression = "Status"; Descending = $true },
            @{expression = "NeedBenchmark"; Descending = $true },
            @{expression = { if ($LocalBTCvalue) { $_.Profits } else { $_.Revenue } }; Descending = $true },
            @{expression = "HashRate"; Descending = $true },
            @{expression = "HashRateDual"; Descending = $true } |
            Format-Table (
                @{Label = "Algorithm"                    ; Expression = { @($_.Algorithms, $_.AlgoLabel) -ne $null -join "|" } },
                @{Label = "Coin"                         ; Expression = { @($_.Pool.Symbol, $_.PoolDual.Symbol) -ne $null -join "_" } },
                @{Label = "Miner"                        ; Expression = { $_.Name } },
                @{Label = "StatsSpeed"                   ; Expression = { if ($_.NeedBenchmark) { "Bench" } else { (@($_.SubMiner.HashRate, $_.SubMiner.HashRateDual) -gt 0 | ForEach-Object { ConvertTo-Hash $_ }) -join "/" } }; Align = 'right' },
                @{Label = "PLim"                         ; Expression = { if ($_.SubMiner.PowerLimit -ne 0) { $_.SubMiner.PowerLimit } }; align = 'right' },
                @{Label = "Watt"                         ; Expression = { if ($_.SubMiner.PowerAvg -gt 0) { $_.SubMiner.PowerAvg.tostring("n0") } }; Align = 'right' },
                @{Label = $Config.LocalCurrency + "/W"   ; Expression = { if ($_.SubMiner.PowerAvg -gt 0) { ($_.SubMiner.Profits / $_.SubMiner.PowerAvg).tostring("n4") } }; Align = 'right' },
                @{Label = "mBTC/Day"                     ; Expression = { if ($_.Revenue) { ($_.Revenue * 1000).tostring("n3") } } ; Align = 'right' },
                @{Label = $Config.LocalCurrency + "/Day" ; Expression = { if ($_.Revenue) { ($_.Revenue * [decimal]$LocalBTCvalue).tostring("n2") } } ; Align = 'right' },
                @{Label = "Profit/Day"                   ; Expression = { if ($_.Profits) { ($_.Profits).tostring("n2") + " $($Config.LocalCurrency)" } }; Align = 'right' },
                @{Label = "PoolFee"                      ; Expression = { if ($_.Pool.Fee -gt 0) { "{0:p2}" -f $_.Pool.Fee } }; Align = 'right' },
                @{Label = "MinerFee"                     ; Expression = { if ($_.MinerFee -gt 0) { "{0:p2}" -f $_.MinerFee } }; Align = 'right' },
                @{Label = "Pool"                         ; Expression = { @($_.Pool.PoolName, $_.PoolDual.PoolName) -ne $null -join "/" } }
            ) -GroupBy GroupName | Out-Host
            Remove-Variable ProfitMiners

            $RepaintScreen = $false
        }

        if ($Screen -eq "Current") {
            Write-Message -Message "{white}Running Mode: {green}$MiningMode" -AlignRight -Line $YToWriteMessages
            Set-ConsolePosition 0 $YToWriteData

            # Display devices info
            Out-DevicesInformation $Devices
        }

        if (
            ($Screen -eq "Wallets" -or -not $WalletStatusAtStart) -and
            -not $ExitLoop
        ) {

            if (-not $WalletsUpdate) {

                # Wallets only refresh on Start and Manual request
                $WalletsUpdate = Get-Date

                $WalletsToCheck = @(
                    $AllPools |
                    Where-Object { $_.WalletMode -eq 'Wallet' -and $_.User } |
                    Select-Object PoolName, User, WalletMode, WalletSymbol -Unique |
                    ForEach-Object {
                        [PSCustomObject]@{
                            PoolName   = $_.PoolName
                            WalletMode = $_.WalletMode
                            User       = $_.User
                            Coin       = $null
                            Algorithm  = $null
                            Symbol     = $_.WalletSymbol
                        }
                    }

                    $AllPools |
                    Where-Object { $_.WalletMode -eq 'ApiKey' -and $Config.("ApiKey_" + $_.PoolName) } |
                    Select-Object PoolName, Algorithm, WalletMode, WalletSymbol, @{Name = "ApiKey"; Expression = { $Config.("ApiKey_" + $_.PoolName) } } -Unique |
                    ForEach-Object {
                        [PSCustomObject]@{
                            PoolName   = $_.PoolName
                            WalletMode = $_.WalletMode
                            User       = $null
                            Algorithm  = $_.Algorithm
                            Symbol     = $_.WalletSymbol
                            ApiKey     = $_.ApiKey
                        }
                    }
                )

                [array]$WalletStatus = $WalletsToCheck | ForEach-Object {

                    Write-Message -Message (" " * 70) -Line $YToWriteMessages
                    Set-ConsolePosition 0 $YToWriteMessages

                    Log "Checking pool balance $($_.PoolName)/$($_.Symbol)"

                    $Ws = Get-Pools -Querymode $_.WalletMode -PoolsFilterList $_.PoolName -Info ($_)

                    if ($_.WalletMode -eq "Wallet") { $Ws | Add-Member Wallet $_.User }
                    else { $Ws | Add-Member Wallet $_.Coin }
                    $Ws | Add-Member PoolName $_.PoolName
                    $Ws | Add-Member WalletSymbol $_.Symbol

                    $Ws
                }
                Write-Message -Message (" " * 70) -Line $YToWriteMessages

                if (-not $WalletStatusAtStart) { [array]$WalletStatusAtStart = $WalletStatus }

                foreach ($Wallet in $WalletStatus) {
                    if (-not $Wallet.BalanceAtStart) {
                        $BalanceAtStart = $WalletStatusAtStart | Where-Object {
                            $_.Wallet -eq $Wallet.Wallet -and
                            $_.PoolName -eq $Wallet.PoolName -and
                            $_.Currency -eq $Wallet.Currency
                        } | Select-Object -ExpandProperty Balance

                        if ($BalanceAtStart) {
                            $Wallet | Add-Member BalanceAtStart $BalanceAtStart
                        } else {
                            $WalletStatusAtStart += $Wallet
                        }
                    }
                }
            }

            if ($Screen -eq "Wallets" -and $RepaintScreen) {

                Write-Message -Message "{green}U{white}pdate wallets" -AlignRight -Line $YToWriteMessages

                $WalletStatus | Where-Object Balance |
                Sort-Object @{expression = "PoolName"; Ascending = $true }, @{expression = "balance"; Descending = $true } |
                Format-Table -Wrap -GroupBy PoolName (
                    @{Label = "Coin"; Expression = { if ($_.WalletSymbol -ne $null) { $_.WalletSymbol } else { $_.wallet } } },
                    @{Label = "Balance"; Expression = { $_.Balance.tostring("n5") }; Align = 'right' },
                    @{Label = "Session"; Expression = { ($_.Balance - $_.BalanceAtStart).tostring("n5") }; Align = 'right' }
                ) | Out-Host

                $RepaintScreen = $false
            }
        }

        if ($Screen -eq "History" -and $RepaintScreen) {

            Write-Message -Message "{white}Running Mode: {green}$MiningMode" -AlignRight -Line $YToWriteMessages
            Set-ConsolePosition 0 $YToWriteData

            # Display activated miners list
            $ActiveMiners.SubMiners |
            Where-Object { $_.Stats.ActivatedTimes -gt 0 } | Sort-Object `
            @{expression = { $ActiveMiners[$_.IdF].DeviceGroup.GroupName -eq 'CPU' }; Ascending = $true },
            @{expression = { $ActiveMiners[$_.IdF].DeviceGroup.GroupName }; Ascending = $true },
            @{expression = { $_.Stats.LastTimeActive }; Descending = $true } |
            Format-Table -Wrap -GroupBy @{Label = "Group"; Expression = { $ActiveMiners[$_.IdF].DeviceGroup.GroupName } } (
                @{Label = "LastTimeActive"; Expression = { $($_.Stats.LastTimeActive).tostring("dd/MM/yy H:mm") } },
                @{Label = "Command"; Expression = { "$($ActiveMiners[$_.IdF].Path.TrimStart((Convert-Path $BinPath))) $($ActiveMiners[$_.IdF].Arguments)" } }
            ) | Out-Host

            $RepaintScreen = $false
        }


        if ($Screen -eq "Stats" -and $RepaintScreen) {
            Write-Message -Message "{green}R{white}eset Failed" -AlignRight -Line $YToWriteMessages
            Set-ConsolePosition 0 $YToWriteData

            # Display activated miners list
            $ActiveMiners.SubMiners |
            Where-Object { $_.Stats.ActivatedTimes -gt 0 } |
            Sort-Object `
            @{expression = { $ActiveMiners[$_.IdF].DeviceGroup.GroupName -eq 'CPU' }; Ascending = $true },
            @{expression = { $ActiveMiners[$_.IdF].DeviceGroup.GroupName }; Ascending = $true },
            @{expression = { $_.Stats.Activetime }; Descending = $true } |
            Format-Table -Wrap -GroupBy @{Label = "Group"; Expression = { $ActiveMiners[$_.IdF].DeviceGroup.GroupName } }(
                @{Label = "Algorithm"; Expression = { $ActiveMiners[$_.IdF].Algorithms + $(if ($ActiveMiners[$_.IdF].AlgoLabel) { "|$($ActiveMiners[$_.IdF].AlgoLabel)" }) } },
                @{Label = "Coin"; Expression = { $ActiveMiners[$_.IdF].Pool.Symbol + $(if ($ActiveMiners[$_.IdF].AlgorithmDual) { "_$($ActiveMiners[$_.IdF].PoolDual.Symbol)" }) } },
                @{Label = "Pool"; Expression = { $ActiveMiners[$_.IdF].Pool.PoolName + $(if ($ActiveMiners[$_.IdF].AlgorithmDual) { "/$($ActiveMiners[$_.IdF].PoolDual.PoolName)" }) } },
                @{Label = "Miner"; Expression = { $ActiveMiners[$_.IdF].Name } },
                @{Label = "PwLmt"; Expression = { if ($_.PowerLimit -gt 0) { $_.PowerLimit } } },
                @{Label = "Launch"; Expression = { $_.Stats.ActivatedTimes } },
                @{Label = "Best"; Expression = { $_.Stats.BestTimes } },
                @{Label = "ActiveTime"; Expression = { if ($_.Stats.ActiveTime -le 3600) { "{0:N1} min" -f ($_.Stats.ActiveTime / 60) } else { "{0:N1} hours" -f ($_.Stats.ActiveTime / 3600) } } },
                @{Label = "LastTimeActive"; Expression = { $($_.Stats.LastTimeActive).tostring("dd/MM/yy H:mm") } },
                @{Label = "Status"; Expression = { $_.Status } }
            ) | Out-Host

            $RepaintScreen = $false
        }

        $FirstLoopExecution = $false

        # Loop for reading key and wait
        Set-ConsolePosition 0 $YToWriteMessages
        if (-not $ExitLoop) {
            $ValidKeys = @('P', 'C', 'H', 'E', 'W', 'U', 'T', 'B', 'S', 'X', 'Q', 'D', 'R') + [string[]]$DeviceGroups.Id
            $KeyPressed = Read-KeyboardTimed -SecondsToWait 3 -ValidKeys $ValidKeys

            switch -regex ($KeyPressed) {
                'P' { $Screen = 'Profits'; Log "Switch to Profits screen" }
                'C' { $Screen = 'Current'; Log "Switch to Current screen" }
                'H' { $Screen = 'History'; Log "Switch to History screen" }
                'S' { $Screen = 'Stats'; Log "Switch to Stats screen" }
                'E' { $ExitLoop = $true; Log "Forced end of interval by E key" }
                'W' { $Screen = 'Wallets'; Log "Switch to Wallet screen" }
                'U' { if ($Screen -eq "Wallets") { $WalletsUpdate = $null }; Log "Update wallets" }
                'T' { if ($Screen -eq "Profits") { $ProfitsScreenLimit = $(if ($ProfitsScreenLimit -eq $InitialProfitsScreenLimit) { 1000 } else { $InitialProfitsScreenLimit }); Log "Toggle Profits Top" } }
                'B' { if ($Screen -eq "Profits") { $ShowBestMinersOnly = -not $ShowBestMinersOnly }; Log "Toggle Profits Best" }
                'X' { try { Set-WindowSize 170 50 } catch { }; Log "Reset screen size" }
                'Q' { $Quit = $true; $ExitLoop = $true; Log "Exit by Q key" }
                'D' {
                    if (-not (Test-Path "./Dump")) { New-Item -Path ./Dump -ItemType directory -Force | Out-Null }
                    $Pools | ConvertTo-Json -Depth 10 | Set-Content ./Dump/Pools.json
                    $ActiveMiners | ConvertTo-Json -Depth 10 | Set-Content ./Dump/Miners.json
                    $DeviceGroups | ConvertTo-Json -Depth 10 | Set-Content ./Dump/DeviceGroups.json
                }
                'R' {
                    # Reset failed miners
                    $ActiveMiners.SubMiners | Where-Object { $_.Status -eq 'Failed' } | ForEach-Object {
                        $_.Status = 'Idle'
                        $_.Stats.FailedTimes = 0
                        Log "Reset failed miner status: $($ActiveMiners[$_.IdF].Name)/$($ActiveMiners[$_.IdF].Algorithms)"
                    }
                }
                "\d" {
                    if ($DeviceGroups | Where-Object { $_.ID -eq "$KeyPressed" }) {
                        $DeviceGroups | Where-Object { $_.ID -eq "$KeyPressed" } | ForEach-Object { $_.Enabled = -not $_.Enabled }
                        $ExitLoop = $true
                        Log "Toggle Device group $_"
                    }
                }
            }

            if ($ValidKeys -contains $KeyPressed) {
                $RepaintScreen = $true
            }
        }

        if ((Get-Date) -ge $LoopStartTime.AddSeconds($Interval.Duration)) {

            # If last interval was benchmark and no speed detected mark as failed
            $ActiveMiners.SubMiners | Where-Object Best | ForEach-Object {
                if ($_.NeedBenchmark -and $_.SpeedReads.Count -eq 0) {
                    $_.Status = 'PendingFail'
                    $_.Stats.FailedTimes++
                    Log "No speed detected while benchmarking $($ActiveMiners[$_.IdF].Name)/$($ActiveMiners[$_.IdF].Algorithm) (id $($ActiveMiners[$_.IdF].Id))" -Severity Warn
                }
            }
            # If interval is over, Exit main loop
            $ExitLoop = $true
            Log "Interval ends by time: $($Interval.Duration)" -Severity Debug
        }

        Send-ErrorsToLog $LogFile

    } # End mining loop

    Remove-Variable Miners
    Remove-Variable Pools
    Get-Job -State Completed | Remove-Job
    [GC]::Collect() # Force garbage collector for free memory
} # End detection loop

Log "Exiting Forager"
$LogFile.close()

Clear-Files
$ActiveMiners | Where-Object Process -ne $null | ForEach-Object { try { Stop-SubProcess $_.Process } catch { } }
Stop-Autoexec
