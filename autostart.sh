#!/bin/bash

export GPU_FORCE_64BIT_PTR=1
export GPU_MAX_HEAP_SIZE=100
export GPU_USE_SYNC_OBJECTS=1
export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100

Mode=Automatic
Pools=NiceHash,ZergPool,Zpool,WhatToMine
Algos=
Coins=

Command="& .\Core.ps1 -MiningMode ${Mode} -PoolsName ${Pools}"

pwsh -executionpolicy bypass -command ${Command}
