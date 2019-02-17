@echo off

cd /d %~dp0

set Mode=Automatic
set Pools=NiceHash,Zpool,NLPool,ZergPool

set Command="& .\Core.ps1 -MiningMode %Mode% -PoolsName %Pools%"

where pwsh >nul 2>nul || goto powershell
pwsh -noexit -executionpolicy bypass -command %Command%
goto end

:powershell
powershell -version 5.0 -noexit -executionpolicy bypass -command %Command%

:end
pause
