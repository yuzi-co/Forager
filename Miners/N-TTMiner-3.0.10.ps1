
$M = @{
    Path       = "TT-Miner.exe"
    Uri        = "https://tradeproject.de/download/Miner/TT-Miner-3.0.10.zip"
    Type       = "NVIDIA"
    Arguments  = @(
        "-o #Protocol#://#Server#:#Port#"
        "-u #Login#"
        "-p #Password#"
        "-worker #WorkerName#"
        "--nvidia"
        "-nui"
        "-luck"
        "-d #Devices#"
        "-b 0.0.0.0:#APIPort#"
        "#CustomParameters#"
    )
    API        = "Claymore"
    Fee        = 0.01
    Algorithms = [PSCustomObject]@{
        Ethash      = @{
            Params = "-a ETHASH"
            Mem    = 3
        }
        # Honeycomb   = "-a HONEYCOMB"
        # Lyra2v3  = "-a LYRA2V3"
        MTP         = @{
            Params = "-a MTP"
            Mem    = 4.5
        }
        ProgPOW     = "-a PROGPOW"
        ProgPOWZ    = "-a PROGPOWZ"
        ProgPOW092  = "-a PROGPOW092"
        ProgPOWHora = "-a PROGPOW092 -coin hora"
        ProgPOWSero = "-a PROGPOW092 -coin sero"
        Tethash     = "-a TETHASHV1"
        Ubqhash     = @{
            Params = "-a UBQHASH"
            Mem    = 3
        }
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.1") {
    $M.Arguments += "#AlgorithmParameters#-101"
    $M.CUDA = 10.1
} elseif ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Arguments += "#AlgorithmParameters#-100"
    $M.CUDA = 10.0
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Arguments += "#AlgorithmParameters#-92"
    $M.CUDA = 9.2
} else {
    return
}

return [PSCustomObject]$M
