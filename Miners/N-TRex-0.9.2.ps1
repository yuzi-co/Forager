
$M = @{
    Path       = "t-rex.exe"
    Type       = "NVIDIA"
    Arguments  = @(
        "-o #Protocol#://#Server#:#Port#"
        "-u #Login#"
        "-p #Password#"
        "-d #Devices#"
        "-R 3"
        "-r 10"
        "-b 127.0.0.1:#APIPort#"
        "#AlgorithmParameters#"
        "#CustomParameters#"
    )
    API        = "Ccminer"
    Fee        = 0.01
    Algorithms = [PSCustomObject]@{
        Astralhash = "-a astralhash"
        Balloon    = "-a balloon"
        BCD        = "-a bcd"
        Bitcore    = "-a bitcore"
        C11        = "-a c11"
        Dedal      = "-a dedal"
        # Hmq1725   = "-a hmq1725"
        HSR        = "-a hsr"
        Jeonghash  = "-a jeonghash"
        Padihash   = "-a padihash"
        Pawelhash  = "-a pawelhash"
        Polytimos  = "-a polytimos"
        Renesis    = "-a renesis"
        SHA256t    = "-a sha256q"
        SHA256q    = "-a sha256q"
        # Skunk     = "-a skunk"
        SonoA      = "-a sonoa"
        Timetravel = "-a timetravel"
        Tribus     = "-a tribus"
        X16r       = "-a x16r"
        X16rt      = "-a x16rt"
        X16s       = "-a x16s"
        X17        = "-a x17"
        X21s       = "-a x21s"
        X22i       = "-a x22i"
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.9.2/t-rex-0.9.2-win-cuda10.0.zip"
    $M.SHA256 = "F9DB2A06D2F095DA53C3E3AE3D294ACBFB4D31A23A19E6300785DB1ED2BD208E"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.9.2/t-rex-0.9.2-win-cuda9.2.zip"
    $M.SHA256 = "9BF2A7497EA0B68658E5D9DA32D8504816CD57BDF4219BCC65222C9D451E2CFC"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.9.2/t-rex-0.9.2-win-cuda9.1.zip"
    $M.SHA256 = "138A5B55DC6A9D04E179F25A083F3AE4DA843B42869AC75B8E209706B9FA8088"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
