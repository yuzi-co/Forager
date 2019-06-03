
$M = @{
    Path       = "CryptoDredge_0.20.1/CryptoDredge.exe"
    Type       = "NVIDIA"
    Arguments  = @(
        "-o #Protocol#://#Server#:#Port#"
        "-u #Login#"
        "-p #Password#"
        "-d #Devices#"
        "--retries 4"
        "--retry-pause 10"
        "--timeout 60"
        "--no-watchdog"
        "-b 127.0.0.1:#APIPort#"
        "#AlgorithmParameters#"
        "#CustomParameters#"
    )
    API        = "Ccminer"
    Fee        = 0.01
    Algorithms = [PSCustomObject]@{
        Allium      = "-a allium"
        Argon2d250  = "-a argon2d250"
        Argon2d500  = "-a argon2d-dyn"
        Argon2d4096 = "-a argon2d4096"
        Argon2dNim  = "-a argon2d-nim"
        # BCD        = "-a bcd"
        # Bitcore    = "-a bitcore"
        CnGpu       = "-a cngpu"
        CnHalf      = "-a cnfast2"
        CnHaven     = "-a cnhaven"
        CnHeavy     = "-a cnheavy"
        CnLiteV7    = "-a aeon"
        CnSaber     = "-a cnsaber"
        CnTurtle    = "-a cnturtle"
        # Cuckoo29   = @{
        #     Params = "-a aeternity"
        #     Mem    = 5.3
        # }
        # Cuckaroo29 = @{
        #     Params = "-a cuckaroo29"
        #     NoCpu  = true
        #     Mem    = 5.3
        # }
        Hmq1725     = "-a hmq1725"
        # Lyra2v3    = "-a lyra2rev3"
        Lyra2vc0ban = "-a lyra2vc0banhash"
        # Lyra2z     = "-a lyra2z"
        Lyra2zz     = "-a lyra2zz"
        MTP         = @{
            Params = "-a mtp"
            Mem    = 4.5
            Fee    = 0.02
        }
        NeoScrypt   = "-a neoscrypt"
        Phi2        = "-a phi2"
        Pipe        = "-a pipe"
        Skunk       = "-a skunk"
        Tribus      = "-a tribus"
        # X16r       = "-a x16r"
        # X16rt      = "-a x16rt"
        # X16s       = "-a x16s"
        # X17        = "-a x17"
        X21s        = "-a x21s"
        # X22i       = "-a x22i"
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.1") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.20.1/CryptoDredge_0.20.1_cuda_10.1_windows.zip"
    $M.SHA256 = "6462A650D9C539A142382DD14AEDA4479B775979A4F0035DCDB3EEB4DAB55A7B"
    $M.CUDA = 10.1
} elseif ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.20.1/CryptoDredge_0.20.1_cuda_10.0_windows.zip"
    $M.SHA256 = "6D098294FEE1FDFBE3341F41C0C75677F3CD003518A7E37AC35307CC5ABAD061"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.20.1/CryptoDredge_0.20.1_cuda_9.2_windows.zip"
    $M.SHA256 = "FEE4BA1B4EA8D64BF455BE4D1E8D48D861E5DA7E4E9829EAC092044FC67971AA"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.20.1/CryptoDredge_0.20.1_cuda_9.1_windows.zip"
    $M.SHA256 = "D7A4A1341147EB8C070B5711A7F32B9E438725FC4432CCD6273F95445C81A74C"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
