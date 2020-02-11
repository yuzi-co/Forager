
$M = @{
    Path       = "z-enemy.exe"
    Type       = "NVIDIA"
    Arguments  = @(
        "-o #Protocol#://#Server#:#Port#"
        "-u #Login#"
        "-p #Password#"
        "-R 3"
        "-r 10"
        "-d #Devices#"
        "-b #APIPort#"
        "#AlgorithmParameters#"
        "#CustomParameters#"
    )
    API        = "Ccminer"
    Fee        = 0.01
    Algorithms = [PSCustomObject]@{
        Aergo      = "-a aeriumx"
        # BCD        = "-a bcd"
        # Bitcore    = "-a bitcore"
        # C11        = "-a c11"
        Hex        = "-a hex"
        # Polytimos  = "-a poly"
        # Phi2       = "-a phi2"
        Renesis    = "-a renesis"
        # Skunk      = "-a skunk"
        # SonoA      = "-a sonoa"
        TimeTravel = "-a timetravel"
        # Tribus     = "-a tribus"
        Vitalium   = "-a vit"
        # X16r       = "-a x16r"
        # X16rv2     = "-a x16rv2"
        # X16s       = "-a x16s"
        # X17        = "-a x17"
        Xevan      = "-a xevan"
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.1") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2020.01/z-enemy-2.4-win-cuda10.1.zip"
    $M.CUDA = 10.1
} elseif ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2020.01/z-enemy-2.4-win-cuda10.0.zip"
    $M.CUDA = 10.0
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2020.01/z-enemy-2.4-win-cuda9.2.zip"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2020.01/z-enemy-2.4-win-cuda9.1.zip"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
