
$M = @{
    Path       = "xmrig-nvidia-2.14.3/xmrig-nvidia.exe"
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

if ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.3/xmrig-nvidia-2.14.3-cuda10-win64.zip"
    $M.SHA256 = "787C6904351ED976D26F33ACAA4E4AD3CE1A49F5E5FC10FC4FA6DDD235F9E776"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.3/xmrig-nvidia-2.14.3-cuda9_2-win64.zip"
    $M.SHA256 = "554BF40A20F55268BF45F414BBB8655CE752753B253CE17A9AFCE39B9E3D3CB1"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.3/xmrig-nvidia-2.14.3-cuda9_1-win64.zip"
    $M.SHA256 = "6F5E431336FD5A11C0659973593C8443367DE42C3C6B48F5C56C28339C61D463"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
