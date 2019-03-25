param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$WalletMode = "Wallet"
$RewardType = "PPLS"
$Result = @()

if ($Querymode -eq "Info") {
    $Result = [PSCustomObject]@{
        Disclaimer            = "No registration, No autoexchange, need wallet for each coin"
        ActiveOnManualMode    = $ActiveOnManualMode
        ActiveOnAutomaticMode = $ActiveOnAutomaticMode
        ApiData               = $true
        WalletMode            = $WalletMode
        RewardType            = $RewardType
    }
}

if ($Querymode -eq "Speed") {
    $Request = Invoke-APIRequest -Url $("https://" + $Info.Symbol + ".miner.rocks/api/stats_address?address=" + $Info.User + "&longpoll=false") -Retry 3 -MaxAge 1

    if ($Request -and $Request.stats.workers) {
        $Request.stats.workers | Get-Member -Type NoteProperty | ForEach-Object {
            $Result += [PSCustomObject]@{
                PoolName   = $Name
                WorkerName = $_.name
                HashRate   = $Request.stats.workers.($_.name).hashrate
            }
        }
        Remove-Variable Request
    }
}

if ($Querymode -eq "Wallet") {
    $Request = Invoke-APIRequest -Url $("https://" + $Info.Symbol + ".miner.rocks/api/stats_address?address=" + $Info.User + "&longpoll=false") -Retry 3
    $Divisor = switch ($Info.Symbol) {
        'aeon' { 1e12 }
        'bittube' { 1e8 }
        'boolberry' { 1e12 }
        'graft' { 1e10 }
        'haven' { 1e12 }
        'loki' { 1e9 }
        'masari' { 1e12 }
        'monero' { 1e12 }
        'purk' { 1e6 }
        'qrl' { 1e9 }
        'ryo' { 1e9 }
        'saronite' { 1e9 }
        'stellite' { 100 }
        'turtle' { 100 }
        Default {
            $StatsRequest = Invoke-APIRequest -Url $("https://" + $Info.Symbol + ".miner.rocks/api/stats") -Retry 3
            $StatsRequest.config.coinUnits
        }
    }
    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $Name
            Currency = $Info.Symbol
            Balance  = ([double]$Request.stats.balance + [double]$Request.stats.pendingIncome ) / $Divisor
        }
        Remove-Variable Request
    }
}

if ($Querymode -eq "Core") {

    $Response = Invoke-WebRequest -Uri "https://miner.rocks" -UseBasicParsing

    $Regex = "^{name:'(\w+)',host:'(\S+)',lastStats:null,kind:`"(\S*)`""
    $Pools = $Response.Content -split "`n" -replace "\s" -match $Regex | ForEach-Object {
        $_ -match $Regex | Out-Null

        [PSCustomObject]@{
            Coin   = $Matches[1]
            Url    = $Matches[2]
            Algo   = if ($Matches[3]) {$Matches[3]} else {'Cn'}
            Symbol = Get-CoinSymbol -Coin $Matches[1]
        }
    } | Sort-Object -Property Coin -Unique

    $Result = $Pools | Where-Object {
        $_.Algo -notin @('Cn') -and
        $Wallets.($_.Symbol)
    } | ForEach-Object {

        $PoolResponse = Invoke-RestMethod -Uri ($_.Url + '/api/stats') -UseBasicParsing

        if ($PoolResponse.pool.heightOK) {

            $Algo = Get-AlgoUnifiedName $_.Algo
            switch ($_.Coin) {
                "BitTube" { $Algo = 'CnSaber' }
                "Haven" { $Algo = 'CnHaven' }
                "Masari" { $Algo = 'CnHalf' }
                "Saronite" { $Algo = 'CnHaven' }
                "Monero" { $Algo = 'CnR' }
            }

            $Coin = Get-CoinUnifiedName $_.Coin

            $Port = $PoolResponse.config.ports |
                Where-Object {
                $_.disabled -ne $true -and
                $_.virtual -ne $true
            } | Sort-Object {if ($PoolResponse.config.ppsEnabled) {$_.rewards -eq 'pps'}}, {$_.desc -like '*Modern*GPU*'} -Descending |
                Select-Object -First 1

            [PSCustomObject]@{
                Info                  = $Coin
                Algorithm             = $Algo
                Protocol              = "stratum+tcp"
                Host                  = $($_.Url -split '//')[1]
                Port                  = [int]$Port.port
                User                  = $Wallets.($PoolResponse.config.symbol)
                Pass                  = "w=#WorkerName#"

                Location              = "EU"
                SSL                   = $false
                Symbol                = $PoolResponse.config.symbol
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolName              = $Name
                WalletMode            = $WalletMode
                WalletSymbol          = $($($_.Url -split '//')[1] -split '\.')[0]
                Fee                   = $(if ($Port.rewards -eq 'pps') {$PoolResponse.config.ppsFee} else {$PoolResponse.config.fee}) / 100
                RewardType            = $(if ($Port.rewards -eq 'pps') {'PPS'} else {'PPLS'})

                Hashrate              = $PoolResponse.pool.hashrate
                Workers               = $PoolResponse.pool.workers

                Price                 = $PoolResponse.charts.profitBtc[-1][1] / 1e6
            }
        }
    }
}

$Result
Remove-Variable Result
