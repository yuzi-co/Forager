Import-Module .\Include.psm1

Get-OpenCLDevices | Format-Table -Property @{Label = "Pid"; Expression = {$_.PlatformId}}, @{Label = "Dev"; Expression = {$_.DeviceIndex}}, Name, Vendor, Type, @{Label = "PlatformVersion"; Expression = {$_.Platform.Version}}, DriverVersion -Wrap
