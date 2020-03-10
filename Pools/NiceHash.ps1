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
$WalletMode = "Wallet"
$RewardType = "PPS"
$Result = @()

if ($Querymode -eq "Info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Autoexchange to BTC, No registration required. Register and set BTC_NH for lower fees"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $true
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}

# if ($Querymode -eq "Wallet") {
#     $Info.user = ($Info.user -split '\.')[0]
#     $Request = Invoke-APIRequest -Url $("https://api.nicehash.com/api?method=stats.provider&addr=" + $Info.user) -Retry 3 |
#     Select-Object -ExpandProperty result | Select-Object -ExpandProperty stats

#     if ($Request) {
#         $Result = [PSCustomObject]@{
#             Pool     = $name
#             Currency = "BTC"
#             Balance  = ($Request | Measure-Object -Sum -Property balance).Sum
#         }
#         Remove-Variable Request
#     }
# }

if ($Querymode -eq "Core") {

    if (-not $Wallets.BTC_NH -and -not $Wallets.BTC) {
        Write-Warning "$Name BTC or BTC_NH wallets not defined in config.ini"
        Exit
    }

    $Request = Invoke-APIRequest -Url "https://api2.nicehash.com/main/api/v2/public/simplemultialgo/info/" -Retry 3 |
    Select-Object -ExpandProperty miningAlgorithms
    $AlgosRequest = Invoke-APIRequest -Url "https://api2.nicehash.com/main/api/v2/mining/algorithms/" -Retry 3 |
    Select-Object -ExpandProperty miningAlgorithms | Where-Object enabled -eq $true

    if (-not $Request) {
        Write-Warning "$Name API NOT RESPONDING...ABORTING"
        Exit
    }

    $Locations = @{
        US = 'usa'
        EU = 'eu'
    }

    $Result = $Request | Where-Object { $_.paying -gt 0 } | ForEach-Object {
        $Pool = $AlgosRequest | Where-Object algorithm -eq $_.algorithm

        $Algo = Get-AlgoUnifiedName ($_.algorithm)

        $Divisor = 100000000

        foreach ($Location in $Locations.Keys) {

            # $EnableSSL = (@('CnV7', 'CnV8', 'Equihash150') -contains $Algo)

            [PSCustomObject]@{
                Algorithm             = $Algo
                Info                  = $Algo
                Price                 = [decimal]$_.paying / $Divisor
                Protocol              = "stratum+tcp"
                # ProtocolSSL           = "ssl"
                Host                  = $Pool.algorithm.ToLower() + "." + $Locations.$Location + ".nicehash.com"
                # HostSSL               = $Pool.algorithm + "." + $Locations.$Location + ".nicehash.com"
                Port                  = $Pool.port
                # PortSSL               = $Pool.port + 30000
                User                  = $(if ($Wallets.BTC_NH) { $Wallets.BTC_NH } else { $Wallets.BTC }) + '.' + "#WorkerName#"
                Pass                  = "x"
                Location              = $Location
                # SSL                   = $EnableSSL
                Symbol                = Get-CoinSymbol -Coin $Algo
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolName              = $Name
                WalletMode            = $WalletMode
                WalletSymbol          = "BTC"
                Fee                   = $(if ($Wallets.BTC_NH) { 0.02 } else { 0.05 })
                EthStMode             = 3
                RewardType            = $RewardType
            }
        }
    }
    Remove-Variable Request
}

$Result
Remove-Variable Result
