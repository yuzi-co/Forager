
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
        "--no-watchdog"
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
        Honeycomb  = "-a honeycomb"
        HSR        = "-a hsr"
        Jeonghash  = "-a jeonghash"
        MTP        = @{
            Params = "-a mtp"
            Mem    = 4.5
        }
        Padihash   = "-a padihash"
        Pawelhash  = "-a pawelhash"
        Polytimos  = "-a polytimos"
        Renesis    = "-a renesis"
        SHA256t    = "-a sha256t"
        SHA256q    = "-a sha256q"
        # Skunk     = "-a skunk"
        SonoA      = "-a sonoa"
        Tensority  = @{
            Params = "-a tensority"
            Fee    = 0.03
        }
        Timetravel = "-a timetravel"
        Tribus     = "-a tribus"
        X16r       = "-a x16r"
        X16rt      = "-a x16rt"
        X16rv2     = "-a x16rv2"
        X16s       = "-a x16s"
        X17        = "-a x17"
        X21s       = "-a x21s"
        X22i       = "-a x22i"
        x25x       = "-a x25x"
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.14.6/t-rex-0.14.6-win-cuda10.0.zip"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.14.6/t-rex-0.14.6-win-cuda9.2.zip"
    $M.CUDA = 9.2
} else {
    return
}

return [PSCustomObject]$M
