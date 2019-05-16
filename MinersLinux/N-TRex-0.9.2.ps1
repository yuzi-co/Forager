
$M = @{
    Path       = "t-rex"
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
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.9.2/t-rex-0.9.2-linux-cuda10.0.tar.gz"
    $M.SHA256 = "504FDEE49849DAD7B7AB590A88EFBDFA15ECD3083B1D3774332A74B6859C24AE"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.9.2/t-rex-0.9.2-linux-cuda9.2.tar.gz"
    $M.SHA256 = "4ACA03FE2D0871E6468263094E0DBCF8D24E39A347FB9EDFFB456BB694B50994"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.9.2/t-rex-0.9.2-linux-cuda9.1.tar.gz"
    $M.SHA256 = "24028738A3867C979A47E6236714B1D0307B483FE7B51CA6BF29614C6ADACA6C"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
