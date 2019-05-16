
$M = @{
    Path       = "TT-Miner.exe"
    Uri        = "https://tradeproject.de/download/Miner/TT-Miner-2.2.3.zip"
    SHA256     = "D63A75BBB1C0992742333165083739F7F270C4425B8CF9364A200861E26CD73E"
    Type       = "NVIDIA"
    Arguments  = @(
        "-o #Protocol#://#Server#:#Port#"
        "-u #Login#"
        "-p #Password#"
        "-worker #WorkerName#"
        "--nvidia"
        "-nui"
        "-d #Devices#"
        "-b 127.0.0.1:#APIPort#"
        "#CustomParameters#"
    )
    API        = "Claymore"
    Fee        = 0.01
    Algorithms = [PSCustomObject]@{
        Ethash   = @{
            Params = "-a ETHASH"
            Mem    = 3
        }
        # Lyra2v3  = "-a LYRA2V3"
        MTP      = @{
            Params = "-a MTP"
            Mem    = 4.5
        }
        ProgPOW  = "-a PROGPOW"
        ProgPOWZ = "-a PROGPOWZ"
        Ubqhash  = @{
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
