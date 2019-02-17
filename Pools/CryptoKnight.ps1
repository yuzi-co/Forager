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
$Location = 'US'
$RewardType = 'PPLS'
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

if ($Querymode -eq "Core") {
    $Pools = @()

    $Pools += [PSCustomObject]@{ Coin = "Aeon"       ; Symbol = "AEON" ; Algo = "CnLiteV7" ; Port = 5542  ; WalletSymbol = "aeon"       }
    $Pools += [PSCustomObject]@{ Coin = "Alloy"      ; Symbol = "XAO"  ; Algo = "CnAlloy"  ; Port = 5562  ; WalletSymbol = "alloy"      }
    $Pools += [PSCustomObject]@{ Coin = "Arqma"      ; Symbol = "ARQ"  ; Algo = "CnLiteV7" ; Port = 3731  ; WalletSymbol = "arq"        }
    $Pools += [PSCustomObject]@{ Coin = "Arto"       ; Symbol = "RTO"  ; Algo = "CnArto"   ; Port = 51201 ; WalletSymbol = "arto"       }
    $Pools += [PSCustomObject]@{ Coin = "BBS"        ; Symbol = "BBS"  ; Algo = "CnLiteV7" ; Port = 19931 ; WalletSymbol = "bbs"        }
    $Pools += [PSCustomObject]@{ Coin = "BitcoiNote" ; Symbol = "BTCN" ; Algo = "CnLiteV7" ; Port = 9732  ; WalletSymbol = "btcn"       }
    $Pools += [PSCustomObject]@{ Coin = "Bittorium"  ; Symbol = "BTOR" ; Algo = "CnLiteV7" ; Port = 10401 ; WalletSymbol = "bittorium"  }
    $Pools += [PSCustomObject]@{ Coin = "BitTube"    ; Symbol = "TUBE" ; Algo = "CnSaber"  ; Port = 5631  ; WalletSymbol = "ipbc"       ; Server = "tube.ingest.cryptoknight.cc" }
    $Pools += [PSCustomObject]@{ Coin = "Caliber"    ; Symbol = "CAL"  ; Algo = "CnV8"     ; Port = 14101 ; WalletSymbol = "caliber"    }
    $Pools += [PSCustomObject]@{ Coin = "CitiCash"   ; Symbol = "CCH"  ; Algo = "CnHeavy"  ; Port = 13901 ; WalletSymbol = "citi"       }
    $Pools += [PSCustomObject]@{ Coin = "Elya"       ; Symbol = "ELYA" ; Algo = "CnV7"     ; Port = 50201 ; WalletSymbol = "elya"       }
    $Pools += [PSCustomObject]@{ Coin = "Graft"      ; Symbol = "GRF"  ; Algo = "CnV8"     ; Port = 9111  ; WalletSymbol = "graft"      }
    $Pools += [PSCustomObject]@{ Coin = "Haven"      ; Symbol = "XHV"  ; Algo = "CnHaven"  ; Port = 5831  ; WalletSymbol = "haven"      }
    $Pools += [PSCustomObject]@{ Coin = "IPBCrocks"  ; Symbol = "IPBC" ; Algo = "SnSaber"  ; Port = 5631  ; WalletSymbol = "ipbcrocks"  }
    $Pools += [PSCustomObject]@{ Coin = "Iridium"    ; Symbol = "IRD"  ; Algo = "CnLiteV7" ; Port = 50501 ; WalletSymbol = "iridium"    }
    $Pools += [PSCustomObject]@{ Coin = "Italo"      ; Symbol = "ITA"  ; Algo = "CnHaven"  ; Port = 50701 ; WalletSymbol = "italo"      }
    $Pools += [PSCustomObject]@{ Coin = "Lethean"    ; Symbol = "LTHN" ; Algo = "CnV8"     ; Port = 8881  ; WalletSymbol = "lethean"    }
    $Pools += [PSCustomObject]@{ Coin = "Loki"       ; Symbol = "LOKI" ; Algo = "CnHeavy"  ; Port = 7731  ; WalletSymbol = "loki"       }
    $Pools += [PSCustomObject]@{ Coin = "Masari"     ; Symbol = "MSR"  ; Algo = "CnHalf"   ; Port = 3333  ; WalletSymbol = "msr"        }
    $Pools += [PSCustomObject]@{ Coin = "Monero"     ; Symbol = "XMR"  ; Algo = "CnV8"     ; Port = 4441  ; WalletSymbol = "monero"     }
    $Pools += [PSCustomObject]@{ Coin = "MoneroV"    ; Symbol = "XMV"  ; Algo = "CnV7"     ; Port = 9221  ; WalletSymbol = "monerov"    }
    $Pools += [PSCustomObject]@{ Coin = "NioBio"     ; Symbol = "NBR"  ; Algo = "CnHeavy"  ; Port = 5801  ; WalletSymbol = "niobio"     }
    $Pools += [PSCustomObject]@{ Coin = "Ombre"      ; Symbol = "OMB"  ; Algo = "CnHeavy"  ; Port = 5571  ; WalletSymbol = "ombre"      }
    $Pools += [PSCustomObject]@{ Coin = "Solace"     ; Symbol = "SOL"  ; Algo = "CnHeavy"  ; Port = 5001  ; WalletSymbol = "solace"     }
    $Pools += [PSCustomObject]@{ Coin = "Ryo"        ; Symbol = "RYO"  ; Algo = "CnGpu"    ; Port = 52901 ; WalletSymbol = "ryo"        }
    $Pools += [PSCustomObject]@{ Coin = "Saronite"   ; Symbol = "XRN"  ; Algo = "CnHeavy"  ; Port = 11301 ; WalletSymbol = "saronite"   }
    $Pools += [PSCustomObject]@{ Coin = "Solace"     ; Symbol = "SOL"  ; Algo = "CnHeavy"  ; Port = 5001  ; WalletSymbol = "solace"     }
    $Pools += [PSCustomObject]@{ Coin = "Stellite"   ; Symbol = "XTL"  ; Algo = "CnHalf"   ; Port = 16221 ; WalletSymbol = "stellite"   }
    $Pools += [PSCustomObject]@{ Coin = "Swap"       ; Symbol = "XWP"  ; Algo = "CnSwap"   ; Port = 7731  ; WalletSymbol = "swap"       }
    $Pools += [PSCustomObject]@{ Coin = "Triton"     ; Symbol = "TRIT" ; Algo = "CnLiteV7" ; Port = 6631  ; WalletSymbol = "triton"     }
    $Pools += [PSCustomObject]@{ Coin = "WowNero"    ; Symbol = "WOW"  ; Algo = "CnWow"    ; Port = 50901 ; WalletSymbol = "wownero"    }

    $Pools | ForEach-Object {

        if ($Wallets.($_.Symbol)) {

            try {
                $Request = $null
                $Request = Invoke-APIRequest -Url ("https://cryptoknight.cc/rpc/" + $_.WalletSymbol + "/stats") -MaxAge 100
            } catch {}

            if ($Request -and $Request.charts) {
                $PriceUSD = [double] $Request.charts.priceUSD[-1][1]
                $Price = [double] $Request.charts.price[-1][1]
                $Profit = [double] $Request.charts.profit3[-1][1]
                $ProfitBTC = $Profit / $PriceUSD * $Price / 100000000
                # Write-Host "Profit $($_.coin): $Profit Price Sat: $Price Price USD: $PriceUSD ProfitBTC: $ProfitBTC"
            } else {
                $ProfitBTC = 0
            }

            $Result += [PSCustomObject]@{
                Algorithm                = $_.Algo
                Info                     = $_.Coin
                Protocol                 = "stratum+tcp"
                Host                     = $(if ($_.Server) {$_.Server} else {$_.WalletSymbol + ".ingest.cryptoknight.cc"})
                Port                     = $_.Port
                User                     = $Wallets.($_.Symbol)
                Pass                     = "#WorkerName#"
                Location                 = $Location
                SSL                      = $false
                Symbol                   = $_.Symbol
                ActiveOnManualMode       = $ActiveOnManualMode
                ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
                ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
                WalletMode               = $WalletMode
                WalletSymbol             = $_.WalletSymbol
                PoolName                 = $Name
                Fee                      = 0
                RewardType               = $RewardType

                PoolWorkers              = $Request.pool.miners
                PoolHashRate             = $Request.pool.hashRate
                Price                    = [decimal]($ProfitBTC / 1000)
                Price24h                 = [decimal]($ProfitBTC / 1000)
            }
        }
    }
    Remove-Variable Pools
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
