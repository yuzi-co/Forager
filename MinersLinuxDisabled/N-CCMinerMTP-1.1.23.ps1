$M = @{
    Uri        = "https://github.com/yuzi-co/miners-linux/releases/download/2019.07/CCMinerMTP-v1.1.23.tar.gz"
    SHA256     = "B13E4A8FD9B87A97A0F57541C411D691887929D8BBCC34B629C1647B6A564069"
    Type       = "NVIDIA"
    Arguments  = @(
        "-o #Protocol#://#Server#:#Port#"
        "-u #Login#"
        "-p #Password#"
        "-R 3"
        "-r 10"
        "-d #Devices#"
        "-b #APIPort#"
        "--no-donation"
        "#AlgorithmParameters#"
        "#CustomParameters#"
    )
    API        = "CCMiner"
    Algorithms = [PSCustomObject]@{
        MTP = @{
            Params = "-a mtp"
            NH     = false
            Mem    = 4.5
        }
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.1") {
    $M.Path = "ccminer-linux-cuda10.1"
    $M.CUDA = 10.1
} elseif ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Path = "ccminer-linux-cuda10.0"
    $M.CUDA = 10.0
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Path = "ccminer-linux-cuda9.2"
    $M.CUDA = 9.2
} else {
    return
}

return [PSCustomObject]$M
