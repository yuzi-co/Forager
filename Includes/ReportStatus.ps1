param(
    [Parameter(Mandatory = $true)][String]$Key,
    [Parameter(Mandatory = $true)][String]$WorkerName,
    [Parameter(Mandatory = $true)]$ActiveMiners,
    [Parameter(Mandatory = $true)]$MinerStatusURL
)

$Miners = $ActiveMiners.SubMiners | Where-Object Status -eq 'Running' | Sort-Object {$ActiveMiners[$_.IdF].DeviceGroup.GroupType -eq 'CPU'}
$Profit = $Miners | % {[decimal]$_.RevenueLive + [decimal]$_.RevenueLiveDual} | Measure-Object -Sum | Select-Object -ExpandProperty Sum
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
        CurrentSpeed   = (@($_.SpeedLive, $_.SpeedLiveDual) -gt 0 | % {ConvertTo-Hash $_}) -join "/" -replace ",", "."
        EstimatedSpeed = (@($_.HashRate, $_.HashRateDual) -gt 0 | % {ConvertTo-Hash $_}) -join "/" -replace ",", "."
        PID            = $M.Process.Id
        StatusMiner    = $(if ($_.NeedBenchmark) {"Benchmarking($([string](($ActiveMiners | Where-Object {$_.DeviceGroup.GroupName -eq $M.DeviceGroup.GroupName}).count)))"} else {$_.Status})
        'BTC/day'      = [decimal]$_.RevenueLive + [decimal]$_.RevenueLiveDual
    }
} | ConvertTo-Json -Compress
try {
    Invoke-RestMethod -Uri $MinerStatusURL -Method Post -Body @{address = $Key; workername = $WorkerName; miners = $MinerReport; profit = $Profit} | Out-Null
} catch {}
