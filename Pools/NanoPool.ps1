param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$WalletMode = "Wallet"
$RewardType = "PPLS"
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
    $Request = Invoke-APIRequest -Url $("https://api.nanopool.org/v1/" + $Info.Symbol.ToLower() + "/balance/" + $Info.User) -Retry 3
    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $Name
            Currency = $Info.Symbol
            Balance  = $Request.Data
        }
    }
}

if ($Querymode -eq "Core") {

    $Pools = @(
        [PSCustomObject]@{ Coin = "Ethereum"        ; Symbol = "ETH"  ; Algo = "Ethash"     ; Port = 9999  ; Fee = 0.01 ; Divisor = 1e6 }
        [PSCustomObject]@{ Coin = "EthereumClassic" ; Symbol = "ETC"  ; Algo = "Ethash"     ; Port = 19999 ; Fee = 0.01 ; Divisor = 1e6 }
        [PSCustomObject]@{ Coin = "Monero"          ; Symbol = "XMR"  ; Algo = "CnV8"       ; Port = 14444 ; Fee = 0.01 ; Divisor = 1   ; PortSSL = 14433 }
        [PSCustomObject]@{ Coin = "Pascalcoin"      ; Symbol = "PASC" ; Algo = "RandomHash" ; Port = 15556 ; Fee = 0.02 ; Divisor = 1 }
        [PSCustomObject]@{ Coin = "Raven"           ; Symbol = "RVN"  ; Algo = "X16r"       ; Port = 12222 ; Fee = 0.01 ; Divisor = 1e6 }
        [PSCustomObject]@{ Coin = "Grin"            ; Symbol = "GRIN" ; Algo = "Cuckaroo29" ; Port = 12111 ; Fee = 0.01 ; Divisor = 1   ; WalletSymbol = "GRIN29" }
    )

    #generate a pool for each location and add API data
    $Result = $Pools | Where-Object { $Wallets.($_.Symbol) -ne $null } | ForEach-Object {
        $PoolSymbol = (@($_.WalletSymbol, $_.Symbol) -ne $null)[0]
        $f = 1000
        $RequestP = Invoke-APIRequest -Url $("https://api.nanopool.org/v1/" + $PoolSymbol.ToLower() + "/approximated_earnings/$f") -Retry 1
        $RequestW = Invoke-APIRequest -Url $("https://api.nanopool.org/v1/" + $PoolSymbol.ToLower() + "/pool/activeworkers") -Retry 1

        $Locations = @{
            Eu   = $PoolSymbol.ToLower() + "-eu1.nanopool.org"
            US   = $PoolSymbol.ToLower() + "-us-east1.nanopool.org"
            Asia = $PoolSymbol.ToLower() + "-asia1.nanopool.org"
        }

        ForEach ($Loc in $Locations.Keys) {
            [PSCustomObject]@{
                Algorithm             = $_.Algo
                Info                  = $_.Coin
                Price                 = [decimal]$RequestP.data.day.bitcoins / $_.Divisor / $f
                Protocol              = "stratum+tcp"
                ProtocolSSL           = "stratum+tls"
                Host                  = $Locations.$Loc
                Port                  = $_.Port
                PortSSL               = $_.PortSSL
                User                  = $Wallets.($_.Symbol) + "/#WorkerName#" + $(if ($Config.Email) { "/" + $Config.Email })
                Pass                  = "x"
                Location              = $Loc
                SSL                   = [bool]$PortSSL
                Symbol                = $_.Symbol
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolWorkers           = $RequestW.Data
                PoolName              = $Name
                WalletMode            = $WalletMode
                WalletSymbol          = $PoolSymbol
                Fee                   = $_.Fee
                EthStMode             = 0
                RewardType            = $RewardType
            }
        }
        Start-Sleep -Milliseconds 250 # Prevent API Saturation
    }
}

$Result
Remove-Variable Result
