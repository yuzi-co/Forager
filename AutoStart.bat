@echo off

cd /d %~dp0

:: Use 1 if only 3GB video memory is detected
setx GPU_FORCE_64BIT_PTR 0
setx GPU_USE_SYNC_OBJECTS 1
setx GPU_MAX_HEAP_SIZE 100
setx GPU_MAX_ALLOC_PERCENT 100
setx GPU_SINGLE_ALLOC_PERCENT 100

set Mode=Automatic
set Pools=NiceHash,Zpool,ZergPool,WhatToMine

set Command="& .\Core.ps1 -MiningMode %Mode% -PoolsName %Pools%"

where pwsh >nul 2>nul || goto powershell
pwsh -executionpolicy bypass -command %Command%
goto end

:powershell
powershell -version 5.0 -executionpolicy bypass -command %Command%

:end
pause
