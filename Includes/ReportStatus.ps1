param(
    [Parameter(Mandatory = $true)]$WorkerName,
    [Parameter(Mandatory = $true)]$ActiveMiners,
    [Parameter(Mandatory = $true)]$MinerStatusKey,
    [Parameter(Mandatory = $true)]$MinerStatusURL
)

function ConvertTo-Hash {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Hash
    )

    $Return = switch ([math]::truncate([math]::log($Hash, 1e3))) {
        1 {"{0:g4} kh" -f ($Hash / 1e3)}
        2 {"{0:g4} mh" -f ($Hash / 1e6)}
        3 {"{0:g4} gh" -f ($Hash / 1e9)}
        4 {"{0:g4} th" -f ($Hash / 1e12)}
        5 {"{0:g4} ph" -f ($Hash / 1e15)}
        default {"{0:g4} h" -f ($Hash)}
    }
    $Return
}

$Miners = $ActiveMiners.SubMiners | Where-Object Status -eq 'Running' | Sort-Object {$ActiveMiners[$_.IdF].DeviceGroup.GroupType -eq 'CPU'}
$Profit = $Miners | ForEach-Object {[decimal]$_.RevenueLive + [decimal]$_.RevenueLiveDual} | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$MinerReport = $Miners | ForEach-Object {

    $M = $ActiveMiners[$_.IdF]

    [PSCustomObject]@{
        Name           = $M.Name
        # Path           = Resolve-Path -Relative $_.Path ## Not the most useful info
        Path           = @($M.Pool.Symbol, $M.PoolDual.Symbol) -ne $null -join "_"
        Type           = $M.DeviceGroup.GroupName
        Active         = $(if ($_.Stats.Activetime -le 3600) {"{0:N1} mins" -f ($_.Stats.ActiveTime / 60)} else {"{0:N1} hours" -f ($_.Stats.ActiveTime / 3600)})
        Algorithm      = @((@($M.Algorithm, $M.AlgorithmDual) -ne $null -join "_"), $M.AlgoLabel) -ne $null -join "|" + $M.BestBySwitch
        Pool           = @(($M.Pool.PoolName + '-' + $M.Pool.Location), ($M.PoolDual.PoolName + '-' + $M.PoolDual.Location)) -ne "-" -join "/"
        CurrentSpeed   = (@($_.SpeedLive, $_.SpeedLiveDual) -gt 0 | ForEach-Object {ConvertTo-Hash $_}) -join "/" -replace ",", "."
        EstimatedSpeed = (@($_.HashRate, $_.HashRateDual) -gt 0 | ForEach-Object {ConvertTo-Hash $_}) -join "/" -replace ",", "."
        PID            = $M.Process.Id
        StatusMiner    = $(if ($_.NeedBenchmark) {"Benchmarking($([string](($ActiveMiners | Where-Object {$_.DeviceGroup.GroupName -eq $M.DeviceGroup.GroupName}).count)))"} else {$_.Status})
        'BTC/day'      = [decimal]$_.RevenueLive + [decimal]$_.RevenueLiveDual
    }
} | ConvertTo-Json -Compress
$Params = @{
    Uri             = $MinerStatusURL
    Method          = 'Post'
    Body            = @{address = $MinerStatusKey; workername = $WorkerName; miners = $MinerReport; profit = $Profit}
    UseBasicParsing = $true
    TimeoutSec      = 10
}
$ErrorActionPreference = SilentlyContinue
Invoke-RestMethod @Params | Out-Null
