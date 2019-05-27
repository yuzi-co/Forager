
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
        Aergo = "-a aeriumx"
        # BCD        = "-a bcd"
        # Bitcore    = "-a bitcore"
        # C11        = "-a c11"
        Hex   = "-a hex"
        # Polytimos  = "-a poly"
        # Renesis    = "-a renesis"
        # SonoA      = "-a sonoa"
        # TimeTravel = "-a timetravel"
        # Tribus     = "-a tribus"
        # Vitalium   = "-a vit"
        # X16r       = "-a x16r"
        # X16s       = "-a x16s"
        # X17        = "-a x17"
        Xevan = "-a xevan"
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2019.05/z-enemy.2-00-cuda10.0.zip"
    $M.SHA256 = "E334B5BC16A5247864F7AAB2BCBB27F941015C725F170611B55C26BCDE83375D"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2019.05/z-enemy.2-00-cuda9.2.zip"
    $M.SHA256 = "C61B59C6C6FBABD6621B87CF27628CBCE1436106EE2CA5900E41323F8134D8A6"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2019.05/z-enemy.2-00-cuda9.1.zip"
    $M.SHA256 = "51D4060B9A3EE80C4134348A46AE14434E45438FBDCEF75945537BD67BC0828C"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
