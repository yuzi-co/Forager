param(
    [Parameter(Mandatory = $true)]$WorkerName,
    [Parameter(Mandatory = $true)]$ActiveMiners,
    [Parameter(Mandatory = $true)]$MinerStatusKey,
    [Parameter(Mandatory = $true)]$MinerStatusURL
)

$Miners = $ActiveMiners.SubMiners | Where-Object Status -eq 'Running' | Sort-Object { $ActiveMiners[$_.IdF].DeviceGroup.GroupType -eq 'CPU' }
[decimal]$Profit = $Miners | ForEach-Object { [decimal]$_.RevenueLive + [decimal]$_.RevenueLiveDual } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$MinerReport = ConvertTo-Json -Compress @(
    $Miners | ForEach-Object {

        $M = $ActiveMiners[$_.IdF]

        [PSCustomObject]@{
            Name           = $M.Name
            Path           = @($M.Pool.Symbol, $M.PoolDual.Symbol) -ne $null
            Type           = $M.DeviceGroup.GroupName
            Active         = $(if ($_.Stats.Activetime -le 3600) { "{0:N1} mins" -f ($_.Stats.ActiveTime / 60) } else { "{0:N1} hours" -f ($_.Stats.ActiveTime / 3600) })
            Algorithm      = @($M.Algorithm, $M.AlgorithmDual) -ne $null
            Pool           = @($M.Pool.PoolName, $M.PoolDual.PoolName) -ne $null
            CurrentSpeed   = @($_.SpeedLive, $_.SpeedLiveDual) -gt 0
            EstimatedSpeed = @($_.HashRate, $_.HashRateDual) -gt 0
            PID            = $M.Process.Id
            'BTC/day'      = $([decimal]$_.RevenueLive + [decimal]$_.RevenueLiveDual)
        }
    }
)

$Params = @{
    Uri             = $MinerStatusURL
    Method          = 'Post'
    Body            = @{address = $MinerStatusKey; workername = $WorkerName; miners = $MinerReport; profit = $Profit }
    UseBasicParsing = $true
    TimeoutSec      = 10
}

$ErrorActionPreference = 'SilentlyContinue'
Invoke-RestMethod @Params | Out-Null
