param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$ActiveOnAutomatic24hMode = $false
$WalletMode = "None"
$RewardType = "PPS"
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

if ($Querymode -eq "Core") {

    if (-not $Config.UserName -and -not $Config.("UserName_" + $Name)) {
        Write-Warning "$Name UserName not defined"
        Exit
    }

    $Pools = @()

    $Pools += [PSCustomObject]@{ Coin = "Cerberus"    ; Algo = "NeoScrypt" ; Symbol = "CBS"  ; Port = 3426 }
    $Pools += [PSCustomObject]@{ Coin = "Crowdcoin"   ; Algo = "NeoScrypt" ; Symbol = "CRC"  ; Port = 3315 }
    $Pools += [PSCustomObject]@{ Coin = "Desire"      ; Algo = "NeoScrypt" ; Symbol = "DSR"  ; Port = 3635 }
    $Pools += [PSCustomObject]@{ Coin = "Feathercoin" ; Algo = "NeoScrypt" ; Symbol = "FTC"  ; Port = 3347 }
    $Pools += [PSCustomObject]@{ Coin = "Gobyte"      ; Algo = "NeoScrypt" ; Symbol = "GBX"  ; Port = 3606 }
    $Pools += [PSCustomObject]@{ Coin = "Guncoin"     ; Algo = "NeoScrypt" ; Symbol = "GUN"  ; Port = 3615 }
    $Pools += [PSCustomObject]@{ Coin = "Innova"      ; Algo = "NeoScrypt" ; Symbol = "INN"  ; Port = 3389 }
    $Pools += [PSCustomObject]@{ Coin = "Nyxcoin"     ; Algo = "NeoScrypt" ; Symbol = "NYX"  ; Port = 3419 }
    $Pools += [PSCustomObject]@{ Coin = "Onexcash"    ; Algo = "NeoScrypt" ; Symbol = "ONEX" ; Port = 3655 }
    $Pools += [PSCustomObject]@{ Coin = "Orbitcoin"   ; Algo = "NeoScrypt" ; Symbol = "ORB"  ; Port = 3614 }
    $Pools += [PSCustomObject]@{ Coin = "Qbic"        ; Algo = "NeoScrypt" ; Symbol = "QBIC" ; Port = 3416 }
    $Pools += [PSCustomObject]@{ Coin = "Sparks"      ; Algo = "NeoScrypt" ; Symbol = "SPK"  ; Port = 3408 }
    $Pools += [PSCustomObject]@{ Coin = "Trezarcoin"  ; Algo = "NeoScrypt" ; Symbol = "TZC"  ; Port = 3616 }
    $Pools += [PSCustomObject]@{ Coin = "Ufocoin"     ; Algo = "NeoScrypt" ; Symbol = "UFO"  ; Port = 3351 }
    $Pools += [PSCustomObject]@{ Coin = "Vivo"        ; Algo = "NeoScrypt" ; Symbol = "VIVO" ; Port = 3610 }
    $Pools += [PSCustomObject]@{ Coin = "Monacoin"    ; Algo = "Lyra2rev2" ; Symbol = "MONA" ; Port = 3420 }
    $Pools += [PSCustomObject]@{ Coin = "Rupee"       ; Algo = "Lyra2rev2" ; Symbol = "RUP"  ; Port = 3427 }
    $Pools += [PSCustomObject]@{ Coin = "Shield"      ; Algo = "Lyra2rev2" ; Symbol = "XSH"  ; Port = 3432 }
    $Pools += [PSCustomObject]@{ Coin = "Straks"      ; Algo = "Lyra2rev2" ; Symbol = "STAK" ; Port = 3433 }
    $Pools += [PSCustomObject]@{ Coin = "Verge"       ; Algo = "Lyra2rev2" ; Symbol = "XVG"  ; Port = 3431 }
    $Pools += [PSCustomObject]@{ Coin = "Vertcoin"    ; Algo = "Lyra2rev2" ; Symbol = "VTC"  ; Port = 3429 }

    $Pools | ForEach-Object {

        $Result += [PSCustomObject]@{
            Algorithm             = Get-AlgoUnifiedName $_.Algo
            Info                  = $_.Coin
            Protocol              = "stratum+tcp"
            Host                  = $_.Algo + ".mining-dutch.nl"
            Port                  = $_.Port
            User                  = $(if ($Config.("UserName_" + $Name)) {$Config.("UserName_" + $Name)} else {$Config.UserName}) + ".#WorkerName#"
            Pass                  = "x"
            Location              = "EU"
            SSL                   = $false
            Symbol                = $_.Symbol
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolName              = $Name
            WalletMode            = $WalletMode
            WalletSymbol          = $_.Symbol
            Fee                   = 0.02
            EthStMode             = 3
            RewardType            = $RewardType
        }
    }
    Remove-Variable Pools
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
