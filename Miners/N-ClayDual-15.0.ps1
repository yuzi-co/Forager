
$M = @{
    Uri        = "https://github.com/yuzi-co/miners/releases/download/2019.09/ClaymoreDual-v15.0.7z"
    SHA256     = "FB10695BA0F19E99382B5DCF7EC01B99C6B55512F49A6FBD5746A38CBC120864"
    Type       = "NVIDIA"
    Arguments  = @(
        "-epool #Protocol#://#Server#:#Port#"
        "-ewal #Login#"
        "-epsw #Password#"
        "-dpool #ProtocolDual#://#ServerDual#:#PortDual#"
        "-dwal #LoginDual#"
        "-dpsw #PasswordDual#"
        "-esm #EthStMode#"
        "-wd 1"
        "-r -1"
        "-logfile #GroupName#_log.txt"
        "-logsmaxsize 10"
        "-platform 2"
        "-di #DevicesClayMode#"
        "-allpools 1"
        "-mport -#APIPort#"
        "#AlgorithmParameters#"
        "#CustomParameters#"
    )
    API        = "Claymore"
    SSL        = $true
    Fee        = "`$(if (`$DeviceGroup.MemoryGB -gt 3){0.01}else{0})"
    Mem        = 3
    Algorithms = [PSCustomObject]@{
        Ethash         = "-mode 1"
        Ethash_Blake2s = "-dcoin blake2s -mode 0"
        Ethash_Keccak  = "-dcoin Keccak -mode 0"
    }
}

if ($SystemInfo.CudaVersion -ge [version]"10.0") {
    $M.Path = "EthDcrMiner64_cuda10.exe"
    $M.CUDA = 10
} elseif ($SystemInfo.CudaVersion -ge [version]"8.0") {
    $M.Path = "EthDcrMiner64.exe"
    $M.CUDA = 8.0
} else {
    return
}

return [PSCustomObject]$M
