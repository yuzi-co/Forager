
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
    $M.Uri = "https://github.com/yuzi-co/miners-linux/releases/download/2019.03/z-enemy-1.28-cuda100.tar.gz"
    $M.SHA256 = "4E80D572D4D426B888DAEAEF4736601257E8257A01ED4F13C77439FD23AF156F"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/yuzi-co/miners-linux/releases/download/2019.03/z-enemy-1.28-cuda92.tar.gz"
    $M.SHA256 = "60249EF65F3097F4AD229EB931B74D9AA92D095EFCB575F7E98F523D80C9D70A"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/yuzi-co/miners-linux/releases/download/2019.03/z-enemy-1.28-cuda91.tar.gz"
    $M.SHA256 = "BC8EF9157D3753E98C7A6639161AC109A86C3F449EA8E2D652FFB5F54A010449"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
