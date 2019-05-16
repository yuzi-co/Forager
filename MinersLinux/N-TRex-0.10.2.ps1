
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
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.10.2/t-rex-0.10.2-linux-cuda10.0.tar.gz"
    $M.SHA256 = "D6574843AFCDC061BBA36DF95433E0C48BD45DD61090F168F4BC7DF58FF85511"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.10.2/t-rex-0.10.2-win-cuda9.2.zip"
    $M.SHA256 = "C40B8B5396C110A826FA127D6A77330416AD9E0A127F99740C36EC49CB8F7732"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.10.2/t-rex-0.10.2-linux-cuda9.1.tar.gz"
    $M.SHA256 = "1455B1E26865D08658769981DC3F75434DB6EB9DA6BBF4782D8093500BB9BEFA"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
