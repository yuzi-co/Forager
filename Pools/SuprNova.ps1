param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$ActiveOnAutomatic24hMode = $false
$WalletMode = "ApiKey"
$RewardType = "PPLS"
$Result = @()

if ($Querymode -eq "Info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Must register and set wallet for each coin on web"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $true
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}

if ($Querymode -eq "ApiKey") {
    $Request = Invoke-APIRequest -Url $("https://" + $Info.Symbol + ".suprnova.cc/index.php?page=api&action=getuserbalance&api_key=" + $Info.ApiKey + "&id=") -Retry 3 |
        Select-Object -ExpandProperty getuserbalance | Select-Object -ExpandProperty data

    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $name
            Currency = $Info.Symbol
            Balance  = $Request.confirmed + $Request.unconfirmed
        }
    }
}

if ($Querymode -eq "Speed") {
    $Request = Invoke-APIRequest -Url $("https://" + $Info.Symbol + ".suprnova.cc/index.php?page=api&action=getuserworkers&api_key=" + $Info.ApiKey) -Retry 1 |
        Select-Object -ExpandProperty getuserworkers | Select-Object -ExpandProperty data

    if ($Request) {
        $Request | ForEach-Object {
            $Result += [PSCustomObject]@{
                PoolName   = $name
                Diff       = $_.difficulty
                WorkerName = ($_.UserName -split "\.")[1]
                HashRate   = $_.HashRate
            }
        }
    }
}

if ($Querymode -eq "Core") {

    if (-not $Config.UserName -and -not $PoolConfig.$Name.UserName) {
        Write-Warning "$Name UserName not defined"
        Exit
    }

    $Pools = @(
        [PSCustomObject]@{ Coin = "Beam"            ; Symbol = "BEAM"  ; Algo = "Equihash150" ; WalletSymbol = "beam"     ; Port = 7776 ; PortSSL = 7777 }
        [PSCustomObject]@{ Coin = "BitcoinGold"     ; Symbol = "BTG"   ; Algo = "Equihash144" ; WalletSymbol = "btg"      ; Port = 8866 ; PortSSL = 8817 }
        [PSCustomObject]@{ Coin = "BitcoinInterest" ; Symbol = "BCI"   ; Algo = "ProgPOW"     ; WalletSymbol = "bci"      ; Port = 9166 }
        [PSCustomObject]@{ Coin = "BitcoinZ"        ; Symbol = "BTCZ"  ; Algo = "Equihash144" ; WalletSymbol = "btcz"     ; Port = 6586 }
        [PSCustomObject]@{ Coin = "BitCore"         ; Symbol = "BTX"   ; Algo = "Bitcore"     ; WalletSymbol = "btx"      ; Port = 3629 }
        [PSCustomObject]@{ Coin = "BitSend"         ; Symbol = "BSD"   ; Algo = "Xevan"       ; WalletSymbol = "bsd"      ; Port = 8686 }
        # [PSCustomObject]@{ Coin = "Credits"         ; Symbol = "CRDS"  ; Algo = "Argon2d250"  ; WalletSymbol = "crds"     ; Port = 2771 }
        [PSCustomObject]@{ Coin = "Dynamic"         ; Symbol = "DYN"   ; Algo = "Argon2d500"  ; WalletSymbol = "dyn"      ; Port = 5960 }
        [PSCustomObject]@{ Coin = "Garlicoin"       ; Symbol = "GRLC"  ; Algo = "Allium"      ; WalletSymbol = "grlc"     ; Port = 8600 }
        [PSCustomObject]@{ Coin = "GenX"            ; Symbol = "GENX"  ; Algo = "Equihash192" ; WalletSymbol = "genx"     ; Port = 9983 }
        [PSCustomObject]@{ Coin = "HODLcoin"        ; Symbol = "HODL"  ; Algo = "HOdl"        ; WalletSymbol = "hodl"     ; Port = 4693 }
        [PSCustomObject]@{ Coin = "Pigeon"          ; Symbol = "PGN"   ; Algo = "X16s"        ; WalletSymbol = "pign"     ; Port = 4096 }
        [PSCustomObject]@{ Coin = "Polytimos"       ; Symbol = "POLY"  ; Algo = "Polytimos"   ; WalletSymbol = "poly"     ; Port = 7935 }
        [PSCustomObject]@{ Coin = "Raven"           ; Symbol = "RVN"   ; Algo = "X16r"        ; WalletSymbol = "rvn"      ; Port = 6666 }
        [PSCustomObject]@{ Coin = "ROIcoin"         ; Symbol = "ROI"   ; Algo = "HOdl"        ; WalletSymbol = "roi"      ; Port = 4699 }
        [PSCustomObject]@{ Coin = "SafeCash"        ; Symbol = "SCASH" ; Algo = "Equihash144" ; WalletSymbol = "scash"    ; Port = 8983 }
        [PSCustomObject]@{ Coin = "UBIQ"            ; Symbol = "UBQ"   ; Algo = "Ethash"      ; WalletSymbol = "ubiq"     ; Port = 3030 }
        [pscustomobject]@{ Coin = "Veil"            ; Symbol = "VEIL"  ; Algo = "X16rt"       ; WalletSymbol = "veil"     ; Port = 7220 }
        [pscustomobject]@{ Coin = "Verge"           ; Symbol = "XVG"   ; Algo = "X17"         ; WalletSymbol = "xvg-x17"  ; Port = 7477 }
        [PSCustomObject]@{ Coin = "Vertcoin"        ; Symbol = "VTC"   ; Algo = "Lyra2v3"     ; WalletSymbol = "vtc"      ; Port = 5778 }
        [PSCustomObject]@{ Coin = "XDNA"            ; Symbol = "XDNA"  ; Algo = "Hex"         ; WalletSymbol = "xdna"     ; Port = 4919 }
        [PSCustomObject]@{ Coin = "Zero"            ; Symbol = "ZER"   ; Algo = "Equihash192" ; WalletSymbol = "zero"     ; Port = 6568 }
    )

    $Result = $Pools | ForEach-Object {

        [PSCustomObject]@{
            Algorithm             = $_.Algo
            Info                  = $_.Coin
            Protocol              = "stratum+tcp"
            ProtocolSSL           = "ssl"
            Host                  = $_.WalletSymbol + ".suprnova.cc"
            HostSSL               = $_.WalletSymbol + ".suprnova.cc"
            Port                  = $_.Port
            PortSSL               = $_.PortSSL
            User                  = $(if ($Config.("UserName_" + $Name)) {$Config.("UserName_" + $Name)} else {$Config.UserName}) + ".#WorkerName#"
            Pass                  = "x"
            Location              = "US"
            SSL                   = [bool]($_.PortSSL)
            Symbol                = $_.Symbol
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolName              = $Name
            WalletMode            = $WalletMode
            WalletSymbol          = $_.WalletSymbol
            Fee                   = 0.01
            EthStMode             = 3
            RewardType            = $RewardType
        }
    }
    Remove-Variable Pools
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
