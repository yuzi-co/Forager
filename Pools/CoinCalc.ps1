<#
THIS IS A ADVANCED POOL.

THIS IS A VIRTUAL POOL, STATISTICS ARE TAKEN FROM CoinCalculators.io AND RECALCULATED WITH YOUR BENCHMARKS HashRate,
YOU CAN SET DESTINATION POOL YOU WANT FOR EACH COIN, BUT REMEMBER YOU MUST HAVE AN ACOUNT IF DESTINATION POOL IS NOT ANONYMOUS
#>

param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

# . .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$WalletMode = "Mixed"
$RewardType = "PPS"
$Result = @()

if ($Querymode -eq "Info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Based on CoinCalculators statistics, you must have accounts and wallets for each coin"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $true
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}

if ($Querymode -eq "Core") {

    #Look for pools
    $ConfigOrder = $Config.("PoolOrder_" + $Name) -split ','
    $Pools = foreach ($PoolToSearch in $ConfigOrder) {
        $PoolsTmp = Get-Pools -Querymode "Core" -PoolsFilterList $PoolToSearch -location $Info.Location
        #Filter by minworkes variable (must be here for not selecting now a pool and after that discarded on core.ps1 filter)
        $PoolsTmp | Where-Object {
            $_.PoolWorkers -eq $null -or
            $_.PoolWorkers -ge $(if ($Config.("MinWorkers_" + $Name)) { $Config.("MinWorkers_" + $Name) } else { $Config.MinWorkers })
        }
    }

    $Url = "https://www.coincalculators.io/api/allcoins.aspx?hashrate=1000&difficultytime=0"
    # $Response = Get-Content .\WIP\CoinCalculators.json | ConvertFrom-Json
    $Response = Invoke-APIRequest -Url $Url -Age 10     ### Requests limited to 500 per day from a single IP
    if (-not $Response) {
        Write-Warning "$Name API NOT RESPONDING...ABORTING"
        Exit
    }
    foreach ($Coin in $Response) {
        $Coin.Name = Get-CoinUnifiedName $Coin.Name

        # Algo fixes
        switch ($Coin.Algorithm) {
            'WildKeccak' { $Coin.Algorithm += $Coin.Symbol }
            'Argon2d' { $Coin.Algorithm += $Coin.Symbol }
        }
        $Coin.Algorithm = Get-AlgoUnifiedName $Coin.Algorithm
    }

    #join pools and coins
    ForEach ($Pool in $Pools) {

        $Pool.Algorithm = Get-AlgoUnifiedName $Pool.Algorithm
        $Pool.Info = Get-CoinUnifiedName $Pool.Info

        if (($Result | Where-Object { $_.Info -eq $Pool.Info -and $_.Algorithm -eq $Pool.Algorithm }).count -eq 0) {
            #look that this coin is not included in result

            $Response | Where-Object { $_.Name -eq $Pool.Info -and $_.Algorithm -eq $Pool.Algorithm } | ForEach-Object {
                $Pool | Add-Member Price                 ([decimal]($_.rewardsInDay * $_.price_btc / $_.yourHashrate)) -Force
                $Pool | Add-Member Price24h              ([decimal]($_.rewardsInDay * $_.price_btc / $_.currentDifficulty * $_.difficulty24 / $_.yourHashrate)) -Force

                $Pool | Add-Member Symbol                $_.Symbol -Force
                $Pool | Add-Member PoolName              ("CC-" + $Pool.PoolName) -Force

                $Pool | Add-Member ActiveOnManualMode    $ActiveOnManualMode -Force
                $Pool | Add-Member ActiveOnAutomaticMode $ActiveOnAutomaticMode -Force

                $Result += $Pool
            }
        }
    } #end foreach pool
    Remove-Variable Pools
}

$Result
Remove-Variable Result
