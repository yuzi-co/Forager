
$M = @{
    Path       = "miniZ.exe"
    Type       = "NVIDIA"
    Arguments  = @(
        "--server `$(if (`$EnableSSL){'ssl://'})#Server#"
        "--port #Port#"
        "--user #Login#"
        "--pass #Password#"
        "--gpu-line"
        "--extra"
        "--cuda-devices #DevicesETHMode#"
        "--telemetry 0.0.0.0:#APIPort#"
        "#AlgorithmParameters#"
        "#CustomParameters#"
    )
    API        = "MiniZ"
    SSL        = $true
    Fee        = 0.02
    Algorithms = [PSCustomObject]@{
        Equihash96  = @{
            Params = "--par=96,5 --pers auto"
            Mem    = 1.75
        }
        Equihash144 = @{
            Params = "--par=144,5 --pers auto"
            Mem    = 1.75
        }
        Equihash150 = @{
            Params = "--par=150,5"
            Mem    = 2.9
        }
        Equihash192 = @{
            Params = "--par=192,7 --pers auto"
            Mem    = 2.75
        }
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2019.04/miniZ_v1.3n3_cuda10_win-x64.zip"
    $M.SHA256 = "0F03D00EA72C5A2FD7364AE97EEFC8519F7F4935C3830F2B602F0D670B5B64E5"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"8.0") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2019.04/miniZ_v1.3n3_win-x64.zip"
    $M.SHA256 = "95F95162A9BC31AF4C8D26FD080629E8423B047D30C0D751C728068D900F3386"
    $M.CUDA = 8.0
} else {
    return
}

return [PSCustomObject]$M
