
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
        Timetravel = "-a timetravel"
        Tribus     = "-a tribus"
        X16r       = "-a x16r"
        X16rt      = "-a x16rt"
        X16s       = "-a x16s"
        X17        = "-a x17"
        X21s       = "-a x21s"
        X22i       = "-a x22i"
        x25x       = "-a x25x"
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.12.0/t-rex-0.12.0-win-cuda10.0.zip"
    $M.SHA256 = "DCD4D044BED972EF5B0B322B1A07ABD84E57DED78BF56A7FDC3D41E1D0B3BE6A"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.12.0/t-rex-0.12.0-win-cuda9.2.zip"
    $M.SHA256 = "EDB907278F8EB66C133B59F2E84F001CE75EF4D66FEB89545B3A8BCE987FA2E3"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.12.0/t-rex-0.12.0-win-cuda9.1.zip"
    $M.SHA256 = "FCF73F6721EBA4A29ACF694C688F81EFF7E0F1B0F1AB76F5F83B34475E1239D5"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
