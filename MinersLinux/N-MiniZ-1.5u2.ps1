
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
        "--nonvml"
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
        Beam        = @{
            Params = "--par=beam"
            Mem    = 3
        }
        BeamV2      = @{
            Params = "--par=beam2"
            Mem    = 3
        }
        Equihash96  = @{
            Params = "--par=96,5 --pers auto"
            Mem    = 1.75
        }
        Equihash125 = @{
            Params = "--par=125,4"
            Mem    = 2
        }
        Equihash144 = @{
            Params = "--par=144,5 --pers auto"
            Mem    = 2
        }
        Equihash150 = @{
            Params = "--par=150,5"
            Mem    = 3
        }
        Equihash192 = @{
            Params = "--par=192,7 --pers auto"
            Mem    = 2.75
        }
        Equihash210 = @{
            Params = "--par=210,9 --pers auto"
            Mem    = 2
        }
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/yuzi-co/miners-linux/releases/download/2020.06/miniZ_v1.5u2_cuda10_linux-x64.7z"
    $M.CUDA = 10
} else {
    return
}

return [PSCustomObject]$M
