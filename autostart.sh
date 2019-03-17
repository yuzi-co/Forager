#!/bin/bash

Mode=Automatic
Pools=NiceHash
Algos=
Coins=

Command="& .\Core.ps1 -MiningMode ${Mode} -PoolsName ${Pools}"

pwsh -executionpolicy bypass -command ${Command}
