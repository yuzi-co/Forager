## Forager
#### Advanced open source multi-pool / multi-algo profit switching miner

It will use profit information from supporting pools to make sure you mine the most profitable algorithm at all times
You can also use WhatToMine and CoinCalculators virtual pools for profit data and mine to pools which dont provide profit information, or even your custom pools ( see Pools/MyPools.ps1 for examples )

Using integration with MSI Afterburner, it will get real time power usage and use this information to calculate how much you pay and adjust the profitability data.

### Main features:
- Supports AMD/NVIDIA/CPU Mining
- Mine single coin or algo or Automatic profit switching on Zpool, Zergpool, NiceHash, MiningPoolHub and others
- Profitability info for all coins on WhatToMine and CoinCalculators
- MSI Afterburner integration for monitoring AMD/NVIDIA GPUs and Intel CPU power consumption and PowerLimit support for AMD/NVIDIA
- Fast benchmarking (Algos with stable hashrate finish within 2-3 mins)
- GPU Activity watchdog + Hashrate watchdog
- Reporting mining stats to https://multipoolminer.io/monitor/
- Power usage approximation for AMD and CPU when Afterburner integration is off
- Profit display in any fiat currency which is supported by CoinDesk
- SHA256 checksum validation for miner downloads
- Autoexec.txt for running custom programs on start. Autorun programs are also stopped on exit
- Enable/Disable a device group during runtime


### Notes:

#### Drivers:

Recommended drivers for AMD - 18.3.4 or 18.6.1.

You can use
https://forums.guru3d.com/threads/atic-install-tool-radeon-drivers-download-utility.422576/
to easily find and download specific driver version

Recommended drivers for NVIDIA on Win 10 - 411.31+ for CUDA 10

Recommended drivers for NVIDIA on Win 10 - 398.+ for CUDA 9.2

Recommended drivers for NVIDIA on Win 7 - 390.65-391.01 for CUDA 9.1


#### Powershell:

Using PowerShell Core recommended - https://github.com/PowerShell/PowerShell/releases

Windows 7 will require PowerShell Core or PowerShell v5 installed: https://www.microsoft.com/en-us/download/details.aspx?id=54616


##### Runtimes for miners:

.NET Core Runtime - https://dotnet.microsoft.com/download

MSVCR120 - https://www.microsoft.com/en-gb/download/details.aspx?id=40784

VCRUNTIME140 - https://www.microsoft.com/en-us/download/details.aspx?id=48145

Visual C++ Redistributable for Visual Studio 2015 - https://www.microsoft.com/en-US/download/details.aspx?id=48145


#### Afterburner

Recommended MSI Afterburner version is 4.5.0 or newer.
Prior versions don't support Intel CPU power usage and may not fully support your GPU

Some miners when benchmarking X16r/X16s (AMD) submit "fake" shares that get rejected by the pools.
Ignore this and after benchmarking it will work normally.

XMRig AMD doesn't support parameter detection for specified devices and will use all AMD devices.

XMR-Stak (AMD and NVIDIA) doesn't support multiple groups per GPU Vendor (2+ AMD or NVIDIA) out of the box.
Of first run it will create "GroupName-Algorithm.txt" files for each group that you can edit once to include only the relevant GPUs.

Mixed rigs (AMD+NVIDIA) are not recommended. Use at your own risk.
You may have problems with some miners selecting specific devices. Disable problematic miners if you have issues.

#### Nvidia-SMI

nvidia-smi.exe is included as an optional tool to modify gpu/memory clocks and other details of your Nvidia GPU(s)
for documentation on commands nvidia-smi.exe uses please refer to http://developer.download.nvidia.com/compute/DCGM/docs/nvidia-smi-367.38.pdf


### Getting started:
#### Option 1:

Download latest Forager release (7zip or self-extracting SFX) from https://github.com/yuzi-co/Forager/releases and extract it

#### Option 2:

Install GIT (https://git-scm.com/download/win), open command line and run
```git clone https://github.com/yuzi-co/Forager/```
to get latest master version

### Configure:

Copy /Config/Config-SAMPLE.ini Rename to /Config/Config.ini and edit it with your preferred currencies, wallets and pool users

Run START.bat to generate sample AutoStart.bat based on your selections or see Autostart*.bat files for examples

When using mixed card models (i.e. RX580 + RX Vega), it is recommended to define separate "GpuGroups" in Config.ini to be able
to benchmark them separately and mine the algos most profitable for the specific card models.

When run, Forager will benchmark all available Miner/Algo combinations and afterwards will start mining the most profitable combination.
Be aware that benchmarking can be a long process

Once run, a file will be created in /Config called "MinerParameters.json"
This file will be where you can set custom options/ parameters For each algo and miner,
The options are the same as the miner's command line options.
Review /Config/MinerParameters.Readme.txt for more info

### Upgrade:
#### Option 1:

Download latest Forager release (7zip or self-extracting SFX) and extract to a new folder
Copy your customized Autostart.bat, Config.ini and Stats folder to new version folder

#### Option 2 (if initially installed using GIT):

Run "git pull" in Forager folder to get latest master version


### Forager folder structure:
```
/Bin/               - Installed miners are located in this folder
/BinLinux/          - Installed miners are located in this folder. Linux only
/Cache/             - Cached API requests storage. Can be purged at will. Old files automatically cleaned on start.
/Config/            - User configuration files
/Data/              - Data files containing different mappings and lists required for Forager
/Downloads/         - Downloaded miner archives. Can be purged at will.
/Includes/          - Code includes and binary helper programs
/Logs/              - Runtime logs and session reports (if enabled). Old files automatically cleaned on start.
/Miners/            - Miner definitions in json format
/MinersLinux/       - Miner definitions in json format for Linux
/MinersDisabled/    - Miners disabled by default, usually because of low profitability or issues
/Pools/             - Pool definitions
/Stats/             - Miner benchmarks and run statistics. *_Hashrate.csv - Benchmark results, remove to re-benchmark. *_Stats.json - Runtime stats
```

### Helper scripts:
```
START.bat               - Menu based option Mining Mode / Pools / Coins selection. Will also generate a sample AutoStart.bat based on your selections.

AutoStart.bat           - Sample start script with recommended set of AutoExchange pools based on instant profitability
AutoStart24h.bat        - Sample start script with recommended set of AutoExchange pools based on 24h profitability (for supporting pools)

AutoStart Example*.bat  - Examples of startup scripts with Algo/Coin filters

BootStart.bat           - Starts AutoStart.bat after 3 minute delay. Can be added to Windows Autostart
DeviceList.bat          - List detected devices and suggested GpuGroups based on auto-detection
OpenCLList.bat          - List OpenCL devices
```


### Donations are welcome
```
BTC - 3FzmW9JMhgmRwipKkNnphxG73VPQMsYsN6
ETH - 0x38973025136D1a5B773aE71c02cA24b365850A9A
LTC - MM8RmXUgxDwHJxrC54muF7KHciSCFS3gx3
```

Disclaimer:

THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
