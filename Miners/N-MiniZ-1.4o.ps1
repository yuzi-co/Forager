
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
        Equihash125 = @{
            Params = "--par=125,4"
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
        # Equihash210 = @{
        #     Params = "--par=210,9"
        # }
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2019.07/miniZ_v1.4o_cuda10_win-x64.zip"
    $M.SHA256 = "23E219735AE2F0C03E40A79D56ED12B41B900B88A436B75FB262916170F787E6"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"8.0") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2019.07/miniZ_v1.4o_win-x64.zip"
    $M.SHA256 = "038C2373DFF900EC34849F8ADE4D558FA68B94DB02383DFF75CBD085138CE067"
    $M.CUDA = 8.0
} else {
    return
}

return [PSCustomObject]$M
