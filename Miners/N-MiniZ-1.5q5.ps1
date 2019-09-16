
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
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2019.09/miniZ_v1.5q5_cuda10_win-x64.zip"
    $M.SHA256 = "3799110F216D77FEADE441C1FB87CA408E37D0152B6B0D97EDC1C388DB238F69"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"8.0") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2019.09/miniZ_v1.5q5_win-x64.zip"
    $M.SHA256 = "3ED99F829C5DF49CFBB59D359C754DC8A896A7A388A81E3F691F291DBC27FC5C"
    $M.CUDA = 8.0
} else {
    return
}

return [PSCustomObject]$M
