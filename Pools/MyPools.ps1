param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$WalletMode = "None"
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

if ($Querymode -eq "Core") {
    $Pools = @(
        [PSCustomObject]@{ Coin = "Dallar"     ; Symbol = "DAL"  ; Algo = "Throestl"   ; Server = "pool.dallar.org"              ; Port = 3032 ; Fee = 0.01 ; User = $Wallets.DAL                    }
        [PSCustomObject]@{ Coin = "Pascalcoin" ; Symbol = "PASC" ; Algo = "RandomHash" ; Server = "mine.pool.pascalpool.org"     ; Port = 3333 ; Fee = 0.01 ; User = $Wallets.PASC                   }
        [PSCustomObject]@{ Coin = "Grin"       ; Symbol = "GRIN" ; Algo = "Cuckaroo29" ; Server = "eu-west-stratum.grinmint.com" ; Port = 3416 ; Fee = 0.01 ; User = '$($Config.Email)/#WorkerName#' }
    )

    $Result = $Pools | ForEach-Object {
        [PSCustomObject]@{
            Algorithm             = $_.Algo
            Info                  = $_.Coin
            Protocol              = "stratum+tcp"
            Host                  = $_.Server
            Port                  = $_.Port
            User                  = $_.User
            Pass                  = if ([string]::IsNullOrEmpty($_.Pass)) {"x"} else {$_.Pass}
            Location              = "EU"
            SSL                   = $false
            Symbol                = $_.symbol
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolName              = $Name
            WalletMode            = $WalletMode
            Fee                   = $_.Fee
            RewardType            = $RewardType
        }
    }
    Remove-Variable Pools
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable result
