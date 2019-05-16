
$M = @{
    Uri        = "https://github.com/BitcoinInterestOfficial/BitcoinInterest/releases/download/2.1/progpow_linux_0.16_final.zip"
    SHA256     = "779447DA3802D6115588EBE1B065656CF9841D59CE9E0C14DB440F9D62EDF733"
    Type       = "NVIDIA"
    Arguments  = @(
        "-P stratum+tcp://#Login#:#Password#@#Server#:#Port#"
        "--cuda"
        "--cuda-devices #DevicesETHMode#"
        "--nocolor"
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
    $M.Path = "progpow_linux_0.16_final/progpowminer_cuda10"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Path = "progpow_linux_0.16_final/progpowminer_cuda9.2"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Path = "progpow_linux_0.16_final/progpowminer_cuda9.1"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
