
$M = @{
    Path       = "CryptoDredge_0.23.0/CryptoDredge"
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
        "--no-color"
        "-b 127.0.0.1:#APIPort#"
        "#AlgorithmParameters#"
        "#CustomParameters#"
    )
    API        = "Ccminer"
    SSL        = $true
    Fee        = 0.01
    Algorithms = [PSCustomObject]@{
        Allium      = "-a allium"
        Argon2d250  = "-a argon2d250"
        Argon2d500  = "-a argon2d-dyn"
        Argon2d4096 = "-a argon2d4096"
        Argon2dNim  = "-a argon2d-nim"
        # BCD        = "-a bcd"
        # Bitcore    = "-a bitcore"
        Chukwa      = "-a chukwa"
        ChukwaWrkz  = "-a chukwa-wrkz"
        CnConceal   = "-a cnconceal"
        CnGpu       = "-a cngpu"
        CnHalf      = "-a cnfast2"
        CnHaven     = "-a cnhaven"
        CnHeavy     = "-a cnheavy"
        CnSaber     = "-a cnsaber"
        CnTurtle    = "-a cnturtle"
        CnUplexa    = "-a cnupx2"
        CnZls       = "-a cnzls"
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
        MTPtcr      = @{
            Params = "-a mtp-tcr"
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
        X16rv2      = "-a x16rv2"
        # X16s       = "-a x16s"
        # X17        = "-a x17"
        X21s        = "-a x21s"
        # X22i       = "-a x22i"
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.1") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.23.0/CryptoDredge_0.23.0_cuda_10.1_linux.tar.gz"
    $M.CUDA = 10.1
} elseif ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.23.0/CryptoDredge_0.23.0_cuda_10.0_linux.tar.gz"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.23.0/CryptoDredge_0.23.0_cuda_9.2_linux.tar.gz"
    $M.CUDA = 9.2
} elseif ($SystemInfo.CudaVersion -ge [version]"9.1") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.23.0/CryptoDredge_0.23.0_cuda_9.1_linux.tar.gz"
    $M.CUDA = 9.1
} else {
    return
}

return [PSCustomObject]$M
