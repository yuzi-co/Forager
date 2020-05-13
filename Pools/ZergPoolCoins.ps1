param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$ActiveOnAutomatic24hMode = $false
$WalletMode = 'Wallet'
$ApiUrl = 'http://api.zergpool.com:8080/api'
$MineUrl = 'mine.zergpool.com'
$Location = 'US'
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
    if (-not $RequestCurrencies -or -not $Request) {
        Write-Warning "$Name API NOT RESPONDING...ABORTING"
        Exit
    }

    $Result = $RequestCurrencies | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {
        $Wallets.(($_ -split '-')[0]) -ne $null -and
        (
            $RequestCurrencies.$_.hashrate_shared -gt 0
        ) -or (
            $RequestCurrencies.$_.hashrate_shared -eq $null -and
            $RequestCurrencies.$_.hashrate -gt 0
        )

    } | ForEach-Object {

        $Coin = $RequestCurrencies.$_
        $Pool_Algo = Get-AlgoUnifiedName ($Coin.algo -replace '_')
        $Pool_Coin = Get-CoinUnifiedName $Coin.name
        $Pool_Symbol = ($_ -split '-')[0]

        $Algo = $Request.($Coin.algo)
        if ($Coin.algo -like 'cryptonight_*') {
            $MineHost = $MineUrl
            if ($Coin.algo -eq 'cryptonight_fast') {
                $Pool_Algo = 'CnHalf'
            }
        } else {
            $MineHost = $Algo.name + "." + $MineUrl
        }

        $Divisor = 1e9 * [decimal]$Coin.mbtc_mh_factor

        [PSCustomObject]@{
            Algorithm             = $Pool_Algo
            Info                  = $Pool_Coin
            Price                 = $(if ($Divisor) { [decimal]$Coin.estimate / $Divisor })
            Price24h              = $(if ($Divisor) { $(if ($Coin.'24h_btc_shared' -ne $null) { [decimal]$Coin.'24h_btc_shared' } else { [decimal]$Coin.'24h_btc' }) / $Divisor })
            Protocol              = "stratum+tcp"
            Host                  = $MineHost
            Port                  = [int]$Coin.port
            User                  = $Wallets.$Pool_Symbol
            Pass                  = "c=$Pool_Symbol,mc=$Pool_Symbol"
            Location              = $Location
            SSL                   = $false
            Symbol                = $Pool_Symbol
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolWorkers           = [int]$(if ($Coin.workers_shared -ne $null) { $Coin.workers_shared } else { $Coin.workers })
            PoolHashRate          = [int64]$(if ($Coin.hashrate_shared -ne $null) { $Coin.hashrate_shared } else { $Coin.hashrate })
            WalletMode            = $WalletMode
            Walletsymbol          = $Pool_Symbol
            PoolName              = $Name
            Fee                   = $Algo.fees / 100
            RewardType            = $RewardType
        }
    }
    Remove-Variable Request
    Remove-Variable RequestCurrencies
}

$Result | ConvertTo-Json | Set-Content pool.json
$Result
Remove-Variable Result
