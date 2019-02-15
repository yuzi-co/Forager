param(
    [Parameter(Mandatory = $false)]
    [String]$MiningMode = $null,
    [Parameter(Mandatory = $false)]
    [string]$PoolsName = $null,
    [Parameter(Mandatory = $false)]
    [string]$CoinsName = $null
)

. .\Include.ps1

#check parameters

if (($MiningMode -eq "MANUAL") -and ($PoolsName.count -gt 1)) {Write-Warning "ONLY ONE POOL CAN BE SELECTED ON MANUAL MODE"}

#--------------Load config.ini file

$Currency = Get-ConfigVariable "Currency"
$Location = Get-ConfigVariable "Location"
$FarmRigs = Get-ConfigVariable "FarmRigs"
$LocalCurrency = Get-ConfigVariable "LocalCurrency"
if (-not $LocalCurrency) {
    #for old config.ini compatibility
    $LocalCurrency = switch ($location) {
        'EU' {"EUR"}
        'US' {"USD"}
        'ASIA' {"USD"}
        'GB' {"GBP"}
        default {"USD"}
    }
}

#needed for anonymous pools load
$CoinsWallets = @{}
switch -regex -file config.ini {
    "^\s*WALLET_(\w+)\s*=\s*(.*)" {
        $name, $value = $matches[1..2]
        $CoinsWallets[$name] = $value.Trim()
    }
}
$UserName = Get-ConfigVariable "UserName"

$SelectedOption = ""

#-----------------Ask user for mode to mining AUTO/MANUAL to use, if a pool is indicated in parameters no prompt

Clear-Host
Print-HorizontalLine ""
Print-HorizontalLine "SELECT OPTION"
Print-HorizontalLine ""

$Modes = @()
$Modes += [PSCustomObject]@{"Option" = 0; "Mode" = 'Automatic'; "Explanation" = 'Automatically choose most profitable coin based on pools current statistics'}
$Modes += [PSCustomObject]@{"Option" = 1; "Mode" = 'Automatic24h'; "Explanation" = 'Automatically choose most profitable coin based on pools 24 hour statistics'}
$Modes += [PSCustomObject]@{"Option" = 2; "Mode" = 'Manual'; "Explanation" = 'Manual coin selection'}

if ($FarmRigs) {
    $Modes += [PSCustomObject]@{"Option" = 3; "Mode" = 'Farm Monitoring'; "Explanation" = 'I want to see my rigs state'}
}
$Modes | Format-Table Option, Mode, Explanation

If ($MiningMode -eq "") {
    $SelectedOption = Read-Host -Prompt 'SELECT ONE OPTION:'
    $MiningMode = $Modes[$SelectedOption].Mode
    Write-Host "SELECTED OPTION: $MiningMode"
} else { Write-Host "SELECTED BY PARAMETER OPTION: $MiningMode" }

if ($MiningMode -ne "FARM MONITORING") {
    #-----------------Ask user for pool/s to use, if a pool is indicated in parameters no prompt

    $Pools = Get-Pools -Querymode "Info" | Where-Object ("ActiveOn" + $MiningMode + "Mode") -eq $true | Sort-Object name

    $Pools | Add-Member Option "0"
    $counter = 0
    $Pools | ForEach-Object {
        $_.Option = $counter
        $counter++}

    #Clear-Host
    Print-HorizontalLine ""
    Print-HorizontalLine "SELECT POOL/S TO MINE"
    Print-HorizontalLine ""

    $Pools | Format-Table Option, name, rewardtype, disclaimer

    If (-not $PoolsName) {
        if ($MiningMode -eq "Manual") {
            $SelectedOption = Read-Host -Prompt 'SELECT ONE OPTION:'
            while ($SelectedOption -like '*,*') {
                $SelectedOption = Read-Host -Prompt 'SELECT ONLY ONE OPTION:'
            }
        } else {
            $SelectedOption = Read-Host -Prompt 'SELECT OPTION/S (separated by comma). 999 for all pools:'
        }

        if ($SelectedOption -eq "999") {
            $PoolsName = $Pools.name -join ',' -replace "\s+"
        } else {
            $PoolsName = ($SelectedOption -split ',' | ForEach-Object {$Pools[$_].name}) -join ',' -replace "\s+"
        }

        Write-Host "SELECTED OPTION: $PoolsName"
    } else {
        Write-Host "SELECTED BY PARAMETER: $PoolsName"
    }

    #-----------------Ask user for coins----------------------------------------------------

    if ($MiningMode -eq "manual") {

        If (-not $CoinsName) {

            #Load coins from pools
            $CoinsPool = Get-Pools -Querymode "Menu" -PoolsFilterList $PoolsName -location $Location | Select-Object Info, Symbol, Algorithm, Workers, PoolHashRate, Blocks_24h, Price -unique | Sort-Object info

            $CoinsPool | Add-Member Option "0"
            $CoinsPool | Add-Member YourHashRate ([Double]0.0)
            $CoinsPool | Add-Member BTCPrice ([Double]0.0)
            $CoinsPool | Add-Member Reward ([Double]0.0)
            $CoinsPool | Add-Member BtcProfit ([Double]0.0)
            $CoinsPool | Add-Member LocalProfit ([Double]0.0)
            $CoinsPool | Add-Member LocalPrice ([Double]0.0)

            'Calling Coindesk API' | Write-Host
            $CDKResponse = try { Invoke-RestMethod -Uri "https://api.coindesk.com/v1/bpi/currentprice/$LocalCurrency.json" -UseBasicParsing -TimeoutSec 5 | Select-Object -ExpandProperty BPI } catch { $null; Write-Host "Not responding" }

            if (($CoinsPool | Where-Object Price -gt 0).count -gt 0) {
                $Counter = 0
                foreach ($Coin in $CoinsPool) {
                    $Coin.Option = $Counter
                    $counter++
                    $Coin.YourHashRate = (Get-BestHashRateAlgo $Coin.Algorithm).HashRate
                    $Coin.BtcProfit = $Coin.price * $Coin.YourHashRate
                    $Coin.LocalProfit = $CDKResponse.$LocalCurrency.rate_float * [double]$Coin.BtcProfit
                }
            } else {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                'Calling CoinMarketCap API' | Write-Host
                $CMCResponse = try { Invoke-RestMethod -Uri "https://api.coinmarketcap.com/v1/ticker/?limit=0" -UseBasicParsing -TimeoutSec 10 } catch { $null; Write-Host "Not responding" }
                'Calling Bittrex API' | Write-Host
                $BTXResponse = try { Invoke-RestMethod -Uri "https://bittrex.com/api/v1.1/public/getmarketsummaries" -UseBasicParsing -TimeoutSec 10 | Select-Object -ExpandProperty 'result' } catch { $null; Write-Host "Not responding" }
                # 'Calling Cryptopia API' | Write-Host
                # $CRYResponse = try { Invoke-RestMethod -Uri "https://www.cryptopia.co.nz/api/GetMarkets/BTC" -UseBasicParsing -TimeoutSec 10 | Select-Object -ExpandProperty 'data' } catch { $null; Write-Host "Not responding" }

                #Add main page coins
                $WtmUrl = 'https://whattomine.com/coins.json?' +
                @(
                    'bcd=true&factor[bcd_hr]=10&factor[bcd_p]=0' #BCD
                    'bk14=true&factor[bk14_hr]=10&factor[bk14_p]=0' #Decred
                    'cn=true&factor[cn_hr]=10&factor[cn_p]=0' #CryptoNight
                    'cn7=true&factor[cn7_hr]=10&factor[cn7_p]=0' #CryptoNightV7
                    'cn8=true&factor[cn8_hr]=10&factor[cn8_p]=0' #CryptoNightV8
                    'cnf=true&factor[cnf_hr]=10&factor[cnf_p]=0' #CryptoNightFast
                    'cnh=true&factor[cnh_hr]=10&factor[cnh_p]=0' #CryptoNightHeavy
                    'cnhn=true&factor[cnhn_hr]=10&factor[cnhn_p]=0' #CryptoNightHaven
                    'cns=true&factor[cns_hr]=10&factor[cns_p]=0' #CryptoNightSaber
                    'cr29=true&factor[cr29_hr]=10&factor[cr29_p]=0' #Cuckaroo29
                    'eq=true&factor[eq_hr]=10&factor[eq_p]=0' #Equihash
                    'eqa=true&factor[eqa_hr]=10&factor[eqa_p]=0' #AION (Equihash210)
                    'eth=true&factor[eth_hr]=10&factor[eth_p]=0' #Ethash
                    'grof=true&factor[gro_hr]=10&factor[gro_p]=0' #Groestl
                    'hx=true&factor[hx_hr]=10&factor[hx_p]=0' #Hex
                    'l2z=true&factor[l2z_hr]=10&factor[l2z_p]=0' #Lyra2z
                    'lbry=true&factor[lbry_hr]=10&factor[lbry_p]=0' #Lbry
                    'lre=true&factor[lrev2_hr]=10&factor[lrev2_p]=0' #Lyra2v2
                    'lrev3=true&factor[lrev3_hr]=10&factor[lrev3_p]=0' #Lyra2v3
                    'mtp=true&factor[mtp_hr]=10&factor[mtp_p]=0' #MTP
                    'n5=true&factor[n5_hr]=10&factor[n5_p]=0' #Nist5
                    'ns=true&factor[ns_hr]=10&factor[ns_p]=0' #NeoScrypt
                    'pas=true&factor[pas_hr]=10&factor[pas_p]=0' #Pascal
                    'phi=true&factor[phi_hr]=10&factor[phi_p]=0' #PHI
                    'phi2=true&factor[phi2_hr]=10&factor[phi2_p]=0' #PHI2
                    'ppw=true&factor[ppw_hr]=10&factor[ppw_p]=0' #ProgPOW
                    'skh=true&factor[skh_hr]=10&factor[skh_p]=0' #Skunk
                    'tt10=true&factor[tt10_hr]=10&factor[tt10_p]=0' #TimeTravel10
                    'x11gf=true&factor[x11g_hr]=10&factor[x11g_p]=0' #X11gost
                    'x16r=true&factor[x16r_hr]=10&factor[x16r_p]=0' #X16r
                    'x22i=true&factor[x22i_hr]=10&factor[x22i_p]=0' #X22i
                    'xn=true&factor[xn_hr]=10&factor[xn_p]=0' #Xevan
                    'zh=true&factor[zh_hr]=10&factor[zh_p]=0' #ZHash (Equihash144)
                ) -join '&'

                'Calling WhatToMine API' | Write-Host
                $WTMResponse = try { Invoke-RestMethod -Uri $WtmUrl -UseBasicParsing -TimeoutSec 10 | Select-Object -ExpandProperty coins } catch { $null; Write-Host "Not responding" }
            }

            $Counter = 0
            foreach ($Coin in $CoinsPool) {
                $Coin.Option = $Counter
                $counter++
                $Coin.YourHashRate = (Get-BestHashRateAlgo $Coin.Algorithm).HashRate

                if ($ManualMiningApiUse -eq $true -and ![string]::IsNullOrEmpty($Coin.Symbol)) {

                    $PriceCMC = [decimal]($CMCResponse | Where-Object Symbol -eq $Coin.Symbol | ForEach-Object {if ($(Get-CoinUnifiedName $_.Id) -eq $Coin.Info) {$_.price_btc} })
                    $PriceBTX = [decimal]($BTXResponse | Where-Object MarketName -eq ('BTC-' + $Coin.Symbol) | Select-Object -ExpandProperty Last)
                    # $PriceCRY = [decimal]($CRYResponse | Where-Object Label -eq ($Coin.Symbol + '/BTC') | Select-Object -ExpandProperty LastPrice)

                    if ($PriceCMC -gt 0) {
                        $Coin.BTCPrice = $PriceCMC
                    } elseif ($PriceBTX -gt 0) {
                        $Coin.BTCPrice = $PriceBTX
                        # } elseif ($PriceCRY -gt 0) {
                        #     $Coin.BTCPrice = $PriceCRY
                    }

                    Remove-Variable PriceCMC
                    Remove-Variable PriceBTX
                    # Remove-Variable PriceCRY

                    #Data from WTM
                    if ($WTMResponse -ne $null) {
                        $WtmCoin = $WTMResponse.PSObject.Properties.Value | Where-Object tag -eq $Coin.Symbol | ForEach-Object {if ($(Get-AlgoUnifiedName $_.algorithm) -eq $Coin.Algorithm) {$_}}
                        if ($WtmCoin -ne $null) {

                            $WTMFactor = switch ($Coin.Algorithm) {
                                "Allium" { 1e6 }
                                "BCD" { 1e6 }
                                "Bitcore" { 1e6 }
                                "Blake2s" { 1e6 }
                                "CnFast" { 1 }
                                "CnHaven" { 1 }
                                "CnHeavy" { 1 }
                                "CnLiteV7" { 1 }
                                "CnSaber" { 1 }
                                "CnV7" { 1 }
                                "CnV8" { 1 }
                                "Cuckaroo29" { 1 }
                                "Cuckaroo31" { 1 }
                                "Energi" { 1e6 }
                                "Equihash144" { 1 }
                                "Equihash192" { 1 }
                                "Equihash210" { 1 }
                                "Equihash96" { 1e3 }
                                "Ethash" { 1e6 }
                                "Hex" { 1e6 }
                                "Keccak" { 1e6 }
                                "KeccakC" { 1e6 }
                                "LBK3" { 1e3 }
                                "Lyra2v2" {1e3}
                                "Lyra2v3" {1e6}
                                "Lyra2z" { 1e6 }
                                "M7M" { 1e3 }
                                "MTP" { 1e3 }
                                "NeoScrypt" { 1e3 }
                                "Phi" { 1e6 }
                                "Phi2" { 1e6 }
                                "ProgPOW" { 1e6 }
                                "RandomHash" { 1e3 }
                                "Skunk" { 1e6 }
                                "SonoA" { 1e3 }
                                "Tensority" { 1 }
                                "Ubqhash" { 1e6 }
                                "X16r" { 1e6 }
                                "X16rt" { 1e6 }
                                "X16s" { 1e6 }
                                "X17" { 1e3 }
                                "X22i" { 1e6 }
                                "Yescrypt" { 1 }
                                default { $null }
                            }

                            if ($WTMFactor) {
                                $Coin.Reward = [double]([double]$WtmCoin.estimated_rewards * ([double]$Coin.YourHashRate / [double]$WTMFactor))
                                $Coin.BtcProfit = [double]([double]$WtmCoin.Btc_revenue * ([double]$Coin.YourHashRate / [double]$WTMFactor))
                            }
                        }
                    }
                    $Coin.LocalProfit = $CDKResponse.$LocalCurrency.rate_float * $Coin.BtcProfit
                    $Coin.LocalPrice = $CDKResponse.$LocalCurrency.rate_float * $Coin.BtcPrice
                }
            }

            # Clear-Host
            Print-HorizontalLine ""
            Print-HorizontalLine "SELECT COIN TO MINE"
            Print-HorizontalLine ""
            $CoinsPool | Format-Table -Wrap (
                @{Label = "Opt."; Expression = {$_.Option}; Align = 'right'} ,
                @{Label = "Name"; Expression = {$_.Info}; Align = 'left'} ,
                @{Label = "Symbol"; Expression = {$_.symbol}; Align = 'left'},
                @{Label = "Algorithm"; Expression = {$_.algorithm}; Align = 'left'},
                @{Label = "HashRate"; Expression = {(ConvertTo-Hash ($_.YourHashRate)) + "/s"}; Align = 'right'},
                @{Label = "BTCPrice"; Expression = {if ($_.BTCPrice -gt 0) {[math]::Round($_.BTCPrice, 6).ToString("n6")}}; Align = 'right'},
                @{Label = $LocalCurrency + "Price"; Expression = { [math]::Round($_.LocalPrice, 2)}; Align = 'right'},
                @{Label = "Reward"; Expression = {if ($_.Reward -gt 0 ) {[math]::Round($_.Reward, 3)}}; Align = 'right'},
                @{Label = "mBTCProfit"; Expression = {if ($_.BtcProfit -gt 0 ) {($_.BtcProfit * 1000).ToString("n5")}}; Align = 'right'},
                @{Label = $LocalCurrency + "Profit"; Expression = {if ($_.LocalProfit -gt 0 ) {[math]::Round($_.LocalProfit, 2)}}; Align = 'right'}
            )

            $SelectedOption = Read-Host -Prompt 'SELECT ONE OPTION:'
            while ($SelectedOption -like '*,*') {
                $SelectedOption = Read-Host -Prompt 'SELECT ONLY ONE OPTION:'
            }
            $CoinsName = $CoinsPool[$SelectedOption].Info -replace '_', ',' #for dual mining
            $AlgosName = $CoinsPool[$SelectedOption].Algorithm -replace '_', ',' #for dual mining

            Write-Host SELECTED OPTION:: $CoinsName - $AlgosName
        } else {
            Write-Host SELECTED BY PARAMETER :: $CoinsName
        }
    }

    #-----------------Launch Command
    $Params = @{
        MiningMode = $MiningMode
        PoolsName  = $PoolsName -split ','
    }
    if ($MiningMode -eq 'Manual') {
        $Params.Algorithm = $AlgosName
        if ($CoinsName) {$Params.CoinsName = $CoinsName}
    }
    $Params | Format-List
    Pause
    & .\Core.ps1 @Params

} else {
    #FARM MONITORING
    & .\Includes\FarmMonitor.ps1
}
