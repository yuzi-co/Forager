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
        Disclaimer               = "Autoexchange to BTC, No registration required. Register and set BTC_NICE for lower fees"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $true
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}

if ($Querymode -eq "Speed") {
    $Info.user = $Info.user.split('.')[0]
    $Request = Invoke-APIRequest -Url $("https://api.nicehash.com/api?method=stats.provider.workers&addr=" + $Info.user) -Retry 1

    if ($Request.Result.Workers) {
        $Request.Result.Workers | ForEach-Object {
            $Multiplier = switch ($_[6]) {
                {@(16, 17, 18, 21, 23, 25, 28) -contains $PSItem} {1e9} #GH
                {@(5, 7, 8, 9, 10, 14, 20, 26, 29, 32) -contains $PSItem} {1e6} #MH
                {@(19, 22, 30, 31) -contains $PSItem} {1e3} #KH
                {@(24, 37) -contains $PSItem} {1}
                Default {1}
            }
            $Result += [PSCustomObject]@{
                PoolName   = $name
                WorkerName = $_[0]
                Rejected   = $_[4]
                HashRate   = [double]$_[1].a * $Multiplier
            }
        }
        Remove-Variable Request
    }
}

if ($Querymode -eq "Wallet") {
    $Info.user = ($Info.user -split '\.')[0]
    $Request = Invoke-APIRequest -Url $("https://api.nicehash.com/api?method=stats.provider&addr=" + $Info.user) -Retry 3 |
        Select-Object -ExpandProperty result | Select-Object -ExpandProperty stats

    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $name
            Currency = "BTC"
            Balance  = ($Request | Measure-Object -Sum -Property balance).Sum
        }
        Remove-Variable Request
    }
}

if ($Querymode -eq "Core") {

    if (-not $Wallets.BTC_NICE -and -not $Wallets.BTC) {
        Write-Warning "$Name BTC or BTC_NICE wallets not defined in config.ini"
        Exit
    }

    $Request = Invoke-APIRequest -Url "https://api.nicehash.com/api?method=simplemultialgo.info" -Retry 3 |
        Select-Object -expand result | Select-Object -expand simplemultialgo

    if (!$Request) {
        Write-Warning "$Name API NOT RESPONDING...ABORTING"
        Exit
    }

    $Locations = @{
        US   = 'usa'
        EU   = 'eu'
        Asia = 'hk'
    }

    $Request | Where-Object {$_.paying -gt 0} | ForEach-Object {

        $Algo = Get-AlgoUnifiedName ($_.name)

        $Divisor = 1000000000

        foreach ($location in $Locations.Keys) {

            $enableSSL = (@('CnV7', 'Equihash', 'Equihash150') -contains $Algo)

            $Result += [PSCustomObject]@{
                Algorithm             = $Algo
                Info                  = $Algo
                Price                 = [decimal]$_.paying / $Divisor
                Protocol              = "stratum+tcp"
                ProtocolSSL           = "ssl"
                Host                  = $_.name + "." + $Locations.$location + ".nicehash.com"
                HostSSL               = $_.name + "." + $Locations.$location + ".nicehash.com"
                Port                  = $_.port
                PortSSL               = $_.port + 30000
                User                  = $(if ($Wallets.BTC_NICE) {$Wallets.BTC_NICE} else {$Wallets.BTC}) + '.' + "#WorkerName#"
                Pass                  = "x"
                Location              = $Location
                SSL                   = $enableSSL
                Symbol                = Get-CoinSymbol -Coin $Algo
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolName              = $Name
                WalletMode            = $WalletMode
                WalletSymbol          = "BTC"
                Fee                   = $(if ($Wallets.BTC_NICE) {0.02} else {0.05})
                EthStMode             = 3
                RewardType            = $RewardType
            }
        }
    }
    Remove-Variable Request
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
