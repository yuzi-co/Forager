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

0 | Set-Content ".\Wrapper_$Id.txt"

$PowerShell = [PowerShell]::Create()
if ($WorkingDirectory -ne "") {$PowerShell.AddScript("Set-Location '$WorkingDirectory'") | Out-Null}
$Command = ". '$FilePath'"
if ($ArgumentList -ne "") {$Command += " $ArgumentList"}
$PowerShell.AddScript("$Command 2>&1 | Write-Verbose -Verbose") | Out-Null
$Result = $PowerShell.BeginInvoke()

Write-Host "Wrapper Started" -BackgroundColor Yellow -ForegroundColor Black
$CardsArray = @(0) * 20

do {
    $PowerShell.Streams.Verbose.ReadAll() | ForEach-Object {
        $Param = @{}
        if (
            $PSVersionTable.PSVersion.Major -lt 6 -and
            $Command -like '*energiminer.exe*'
        ) {
            $Param.NoNewLine = $true
        }
        Write-Host $_ @Param

        $HashRate = 0

        if (
            $_ -match "Speed\s([0-9.,]+)\s?([kmgtp]?h/s)" -or # EnergiMiner
            $_ -match "Accepted.*\s([0-9.,]+)\s([kmgtp]?h/s)" -or # lyclMiner
            $_ -match "Total\s([0-9.,]+)\s([kmgtp]?h/s)" -or # SilentArmy
            $_ -match "Results: ([\d,.]+) ([kmgtp]?gps), sub:(\d+) acc:(\d+) rej:(\d+)" -or # SwapMiner
            $false
        ) {
            [decimal]$HashRate = $Matches[1] -replace ',', '.'
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
            "`nWrapper Detected HashRate: $HashRate $Units" | Write-Host -BackgroundColor Yellow -ForegroundColor Black

            $HashRate *= switch ($Units) {
                "kh/s" { 1e3 }
                "mh/s" { 1e6 }
                "gh/s" { 1e9 }
                "th/s" { 1e12 }
                "ph/s" { 1e15 }
                Default { 1 }
            }
            $HashRate -replace ',', '.' | Set-Content ".\Wrapper_$Id.txt"
        }
    }
    if (-not (Get-Process | Where-Object Id -EQ $ControllerProcessID)) {$PowerShell.Stop() | Out-Null}
    Start-Sleep -Seconds 1
} until($Result.IsCompleted)
