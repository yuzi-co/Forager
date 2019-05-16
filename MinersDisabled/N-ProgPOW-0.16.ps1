
$M = @{
    Uri        = "https://github.com/BitcoinInterestOfficial/BitcoinInterest/releases/download/2.1/progpowminer-cuda-windows-0.16_final.zip"
    SHA256     = "10DCBB1C62DCDA533CBFBA120E68CAE5628AC272267F4522609E3CED1C661AED"
    Type       = "NVIDIA"
    Arguments  = @(
        "-P stratum+tcp://#Login#:#Password#@#Server#:#Port#"
        "--cuda"
        "--cuda-devices #DevicesETHMode#"
        "--api-port -#APIPort#"
        "#AlgorithmParameters#"
        "#CustomParameters#"
    )
    API        = "Claymore"
    Algorithms = [PSCustomObject]@{
        ProgPOW = ""
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Path = "progpowminer-cuda-windows-0.16_final/Cuda 10/progpowminer-cuda.exe"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Path = "progpowminer-cuda-windows-0.16_final/Cuda 9.2/progpowminer-cuda.exe"
    $M.CUDA = 9.2
} else {
    return
}

return [PSCustomObject]$M
