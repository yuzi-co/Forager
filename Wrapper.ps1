param(
    [Parameter(Mandatory = $true)]
    [Int]$ControllerProcessID,
    [Parameter(Mandatory = $true)]
    [String]$Id,
    [Parameter(Mandatory = $true)]
    [String]$FilePath,
    [Parameter(Mandatory = $false)]
    [String]$ArgumentList = "",
    [Parameter(Mandatory = $false)]
    [String]$WorkingDirectory = ""
)

# Force Culture to en-US
$culture = [System.Globalization.CultureInfo]::CreateSpecificCulture("en-US")
$culture.NumberFormat.NumberDecimalSeparator = "."
$culture.NumberFormat.NumberGroupSeparator = ","
[System.Threading.Thread]::CurrentThread.CurrentCulture = $culture

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

0 | Set-Content ".\Wrapper_$Id.json"

$PowerShell = [PowerShell]::Create()
if ($WorkingDirectory) {
    $PowerShell.AddScript("Set-Location '$WorkingDirectory'") | Out-Null
}
$Command = ". '$FilePath'"
if ($ArgumentList) {
    $Command += " $ArgumentList"
}
$PowerShell.AddScript("$Command 2>&1 | Write-Verbose -Verbose") | Out-Null
$Result = $PowerShell.BeginInvoke()

Write-Host "Wrapper Started" -BackgroundColor Yellow -ForegroundColor Black
$CardsArray = @(0) * 20

do {
    $PowerShell.Streams.Verbose.ReadAll() | ForEach-Object {
        Write-Host $_

        [decimal]$HashRate = 0

        if (
            #[2019-05-27 21:33:34] Accepted 1/1 (100%), 30.41 MH, 10.48 MH/s
            $_ -match "Accepted (\d+)/(\d+) \([\d+]%\), [\d.,]+ ([kmgtp]?h), ([0-9.,]+) ([kmgtp]?h/s)" -or # lyclMiner
            #[2019-05-27 21:33:34] accepted: 202/203 (diff 0.003), 1408.09 kH/s yes!
            $_ -match "accepted: (\d+)/(\d+) \(diff [\d,.]+\), ([\d,.]+) ([kmgtp]?h/s)" -or #CCMiner
            $false
        ) {
            $HashRate = $Matches[3] -replace ',', '.'
            $Units = $Matches[4]
            if ($HashRate -gt 0) {
                $Shares = @(
                    [int64]($Matches[1])
                    [int64]($Matches[2] - $Matches[1])
                )
            }
        } elseif (
            $_ -match "Total ([\d.,]+) ([kmgtp]?h/s)" -or # SilentArmy
            $_ -match "Results: ([\d,.]+) ([kmgtp]?gps), sub:(\d+) acc:(\d+) rej:(\d+)" -or # SwapMiner
            $false
        ) {
            $HashRate = $Matches[1] -replace ',', '.'
            $Units = $Matches[2] -replace "gps", "h/s"
            # } elseif ($_ -match "Statistics: GPU (\d+): mining at ([0-9,.]+) (gps), solutions: (\d+)") {
            #     # SwapMiner per card
            #     [int]$DevIndex = $Matches[1]
            #     [decimal]$DevHash = $Matches[2] -replace ',', '.'
            #     $CardsArray[$DevIndex] = $DevHash
            #     $HashRate = $CardsArray | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            #     $Units = $Matches[3] -replace "gps", "h/s"
        } elseif ($_ -match "Device #(\d+): ([0-9,.]+) ([kmgtp]?h), ([0-9,.]+) ([kmgtp]?h/s)") {
            # Device #0: 461.37 MH, 43.88 MH/s
            # lyclMiner per card
            [int]$DevIndex = $Matches[1]
            [decimal]$DevHash = $Matches[4] -replace ',', '.'
            $CardsArray[$DevIndex] = $DevHash
            $HashRate = $CardsArray | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            $Units = $Matches[5]
        }

        if ($HashRate -gt 0) {
            "`nWrapper Detected HashRate: $HashRate $Units" + $(if ($Shares) { ", Acc/Rej: $($Shares -join "/")" }) | Write-Host -BackgroundColor Yellow -ForegroundColor Black

            $HashRate *= switch ($Units) {
                "kh/s" { 1e3 }
                "mh/s" { 1e6 }
                "gh/s" { 1e9 }
                "th/s" { 1e12 }
                "ph/s" { 1e15 }
                Default { 1 }
            }
            ConvertTo-Json @{
                Hashrate = $HashRate
                Shares   = $Shares
            } | Set-Content ".\Wrapper_$Id.json"

        }
    }
    if (-not (Get-Process | Where-Object Id -EQ $ControllerProcessID)) { $PowerShell.Stop() | Out-Null }
    Start-Sleep -Seconds 1
} until($Result.IsCompleted)

if (Test-Path ".\Wrapper_$Id.json") { Remove-Item ".\Wrapper_$Id.json" }
