
$M = @{
    Path       = "z-enemy"
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
    $M.Uri = "https://github.com/yuzi-co/miners-linux/releases/download/2019.05/z-enemy-2.0-cuda100.tar.gz"
    $M.SHA256 = "0BEF26FF676F8B91243781FF85FC1A45BC1D82AFB9C1016B27787B4247937E92"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/yuzi-co/miners-linux/releases/download/2019.05/z-enemy-2.0-cuda92.tar.gz"
    $M.SHA256 = "098977ABCB1A3A40173945307C523777A57BA394C274E0BC8B8956DB752CB9A1"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/yuzi-co/miners-linux/releases/download/2019.05/z-enemy-2.0-cuda91.tar.gz"
    $M.SHA256 = "888A5A2AD4862E9467562421049F69ECB7A255B7DE64D9ABAC4E615BBBF512C6"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
