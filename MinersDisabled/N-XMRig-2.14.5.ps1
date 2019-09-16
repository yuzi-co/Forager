
$M = @{
    Path       = "xmrig-nvidia-2.14.5/xmrig-nvidia.exe"
    Type       = "NVIDIA"
    Arguments  = @(
        "-o #Server#:#Port#"
        "-u #Login#"
        "-p #Password#"
        "--cuda-devices=#Devices#"
        "`$(if (`$Pool.PoolName -eq 'NiceHash'){'--nicehash'})"
        "`$(if (`$EnableSSL){'--tls'})"
        "--donate-level 1"
        "--api-port #APIPort#"
        "#AlgorithmParameters#"
        "#CustomParameters#"
    )
    API        = "XMRig"
    SSL        = $true
    Fee        = 0.01
    Algorithms = [PSCustomObject]@{
        CnAlloy  = "-a cn/xao"
        CnArto   = "-a cn/rto"
        CnDouble = "-a cn/double"
        CnFast   = "-a cn/msr"
        CnGpu    = "-a cn/gpu"
        CnHalf   = "-a cn/half"
        CnHaven  = "-a cn-heavy/xhv"
        CnHeavy  = "-a cn-heavy"
        CnLiteV7 = "-a cn-lite/1"
        CnR      = "-a cn/r"
        CnRwz    = "-a cn/rwz"
        CnSaber  = "-a cn-heavy/tube"
        # CnTurtle = "-a cn-pico/trtl"
        CnWow    = "-a cn/wow"
        CnXTL    = "-a cn/xtl"
        CnZls    = "-a cn/zls"
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.1") {
    $M.Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.5/xmrig-nvidia-2.14.5-cuda10_1-win64.zip"
    $M.SHA256 = "6EF35FF6F3A61D36F09EFC294B1310BE4697922265951B2D8BECA54EA2E7F795"
    $M.CUDA = 10.1
} elseif ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.5/xmrig-nvidia-2.14.5-cuda10-win64.zip"
    $M.SHA256 = "41C6E317A803F4692A26B8672C0A71059F1D36F1C16A92130E69DBF109333DAD"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.5/xmrig-nvidia-2.14.5-cuda9_2-win64.zip"
    $M.SHA256 = "86262DA53E0170CCDA9D4B65F22B731EC20076E45D015210984E62114AED9610"
    $M.CUDA = 9.2
} else {
    return
}

return [PSCustomObject]$M
