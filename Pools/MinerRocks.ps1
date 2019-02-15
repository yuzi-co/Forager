param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$WalletMode = "WALLET"
$RewardType = "PPLS"
$Result = @()

if ($Querymode -eq "Info") {
    $Result = [PSCustomObject]@{
        Disclaimer            = "Must set wallet for each coin on web, set login on config.ini file"
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
        'bittube' { 1e14 }
        'haven' { 1e12 }
        'masari' { 1e12 }
        'stellite' { 1e5 }
        Default { 1e12 }
    }
    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $Name
            currency = $Info.Symbol
            balance  = ($Request.stats.balance + $Request.stats.pendingIncome ) / $Divisor
        }
        Remove-Variable Request
    }
}

if (($Querymode -eq "Core" ) -or ($Querymode -eq "Menu")) {

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

    $Pools | Where-Object { $_.Algo -notin @('Cn')} | ForEach-Object {

        $PoolResponse = Invoke-RestMethod -Uri ($_.Url + '/api/stats') -UseBasicParsing

        if ($PoolResponse.pool.heightOK) {

            $Algo = Get-AlgoUnifiedName $_.Algo
            switch ($_.Coin) {
                "Haven" { $Algo = 'CnHaven' }
                "Saronite" { $Algo = 'CnHaven' }
                "BitTube" { $Algo = 'CnSaber' }
            }

            $Coin = Get-CoinUnifiedName $_.Coin

            if ($CoinsWallets.($PoolResponse.config.symbol)) {
                $Result += [PSCustomObject]@{
                    Info                  = $Coin
                    Algorithm             = $Algo
                    Protocol              = "stratum+tcp"
                    Host                  = $($_.Url -split '//')[1]
                    Port                  = [int]$($PoolResponse.config.ports | Sort-Object {$_.desc -like "*Modern*GPU*"} -Descending | Select-Object -First 1 -ExpandProperty port)
                    User                  = $CoinsWallets.($PoolResponse.config.symbol)
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
}

$Result | ConvertTo-Json | Set-Content $info.SharedFile
Remove-Variable Result
