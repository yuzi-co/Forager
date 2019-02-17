@echo off

cd /d %~dp0

set Command="& .\Miner.ps1"

where pwsh >nul 2>nul || goto powershell
pwsh -noexit -executionpolicy bypass -command %Command%
goto end

:powershell
powershell -version 5.0 -noexit -executionpolicy bypass -command %Command%

:end
pause
