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
    $Request = Invoke-APIRequest -Url $("https://" + $Info.Symbol + ".fairpool.xyz/api/stats?login=" + ($Info.user -split "\+")[0]) -Retry 1

    if ($Request -and $Request.Workers) {
        $Request.Workers | ForEach-Object {
            $Result += [PSCustomObject]@{
                PoolName   = $name
                WorkerName = $_[0]
                HashRate   = $_[1]
            }
        }
        Remove-Variable Request
    }
}

if ($Querymode -eq "Wallet") {
    $Request = Invoke-APIRequest -Url $("https://" + $Info.Symbol + ".fairpool.xyz/api/stats?login=" + ($Info.User -split "\+")[0]) -Retry 3
    if ($Request) {
        switch ($Info.Symbol) {
            'pasl' { $Divisor = 1e4 }
            'sumo' { $Divisor = 1e9}
            'loki' { $Divisor = 1e9}
            'xhv' { $Divisor = 1e12}
            'xrn' { $Divisor = 1e9}
            'bloc' { $Divisor = 1e4}
            'purk' { $Divisor = 1e6}
            Default { $Divisor = 1e9 }
        }
        $Result = [PSCustomObject]@{
            Pool     = $name
            Currency = $Info.Symbol
            Balance  = ($Request.balance + $Request.unconfirmed ) / $Divisor
        }
        Remove-Variable Request
    }
}

if ($Querymode -eq "Core") {
    $Pools = @()

    $Pools += [PSCustomObject]@{ Coin = "Akroma"          ; Symbol = "AKA"    ; Algo = "Ethash"      ; WalletSymbol = "aka"     ; Port = 2222 }
    $Pools += [PSCustomObject]@{ Coin = "Bittube"         ; Symbol = "TUBE"   ; Algo = "CnSaber"     ; WalletSymbol = "tube"    ; Port = 6040 }
    $Pools += [PSCustomObject]@{ Coin = "Dogethereum"     ; Symbol = "DOGX"   ; Algo = "Ethash"      ; WalletSymbol = "dogx"    ; Port = 7788 }
    $Pools += [PSCustomObject]@{ Coin = "EthereumClassic" ; Symbol = "ETC"    ; Algo = "Ethash"      ; WalletSymbol = "etc"     ; Port = 4444 }
    $Pools += [PSCustomObject]@{ Coin = "Haven"           ; Symbol = "XHV"    ; Algo = "CnHaven"     ; WalletSymbol = "xhv"     ; Port = 5566 }
    $Pools += [PSCustomObject]@{ Coin = "Lethean"         ; Symbol = "LTHN"   ; Algo = "CnV8"        ; WalletSymbol = "lethean" ; Port = 6070 }
    $Pools += [PSCustomObject]@{ Coin = "Loki"            ; Symbol = "LOKI"   ; Algo = "CnHeavy"     ; WalletSymbol = "loki"    ; Port = 5577 }
    $Pools += [PSCustomObject]@{ Coin = "Masari"          ; Symbol = "MSR"    ; Algo = "CnHalf"      ; WalletSymbol = "msr"     ; Port = 6060 }
    $Pools += [PSCustomObject]@{ Coin = "Metaverse"       ; Symbol = "ETP"    ; Algo = "Ethash"      ; WalletSymbol = "etp"     ; Port = 6666 }
    $Pools += [PSCustomObject]@{ Coin = "Nekonium"        ; Symbol = "NUKO"   ; Algo = "Ethash"      ; WalletSymbol = "nuko"    ; Port = 7777 }
    $Pools += [PSCustomObject]@{ Coin = "PascalLite"      ; Symbol = "PASL"   ; Algo = "Pascal"      ; WalletSymbol = "pasl"    ; Port = 4009 }
    $Pools += [PSCustomObject]@{ Coin = "Pegascoin"       ; Symbol = "PGC"    ; Algo = "Ethash"      ; WalletSymbol = "pgc"     ; Port = 1111 }
    $Pools += [PSCustomObject]@{ Coin = "PURK"            ; Symbol = "PURK"   ; Algo = "Purk"        ; WalletSymbol = "purk"    ; Port = 2244 }
    $Pools += [PSCustomObject]@{ Coin = "Quantum R L"     ; Symbol = "QRL"    ; Algo = "CnV7"        ; WalletSymbol = "qrl"     ; Port = 6010 }
    $Pools += [PSCustomObject]@{ Coin = "RYO"             ; Symbol = "RYO"    ; Algo = "CnGpu"       ; WalletSymbol = "ryo"     ; Port = 5555 }
    $Pools += [PSCustomObject]@{ Coin = "Saronite"        ; Symbol = "XRN"    ; Algo = "CnHaven"     ; WalletSymbol = "xrn"     ; Port = 5599 }
    $Pools += [PSCustomObject]@{ Coin = "Solace"          ; Symbol = "SOLACE" ; Algo = "CnHeavy"     ; WalletSymbol = "solace"  ; Port = 5588 }
    $Pools += [PSCustomObject]@{ Coin = "Swap"            ; Symbol = "XWP"    ; Algo = "CnFreeHaven" ; WalletSymbol = "xfh"     ; Port = 6080 }
    $Pools += [PSCustomObject]@{ Coin = "Wownero"         ; Symbol = "WOW"    ; Algo = "CnWow"       ; WalletSymbol = "wow"     ; Port = 6090 }

    $Pools | ForEach-Object {
        if ($Wallets.($_.Symbol)) {
            $ApiResponse = Invoke-APIRequest -Url ("https://" + $_.WalletSymbol + ".fairpool.xyz/api/poolStats")
            $Result += [PSCustomObject]@{
                Algorithm             = $_.Algo
                Info                  = $_.Coin
                Protocol              = "stratum+tcp"
                Host                  = "mine." + $_.WalletSymbol + ".fairpool.xyz"
                Port                  = $_.Port
                Price                 = [decimal]$ApiResponse.ProfitBtc
                User                  = $Wallets.($_.Symbol) + "+#WorkerName#"
                Pass                  = "x"
                Location              = "US"
                SSL                   = $false
                Symbol                = $_.Symbol
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolName              = $Name
                Workers               = $ApiResponse.Workers
                WalletMode            = $WalletMode
                WalletSymbol          = $_.WalletSymbol
                Fee                   = $ApiResponse.Fee
                RewardType            = $RewardType
            }
        }
    }
    Remove-Variable Pools
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
