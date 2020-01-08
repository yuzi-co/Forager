<#
THIS IS A ADVANCED POOL.

THIS IS A VIRTUAL POOL, STATISTICS ARE TAKEN FROM WHATTOMINE AND RECALCULATED WITH YOUR BENCHMARKS HashRate,
YOU CAN SET DESTINATION POOL YOU WANT FOR EACH COIN, BUT REMEMBER YOU MUST HAVE AN ACOUNT IF DESTINATION POOL IS NOT ANONYMOUS POOL
#>

param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

# . .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $false
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$WalletMode = "Mixed"
$RewardType = "PPS"
$Result = @()

if ($Querymode -eq "Info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Based on WhatToMine statistics, you must have accounts and wallets for each coin"
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
    $HPools = foreach ($PoolToSearch in $ConfigOrder) {
        $HPoolsTmp = Get-Pools -Querymode "Core" -PoolsFilterList $PoolToSearch -Location $Info.Location
        #Filter by minworkes variable (must be here for not selecting now a pool and after that discarded on core.ps1 filter)
        $HPoolsTmp | Where-Object {
            $_.PoolWorkers -eq $null -or
            $_.PoolWorkers -ge $(if ($Config.("MinWorkers_" + $PoolToSearch)) { $Config.("MinWorkers_" + $PoolToSearch) } else { $Config.MinWorkers })
        }
    }

    #Common Data from WTM

    #Add main page coins
    $WtmUrl = Get-WhatToMineURL

    $WTMResponse = Invoke-APIRequest -Url $WtmUrl -Retry 3 | Select-Object -ExpandProperty coins
    if (-not $WTMResponse) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }
    [array]$WTMCoins = $WTMResponse.PSObject.Properties.Name | ForEach-Object {
        #convert response to collection
        $res = $WTMResponse.($_)
        $res | Add-Member Name (Get-CoinUnifiedName $_)
        $res.Algorithm = Get-AlgoUnifiedName ($res.Algorithm)
        $res
    }
    Remove-Variable WTMResponse

    #Add secondary page coins
    $WTMResponse = Invoke-APIRequest -Url 'https://whattomine.com/calculators.json' -Retry 3 | Select-Object -ExpandProperty coins
    if ($WTMResponse) {
        $WTMSecondaryCoins = $WTMResponse.PSObject.Properties.Name | ForEach-Object {
            #convert response to collection
            $res = $WTMResponse.($_)
            if ($res.Status -eq "Active") {
                $res | Add-Member Name (Get-CoinUnifiedName $_)
                $res.Algorithm = Get-AlgoUnifiedName ($res.Algorithm)
                # Algo fixes
                switch ($res.Name) {
                    'Pascal' { $res.Algorithm = 'RandomHash2' }
                }
                $res
            }
        }
        Remove-Variable WTMResponse
    }

    #join pools and coins
    ForEach ($HPool in $HPools) {

        $HPool.Algorithm = Get-AlgoUnifiedName $HPool.Algorithm
        $HPool.Info = Get-CoinUnifiedName $HPool.Info

        #we must add units for each algo, this value must be filled if we want a coin to be selected
        $WTMFactor = Get-WhatToMineFactor -Algo $HPool.Algorithm

        if ($WTMFactor -and ($Result | Where-Object { $_.Info -eq $HPool.Info -and $_.Algorithm -eq $HPool.Algorithm }).count -eq 0) {
            # check if coin is not already included in result

            # check if coin in main page coins
            $WtmCoin = $WTMCoins | Where-Object {
                $_.Name -eq $HPool.Info -and
                $_.Algorithm -eq $HPool.Algorithm
            }

            if (-not $WtmCoin -and $WTMSecondaryCoins) {
                # check in secondary coins page
                $WtmSecCoin = $WTMSecondaryCoins | Where-Object {
                    $_.Name -eq $HPool.Info -and
                    $_.Algorithm -eq $HPool.Algorithm
                }
                if ($WtmSecCoin) {
                    $f = 10
                    $WtmCoin = Invoke-APIRequest -Url "https://whattomine.com/coins/$($WtmSecCoin.Id).json?hr=$f&p=0&fee=0.0&cost=0.0&hcost=0.0" -Retry 3
                    if ($WtmCoin) {
                        if (-not [decimal]$WtmCoin.btc_revenue) {
                            # if (-not $CMCResponse) {
                            #     'Calling CoinMarketCap API' | Write-Host
                            #     $CMCResponse = Invoke-APIRequest -Url "https://api.coinmarketcap.com/v1/ticker/?limit=0" -MaxAge 60 -Retry 1
                            # }
                            # $APIPrice = [decimal]($CMCResponse | Where-Object Symbol -eq $WtmCoin.tag | Select-Object -First 1 -ExpandProperty price_btc)

                            if (-not $CPResponse) {
                                'Calling CoinPaprika API' | Write-Host
                                $CPResponse = Invoke-APIRequest -Url "https://api.coinpaprika.com/v1/tickers?quotes=BTC" -MaxAge 60 -Retry 1
                            }
                            $APIPrice = [decimal]($CPResponse | Where-Object Symbol -eq $WtmCoin.tag | Select-Object -First 1 -ExpandProperty quotes).BTC.price
                            $WtmCoin.btc_revenue = $APIPrice * [decimal]$WtmCoin.estimated_rewards
                        }
                        $WtmCoin | Add-Member btc_revenue24 $WtmCoin.btc_revenue
                    }
                }
            }
            if ($WtmCoin) {
                $HPool | Add-Member Symbol                  $WtmCoin.Tag -Force
                $HPool | Add-Member PoolName                ("W-" + $HPool.PoolName) -Force

                $HPool | Add-Member Price                   ([decimal]$WtmCoin.btc_revenue / $WTMFactor) -Force
                $HPool | Add-Member Price24h                ([decimal]$WtmCoin.btc_revenue24 / $WTMFactor) -Force

                $HPool | Add-Member ActiveOnManualMode      $ActiveOnManualMode -Force
                $HPool | Add-Member ActiveOnAutomaticMode   $ActiveOnAutomaticMode -Force

                $Result += $HPool
            }
        }
    } #end foreach pool
    Remove-Variable HPools
    # Remove-Variable CMCResponse
    Remove-Variable CPResponse
}

$Result
Remove-Variable Result
