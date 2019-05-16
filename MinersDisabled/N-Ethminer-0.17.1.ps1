
$M = @{
    Path       = "bin/ethminer.exe"
    Type       = "NVIDIA"
    Arguments  = @(
        "-P stratum2+tcp://#Login#:#Password#@#Server#:#Port#"
        "--cuda"
        "--cuda-devices #DevicesETHMode#"
        "--api-port #APIPort#"
        "#AlgorithmParameters#"
        "#CustomParameters#"
    )
    API        = "Claymore"
    Mem        = 3
    Algorithms = [PSCustomObject]@{
        Ethash = ""
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/ethereum-mining/ethminer/releases/download/v0.17.1/ethminer-0.17.1-cuda10.0-windows-amd64.zip"
    $M.SHA256 = "3D94632F65E761A30F39CC0B67050CD224E0658B9F25A4B7CA350006775E553B"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.0") {
    $M.Uri = "https://github.com/ethereum-mining/ethminer/releases/download/v0.17.1/ethminer-0.17.1-cuda9.0-windows-amd64.zip"
    $M.SHA256 = "86414B48C7DEF79C36E1C4474BCD3B13F06CEB33AD084AC4D69199D320BCB581"
    $M.CUDA = 9.0
} else {
    return
}

return [PSCustomObject]$M
