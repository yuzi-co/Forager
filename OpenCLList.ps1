Import-Module .\Include.psm1
Set-OsFlags

Get-OpenCLDevices | Format-Table -Property @{Label = "Pid"; Expression = { $_.PlatformId } },
@{Label = "Dev"; Expression = { $_.DeviceIndex } },
Name,
@{Label = "MemGB"; Expression = { [math]::round(($_.GlobalMemSize / 1GB), 2) } },
@{Label = "CU"; Expression = { $_.MaxComputeUnits } },
Vendor,
Type,
@{Label = "PlatformVer"; Expression = { $_.Platform.Version } },
@{Label = "DriverVer"; Expression = { $_.DriverVersion } } -Wrap
