param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$WalletMode = 'Wallet'
$ApiUrl = 'http://api.zergpool.com:8080/api'
$MineUrl = 'mine.zergpool.com'
$Location = 'US'
$RewardType = "PPS"
$Result = @()

if ($Querymode -eq "Info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Autoexchange to BTC/LTC/DASH, No registration"
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
    if (-not $Request) {
        Write-Warning "$Name API NOT RESPONDING...ABORTING"
        Exit
    }

    $Currency = if ($Config.("Currency_" + $Name)) { $Config.("Currency_" + $Name) } else { $Config.Currency }

    if (
        @('BTC', 'LTC', 'DASH') -notcontains $Currency -and
        -not ( $RequestCurrencies -and ($RequestCurrencies | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object { $_ -eq $Currency }))
    ) {
        Write-Warning "$Name $Currency may not be supported for payment"
    }

    if (-not $Wallets.$Currency) {
        Write-Warning "$Name $Currency wallet not defined"
        Exit
    }

    ### Option 1 - Mine in particular algorithm
    $Result = $Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {
        $Request.$_.HashRate -gt 0
    } | ForEach-Object {
        $Algo = $Request.$_
        $Pool_Algo = Get-AlgoUnifiedName ($Algo.name -replace '_')
        if ($Algo.name -like 'cryptonight_*') {
            $MineHost = $MineUrl
            if ($Algo.name -eq 'cryptonight_fast') {
                $Pool_Algo = 'CnHalf'
            }
        } else {
            $MineHost = $Algo.name + "." + $MineUrl
        }

        $Divisor = 1000000 * $Algo.mbtc_mh_factor

        [PSCustomObject]@{
            Algorithm             = $Pool_Algo
            Info                  = $Pool_Algo
            Price                 = [decimal]$Algo.estimate_current / $Divisor
            Price24h              = [decimal]$Algo.estimate_last24h / $Divisor
            Actual24h             = [decimal]$Algo.actual_last24h / 1000 / $Divisor
            Protocol              = "stratum+tcp"
            Host                  = $MineHost
            Port                  = [int]$Algo.port
            User                  = $Wallets.$Currency
            Pass                  = "c=$Currency,ID=#WorkerName#"
            Location              = $Location
            SSL                   = $false
            Symbol                = Get-CoinSymbol -Coin $Pool_Algo
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolWorkers           = $(if ($Algo.workers_shared -ne $null) { [int]$Algo.workers_shared } else { [int]$Algo.workers })
            PoolHashRate          = [decimal]$Algo.HashRate
            WalletMode            = $WalletMode
            WalletSymbol          = $Currency
            PoolName              = $Name
            Fee                   = $Algo.fees / 100
            RewardType            = $RewardType
        }
    }
    Remove-Variable Request
}

$Result
Remove-Variable Result
