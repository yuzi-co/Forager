
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
    $M.Uri = "https://github.com/ethereum-mining/ethminer/releases/download/v0.18.0/ethminer-0.18.0-cuda10.0-windows-amd64.zip"
    $M.SHA256 = "9331AE5AED54EBBAE83AB42B3DEB7C01D3B2A9C397E33EADE268C3901BCAD00B"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/ethereum-mining/ethminer/releases/download/v0.18.0/ethminer-0.18.0-cuda9.1-windows-amd64.zip"
    $M.SHA256 = "01AEC9FA9EC80872F46D2D65FEE36464908D2103D21215F341E2A2B7DC6F69EB"
    $M.CUDA = 9.1
} else {
    $M.Uri = "https://github.com/ethereum-mining/ethminer/releases/download/v0.18.0/ethminer-0.18.0-cuda8.0-windows-amd64.zip"
    $M.SHA256 = "9D366C747D4FA02678A9D04384D35463444AC6827A528C96DC85DC36FB5E2CBE"
    $M.CUDA = 8.0
} else {
    return
}

return [PSCustomObject]$M
