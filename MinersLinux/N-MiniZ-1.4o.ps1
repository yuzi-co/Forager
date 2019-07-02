
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
    $M.Uri = "https://github.com/yuzi-co/miners-linux/releases/download/2019.07/miniZ_v1.4o_cuda10_linux-x64.tar.gz"
    $M.SHA256 = "C3B3467FDA52EEC056FD85A1A7598F1F95BE3BB9FE1850141E977353CA1598BB"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"8.0") {
    $M.Uri = "https://github.com/yuzi-co/miners-linux/releases/download/2019.07/miniZ_v1.4o_linux-x64.tar.gz"
    $M.SHA256 = "07A7855795E3615D9D7D6F79237751C4F1DFB405C8924F885956EE5BFBCC2CCC"
    $M.CUDA = 8.0
} else {
    return
}

return [PSCustomObject]$M
