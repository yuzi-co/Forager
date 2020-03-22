
$M = @{
    Path       = "CryptoDredge_0.16.0/CryptoDredge"
    Type       = "NVIDIA"
    Arguments  = @(
        "-o #Protocol#://#Server#:#Port#"
        "-u #Login#"
        "-p #Password#"
        "-d #Devices#"
        "--retries 4"
        "--retry-pause 10"
        "--timeout 60"
        "--no-watchdog"
        "--no-color"
        "-b 127.0.0.1:#APIPort#"
        "#AlgorithmParameters#"
        "#CustomParameters#"
    )
    API        = "Ccminer"
    SSL        = $true
    Fee        = 0.01
    Algorithms = [PSCustomObject]@{
        C11    = "-a c11"
        Dedal  = "-a dedal"
        Exosis = "-a exosis"
        Lbk3   = "-a lbk3"
        Phi    = "-a phi"
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.16.0/CryptoDredge_0.16.0_cuda_10.0_linux.tar.gz"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.16.0/CryptoDredge_0.16.0_cuda_9.2_linux.tar.gz"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.16.0/CryptoDredge_0.16.0_cuda_9.1_linux.tar.gz"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
