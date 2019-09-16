
$M = @{
    Path       = "CryptoDredge_0.21.0/CryptoDredge.exe"
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
        Argon2d256  = "-a chukwa-wrkz"
        Argon2d500  = "-a argon2d-dyn"
        Argon2d512  = "-a chukwa"
        Argon2d4096 = "-a argon2d4096"
        Argon2dNim  = "-a argon2d-nim"
        # BCD        = "-a bcd"
        # Bitcore    = "-a bitcore"
        CnConceal   = "-a cnconceal"
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
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.21.0/CryptoDredge_0.21.0_cuda_10.1_windows.zip"
    $M.SHA256 = "3C293F2BCD50EDCFD3D8ACA7F3F8BE981F577D4C7916B047BF5DF407558E7B4C"
    $M.CUDA = 10.1
} elseif ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.21.0/CryptoDredge_0.21.0_cuda_10.0_windows.zip"
    $M.SHA256 = "5955CC17B3D3D6B118093AFB4A7E0AB8002FB3769CC7B7698614B64C50BE3FEE"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"9.2") {
    $M.Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.21.0/CryptoDredge_0.21.0_cuda_9.2_windows.zip"
    $M.SHA256 = "0E0A2076208E7FCA004824B259E910952A27BB03AB6C8951933650EBE26C4009"
    $M.CUDA = 9.2
} else {
    return
}

return [PSCustomObject]$M
