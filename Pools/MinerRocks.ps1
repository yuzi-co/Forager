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
        'aeon' { 1e21 }
        'bittube' { 1e9 }
        'haven' { 1e13 }
        'loki' { 1e9 }
        'masari' { 1e13 }
        'ryo' { 1e16 }
        'stellite' { 1e3 }
        'turtle' { 1e6 }
        Default { 1e9 }
    }
    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $Name
            Currency = $Info.Symbol
            Balance  = ($Request.stats.balance + $Request.stats.pendingIncome ) / $Divisor
        }
        Remove-Variable Request
    }
}

if ($Querymode -eq "Core") {

    $Response = Invoke-WebRequest -Uri "https://miner.rocks"

    $Regex = "[^\/]{name:\s*'(\w+)',\s*host:\s*'(\S+)'.*kind:\s*`"(\S*)`""
    $Pools = $Response.Content -split "`n" -match $Regex | ForEach-Object {
        $_ -match $Regex | Out-Null

        [PSCustomObject]@{
            Coin = $Matches[1]
            Url  = $Matches[2]
            Algo = if ($Matches[3]) {$Matches[3]} else {'Cn'}
        }
    } | Sort-Object -Property Coin -Unique

    $Result = $Pools | Where-Object { $_.Algo -notin @('Cn')} | ForEach-Object {

        $PoolResponse = Invoke-RestMethod -Uri ($_.Url + '/api/stats') -UseBasicParsing

        if ($PoolResponse.pool.heightOK -and $Wallets.($PoolResponse.config.symbol) -ne $null) {

            $Algo = Get-AlgoUnifiedName $_.Algo
            switch ($_.Coin) {
                "BitTube" { $Algo = 'CnSaber' }
                "Haven" { $Algo = 'CnHaven' }
                "Masari" { $Algo = 'CnHalf' }
                "Saronite" { $Algo = 'CnHaven' }
            }

            $Coin = Get-CoinUnifiedName $_.Coin

            [PSCustomObject]@{
                Info                  = $Coin
                Algorithm             = $Algo
                Protocol              = "stratum+tcp"
                Host                  = $($_.Url -split '//')[1]
                Port                  = [int]$($PoolResponse.config.ports | Sort-Object {$_.desc -like "*Modern*GPU*"} -Descending | Select-Object -First 1 -ExpandProperty port)
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
                Fee                   = $PoolResponse.config.fee / 100
                RewardType            = $RewardType

                Hashrate              = $PoolResponse.pool.hashrate
                Workers               = $PoolResponse.pool.workers

                Price                 = $PoolResponse.charts.profitBtc[-1][1] / 1e6
            }

        }
    }
}

$Result | ConvertTo-Json | Set-Content $info.SharedFile
Remove-Variable Result
