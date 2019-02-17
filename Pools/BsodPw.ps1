param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null ,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$ActiveOnAutomatic24hMode = $false
$WalletMode = 'Wallet'
$ApiUrl = 'http://api.bsod.pw/api'
$Locations = @{
    'US'   = 'us.bsod.pw'
    'EU'   = 'eu.bsod.pw'
    'ASIA' = 'asia.bsod.pw'
}
$RewardType = "PPS"
$Result = @()

if ($Querymode -eq "Info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "No registration, No autoexchange, need wallet for each coin"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $true
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}

if ($Querymode -eq "Speed") {
    $Request = Invoke-APIRequest -Url $($ApiUrl + "/walletEx?address=" + $Info.user) -Retry 1

    if ($Request) {
        $Result = $Request.Miners | ForEach-Object {
            [PSCustomObject]@{
                PoolName   = $Name
                Version    = $_.version
                Algorithm  = Get-AlgoUnifiedName $_.Algo
                WorkerName = (($_.password -split 'id=')[1] -split ',')[0]
                Diff       = $_.difficulty
                Rejected   = $_.rejected
                HashRate   = $_.accepted
            }
        }
        Remove-Variable Request
    }
}

if ($Querymode -eq "Wallet") {
    $Request = Invoke-APIRequest -Url $($ApiUrl + "/wallet?address=" + $Info.user) -Retry 3

    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $Name
            Currency = $Request.currency
            Balance  = $Request.balance
        }
        Remove-Variable Request
    }
}

if ($Querymode -eq "Core") {
    $Request = Invoke-APIRequest -Url $($ApiUrl + "/status") -Retry 3
    $RequestCurrencies = Invoke-APIRequest -Url $($ApiUrl + "/currencies") -Retry 3
    if (-not $RequestCurrencies) {
        Write-Warning "$Name API NOT RESPONDING...ABORTING"
        Exit
    }

    $RequestCurrencies | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {
        $RequestCurrencies.$_.'24h_blocks' -gt 0 -and
        $RequestCurrencies.$_.HashRate -gt 0
    } | ForEach-Object {

        $Coin = $RequestCurrencies.$_
        $Pool_Algo = Get-AlgoUnifiedName $Coin.algo
        $Pool_Coin = Get-CoinUnifiedName $Coin.name
        $Pool_Symbol = $_

        $Divisor = 1000000

        switch ($Pool_Algo) {
            "blake14r" {$Divisor *= 1000}
            "blake2s" {$Divisor *= 1000}
            "blakecoin" {$Divisor *= 1000}
            "equihash" {$Divisor /= 1000}
            "keccakc" {$Divisor *= 1000}
            "skein" {$Divisor *= 1000}
            "x16r" {$Divisor *= 1000}
            "yescrypt" {$Divisor /= 1000}
        }

        foreach ($Location in $Locations.Keys) {
            $Result += [PSCustomObject]@{
                Algorithm             = $Pool_Algo
                Info                  = $Pool_Coin
                Price                 = [decimal]$Coin.estimate / $Divisor
                Price24h              = [decimal]$Coin.'24h_btc' / $Divisor
                Protocol              = "stratum+tcp"
                Host                  = $Locations.$Location
                Port                  = [int]$Coin.port
                User                  = $Wallets.$Pool_Symbol
                Pass                  = "c=$Pool_Symbol,id=#WorkerName#"
                Location              = $Location
                SSL                   = $false
                Symbol                = $Pool_Symbol
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolWorkers           = [int]$Coin.workers
                PoolHashRate          = [decimal]$Coin.HashRate
                WalletMode            = $WalletMode
                Walletsymbol          = $Pool_Symbol
                PoolName              = $Name
                Fee                   = $Coin.fees / 100
                RewardType            = $RewardType
            }
        }
    }
    Remove-Variable Request
    Remove-Variable RequestCurrencies
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
