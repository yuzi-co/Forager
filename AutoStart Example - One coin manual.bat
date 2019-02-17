@echo off

cd /d %~dp0

set Mode=Manual
set Pools=SuprNova
set Coins=Bitcore

set Command="& .\Core.ps1 -MiningMode %Mode% -PoolsName %Pools% -Coinsname %Coins%"

where pwsh >nul 2>nul || goto powershell
pwsh -noexit -executionpolicy bypass -command %Command%
goto end

:powershell
powershell -version 5.0 -noexit -executionpolicy bypass -command %Command%

:end
pause
