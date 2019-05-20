
$M = @{
    Path       = "miniZ"
    Type       = "NVIDIA"
    Arguments  = @(
        "--server `$(if (`$EnableSSL){'ssl://'})#Server#"
        "--port #Port#"
        "--user #Login#"
        "--pass #Password#"
        "--gpu-line"
        "--extra"
        "--nocolor"
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
    $M.Uri = "https://github.com/yuzi-co/miners-linux/releases/download/2019.4/miniZ_v1.3n3_cuda10_linux-x64.tar.gz"
    $M.SHA256 = "1FB265597BB14DAE42397F47998DAE34562A4331E4563FA8B4867F907653856A"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"8.0") {
    $M.Uri = "https://github.com/yuzi-co/miners-linux/releases/download/2019.4/miniZ_v1.3n3_linux-x64.tar.gz"
    $M.SHA256 = "1DC3284F1335D58A2E5F19083E6A49663DC922BED8C28C23AF1A42FD3023DB99"
    $M.CUDA = 8.0
} else {
    return
}

return [PSCustomObject]$M
