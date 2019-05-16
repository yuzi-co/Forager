
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
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.16.0/CryptoDredge_0.16.0_cuda_10.0_linux.tar.gz"
    $M.SHA256 = "C2056F6529F4A834C2F9A2758D69EE3BB5533BBDBAF70A362B43B03EB58A0036"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.16.0/CryptoDredge_0.16.0_cuda_9.2_linux.tar.gz"
    $M.SHA256 = "381A9DE55E0C403BE1AC3DD8DA654A6F51A2FB7166D56D4568ACF5D72BDF9B28"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.16.0/CryptoDredge_0.16.0_cuda_9.1_linux.tar.gz"
    $M.SHA256 = "71DA574D3A847242DFD355D5544F96FCF576C592EC1B6702D27E35E62EB58FDD"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
