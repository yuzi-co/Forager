
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
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2018.12/z-enemy.1-28-cuda10.0.zip"
    $M.SHA256 = "72E5FB401C0FCF5F05D4595D85B87B8756E3A10B81B10466EAC90BC963760A76"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2018.12/z-enemy.1-28-cuda9.2.zip"
    $M.SHA256 = "A60EA1962B2581F9E938C5C2F0C3151E67CE79B98AEC2A95392C2750D4F34EDA"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/yuzi-co/miners/releases/download/2018.12/z-enemy.1-28-cuda9.1.zip"
    $M.SHA256 = "5EE56F9C8595314A21A0890E6F7927D45A3A90A2C8060D78ECFB495B11EB0A7F"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
