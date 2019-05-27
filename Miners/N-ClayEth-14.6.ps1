
$M = @{
    Uri        = "https://github.com/yuzi-co/miners/releases/download/2019.05/ClaymoreDual-14.6.7z"
    SHA256     = "BEEE669B66C98E7B327B1B6FB3E6D3759BE2A3261C1BE2448278586F77B9B544"
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
    Mem        = 2
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
