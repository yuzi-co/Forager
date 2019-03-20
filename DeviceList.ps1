Import-Module .\Include.psm1

$global:Config = Get-Config
if ($Config.Afterburner -and $IsWindows) {
    . .\Includes\Afterburner.ps1
}
Out-DevicesInformation (Get-DevicesInformation (Get-MiningTypes -All))

$Groups = Get-MiningTypes -All | Where-Object GroupType -ne 'CPU' | Select-Object GroupName, GroupType, Devices, @{Name = 'PowerLimits'; Expression = {$_.PowerLimits -join ','}} | ConvertTo-Json -Compress

Write-Host "Suggested GpuGroups string:"
Write-Host "GpuGroups = $Groups" -ForegroundColor Yellow
