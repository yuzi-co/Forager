
$M = @{
    Path       = "xmrig-nvidia-2.14.4/xmrig-nvidia.exe"
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
    $M.Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.4/xmrig-nvidia-2.14.4-cuda10_1-win64.zip"
    $M.SHA256 = "5D1F7B6E45A18DB0C9445F38026C4AF228ECAFA5407D6E33801B995669FE0940"
    $M.CUDA = 10.1
} elseif ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.4/xmrig-nvidia-2.14.4-cuda10-win64.zip"
    $M.SHA256 = "EE26AAD006299D29E0517C035694C65AE5A8ADCAF65F4B730AECADA2B85DEE08"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.4/xmrig-nvidia-2.14.4-cuda9_2-win64.zip"
    $M.SHA256 = "19A13C269E0332C5BA528D81A0D7A770657093754C383338FD6E3CFF108C63DE"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.0") {
    $M.Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.14.4/xmrig-nvidia-2.14.4-cuda9_0-win64.zip"
    $M.SHA256 = "EAB50EC1EBBC21C93FFD0A6AA8503FA6A199B82DCEB1D96864767BB4CD843F3B"
    $M.CUDA = 9.0
} else {
    return
}

return [PSCustomObject]$M
