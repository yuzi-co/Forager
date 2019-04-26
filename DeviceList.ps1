Import-Module ./Include.psm1

$global:Config = Get-Config
if ($Config.Afterburner -and $IsWindows) {
    . "$PSScriptRoot/Includes/Afterburner.ps1"
}
Out-DevicesInformation (
    Get-DevicesInformation (
        Get-MiningTypes -All
    )
)

$Groups = ConvertTo-Json -Compress @(Get-MiningTypes -All | Where-Object GroupType -ne 'CPU' | Select-Object GroupName, GroupType, Devices, @{Name = 'PowerLimits'; Expression = { $_.PowerLimits -join ',' } })

Write-Host "Suggested GpuGroups string for Config.ini:"
Write-Host "GpuGroups = $Groups" -ForegroundColor Yellow
Write-Host "Remove integrated GPUs from Devices"
