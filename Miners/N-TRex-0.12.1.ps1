
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
        # Dedal      = "-a dedal"
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
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.12.1/t-rex-0.12.1-win-cuda10.0.zip"
    $M.SHA256 = "FA07B8A2EEEAE0DE46C13495DBD6A5FBC694BB9918C97407CDA3644065A02803"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.12.1/t-rex-0.12.1-win-cuda9.2.zip"
    $M.SHA256 = "54A0ED8B3C6ACFACF700361CD22F3DC637DE2D245AB3AAB8F62E71229EE35B52"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/trexminer/T-Rex/releases/download/0.12.1/t-rex-0.12.1-win-cuda9.1.zip"
    $M.SHA256 = "7E3DF0B104CA17BEBC7EA2619AD3AF15E4D79699728D6DF68090BBF3CAE81E4D"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
