param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$WalletMode = "ApiKey"
$RewardType = "PPLS"
$Result = @()

if ($Querymode -eq "Info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Registration required, set UserName in config"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}

if ($Querymode -eq "ApiKey") {

    $Request = Invoke-APIRequest -Url "https://$($Info.Symbol).miningpoolhub.com/index.php?page=api&action=getdashboarddata&api_key=$($Info.ApiKey)&id=&$(Get-Date -Format "yyyy-MM-dd_HH-mm")" -Retry 3

    if ($Request.getdashboarddata.data) {
        $Data = $Request.getdashboarddata.data
        $Result = [PSCustomObject]@{
            Pool     = $name
            Currency = $Info.Symbol
            Balance  = $Data.balance.confirmed +
            $Data.balance.unconfirmed +
            $Data.balance_for_auto_exchange.confirmed +
            $Data.balance_for_auto_exchange.unconfirmed +
            $Data.balance_on_exchange
        }
        Remove-Variable Request
        Remove-Variable Data
    }
}

if ($Querymode -eq "Speed") {

    $Request = Invoke-APIRequest -Url "https://$($Info.Symbol).miningpoolhub.com/index.php?page=api&action=getuserworkers&api_key=$($Info.ApiKey)&$(Get-Date -Format "yyyy-MM-dd_HH-mm")" -Retry 1

    if ($Request.getuserworkers.data) {
        $Data = $Request.getuserworkers.data
        $Result = $Data | ForEach-Object {
            if ($_.HashRate -gt 0) {
                [PSCustomObject]@{
                    PoolName   = $name
                    Diff       = $_.difficulty
                    WorkerName = $_.UserName.split('.')[1]
                    HashRate   = $_.HashRate
                }
            }
        }
        Remove-Variable Request
        Remove-Variable Data
    }
}

if ($Querymode -eq "Core") {

    if (-not $Config.UserName -and -not $Config.("UserName_" + $Name)) {
        Write-Warning "$Name UserName not defined"
        Exit
    }

    $MiningPoolHub_Request = Invoke-APIRequest -Url "https://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics&$(Get-Date -Format "yyyy-MM-dd_HH-mm")" -Retry 3

    if (-not $MiningPoolHub_Request) {
        Write-Warning "$Name API NOT RESPONDING...ABORTING"
        Exit
    }

    $Locations = "EU", "US", "Asia"

    $MiningPoolHub_Request.return | Where-Object time_since_last_block -gt 0 | ForEach-Object {

        $MiningPoolHub_Algorithm = Get-AlgoUnifiedName $_.algo
        $MiningPoolHub_Coin = Get-CoinUnifiedName $_.coin_name

        $MiningPoolHub_OriginalCoin = $_.coin_name

        $MiningPoolHub_Hosts = $_.host_list -split ";"
        $MiningPoolHub_Port = $_.port

        $MiningPoolHub_Price = [double]($_.profit / 1e9)

        foreach ($Location in $Locations) {

            $Server = $MiningPoolHub_Hosts | Sort-Object {$_ -like "$Location*"} -Descending | Select-Object -First 1

            $Result += [PSCustomObject]@{
                Algorithm             = $MiningPoolHub_Algorithm
                Info                  = $MiningPoolHub_Coin
                Price                 = [decimal]$MiningPoolHub_Price
                Protocol              = "stratum+tcp"
                Host                  = $Server
                Port                  = $MiningPoolHub_Port
                User                  = $(if ($Config.("UserName_" + $Name)) {$Config.("UserName_" + $Name)} else {$Config.UserName}) + ".#WorkerName#"
                Pass                  = "x"
                Location              = $Location
                Symbol                = Get-CoinSymbol -Coin $MiningPoolHub_Coin
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                WalletMode            = $WalletMode
                WalletSymbol          = $MiningPoolHub_OriginalCoin
                PoolName              = $Name
                Fee                   = 0.009 + 0.002 # Pool fee + AutoExchange fee
                EthStMode             = 2
                RewardType            = $RewardType
            }
        }
    }
    Remove-Variable MiningPoolHub_Request
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
