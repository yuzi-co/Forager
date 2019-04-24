Import-Module .\Include.psm1

### Load configuraion
$global:Config = Get-Config
$global:Wallets = Get-Wallets

Set-OsFlags

### Select Mining mode
Out-HorizontalLine "Select Mining Mode"

[array]$Modes = @(
    [PSCustomObject]@{Option = 0 ; Mode = 'Automatic'    ; Description = 'Automatically choose most profitable coin based on pools current statistics' }
    [PSCustomObject]@{Option = 1 ; Mode = 'Automatic24h' ; Description = 'Automatically choose most profitable coin based on pools 24 hour statistics' }
    [PSCustomObject]@{Option = 2 ; Mode = 'Manual'       ; Description = 'Manual coin selection' }
)
$Modes | Format-Table

do {
    $SelectedOption = Read-Host -Prompt 'Select one option:'
    $MiningMode = $Modes[$SelectedOption].Mode
} until ($MiningMode)

Write-Host "Selected: $MiningMode"


### Selects Pools
Out-HorizontalLine "Select Pool(s)"

[array]$Pools = Get-Pools -Querymode "Info" | Where-Object ("ActiveOn" + $MiningMode + "Mode") -eq $true | Sort-Object Name

$Pools | ForEach-Object {
    $_ | Add-Member Option ([array]::indexof($Pools, $_))
}

$Pools | Format-Table Option, Name, RewardType, Disclaimer

do {
    if ($MiningMode -eq "Manual") {
        do {
            $SelectedOption = Read-Host -Prompt 'Select one pool (Option number):'
        } until ($SelectedOption -match "\d")
    } else {
        $SelectedOption = Read-Host -Prompt 'Select pools (Option numbers separated by comma). 999 for all pools:'
    }

    if ($SelectedOption -eq "999") {
        $PoolsName = $Pools.Name -join ',' -replace "\s+"
    } else {
        $PoolsName = ($SelectedOption -split ',' | ForEach-Object { $Pools[$_].name }) -join ',' -replace "\s+"
    }
} until ($PoolsName)
Write-Host "Selected Pool(s): $PoolsName"


### Select Coins
if ($MiningMode -eq "Manual") {

    #Load coins from pools
    $CoinsPool = @(Get-Pools -Querymode "Core" -PoolsFilterList $PoolsName -Location $Config.Location | Select-Object Info, Symbol, Algorithm, Workers, PoolHashRate, Blocks_24h, Price -Unique | Sort-Object Info)

    $CoinsPool | ForEach-Object {
        $_ | Add-Member Option ([array]::indexof($CoinsPool, $_))
    }

    $CoinsPool | Add-Member YourHashRate 0
    $CoinsPool | Add-Member BtcProfit 0
    $CoinsPool | Add-Member LocalProfit 0

    'Calling Coindesk API' | Write-Host
    $CDKResponse = try {
        Invoke-ApiRequest -Url "https://api.coindesk.com/v1/bpi/currentprice/$($Config.LocalCurrency).json" | Select-Object -ExpandProperty BPI
    } catch {
        $null
        Write-Host "Not responding"
    }

    if (($CoinsPool | Where-Object { [decimal]$_.Price -eq 0 }).Count -gt 0) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        #Add main page coins
        $WtmUrl = Get-WhatToMineURL

        'Calling WhatToMine API' | Write-Host
        $WTMResponse = try {
            Invoke-APIRequest -Url $WtmUrl -Retry 3 | Select-Object -ExpandProperty coins
        } catch {
            $null
            Write-Host "Not responding"
        }
    }

    foreach ($Coin in $CoinsPool) {
        if ($Coin.Symbol -and -not $Coin.Price -and $WTMResponse) {
            #Data from WTM
            $WtmCoin = $WTMResponse.PSObject.Properties.Value | Where-Object {
                $_.tag -eq $Coin.Symbol -and
                (Get-AlgoUnifiedName $_.algorithm) -eq $Coin.Algorithm
            }
            $WTMFactor = Get-WhatToMineFactor ($Coin.Algorithm)
            if ($WtmCoin -and $WTMFactor) {
                $Coin | Add-Member Price ([double]$WtmCoin.Btc_revenue / [double]$WTMFactor) -Force
            }
        }
        $Coin.YourHashRate = (Get-BestHashRateAlgo $Coin.Algorithm).HashRate
        $Coin.BtcProfit = [double]$Coin.Price * [double]$Coin.YourHashRate
        $Coin.LocalProfit = $CDKResponse.$($Config.LocalCurrency).rate_float * [double]$Coin.BtcProfit
    }

    Out-HorizontalLine "Select Coin to mine"
    $CoinsPool | Format-Table -Wrap (
        @{Label = "Opt."; Expression = { $_.Option }; Align = 'right' } ,
        @{Label = "Name"; Expression = { $_.Info }; Align = 'left' } ,
        @{Label = "Symbol"; Expression = { $_.Symbol }; Align = 'left' },
        @{Label = "Algorithm"; Expression = { $_.Algorithm }; Align = 'left' },
        @{Label = "HashRate"; Expression = { (ConvertTo-Hash ($_.YourHashRate)) }; Align = 'right' },
        @{Label = "mBTC/day"; Expression = { if ($_.BtcProfit -gt 0 ) { ($_.BtcProfit * 1000).ToString("n3") } }; Align = 'right' },
        @{Label = $Config.LocalCurrency + "/Day"; Expression = { if ($_.LocalProfit -gt 0 ) { [math]::Round($_.LocalProfit, 2) } }; Align = 'right' }
    )

    do {
        $SelectedOption = Read-Host -Prompt 'Select one option:'
    } until ($SelectedOption -match "\d+")

    $CoinsName = $CoinsPool[$SelectedOption].Info -replace '_', ',' #for dual mining
    $AlgosName = $CoinsPool[$SelectedOption].Algorithm -replace '_', ',' #for dual mining

    Write-Host "Selected option: $AlgosName / $CoinsName"
}

#-----------------Launch Command
$Params = @{
    MiningMode = $MiningMode
    PoolsName  = $PoolsName -split ','
}
if ($MiningMode -eq 'Manual') {
    $Params.Algorithm = $AlgosName
    if ($CoinsName) { $Params.CoinsName = $CoinsName }
}

if ($IsWindows) {
    $SampleFile = "./Data/AutoStart.sample.txt"
    $Autostart = "AutoStart.bat"
} else {
    $SampleFile = "./Data/AutoStart.sh.sample.txt"
    $Autostart = "autostart.sh"
}
if (Test-Path $SampleFile) {

    Out-HorizontalLine "Sample $Autostart"

    $Sample = Get-Content $SampleFile -Raw

    Write-Host ""
    Write-Host $ExecutionContext.InvokeCommand.ExpandString($Sample)
    Write-Host ""

    Out-HorizontalLine "End Sample $Autostart"
}

Pause
& "$PSScriptRoot/Core.ps1" @Params
