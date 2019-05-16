
$M = @{
    Path       = "CryptoDredge_0.16.0/CryptoDredge.exe"
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
        "-b 127.0.0.1:#APIPort#"
        "#AlgorithmParameters#"
        "#CustomParameters#"
    )
    API        = "Ccminer"
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
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.16.0/CryptoDredge_0.16.0_cuda_10.0_windows.zip"
    $M.SHA256 = "2E0EC3A24EF90CC2FA82B3435972C2EB26011E23A674E727AAE62A5480167D85"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.16.0/CryptoDredge_0.16.0_cuda_9.2_windows.zip"
    $M.SHA256 = "4CC926B31C704BA74AFEE81375020214CE890F098A7289C47C4D3B158488B1A3"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.16.0/CryptoDredge_0.16.0_cuda_9.1_windows.zip"
    $M.SHA256 = "F97806CED35275147F87E659F5D2AC7318C05F3705BF187A7602490F3588D1CE"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
