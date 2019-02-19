## Forager
Advanced open source multi-pool / multi-algo profit switching miner

It will use profit information from supporting pools to make sure you mine the most profitable algorithm at all times
You can also use WhatToMine and CoinCalculators virtual pools for profit data and mine to pools which dont provide profit information, or even your custom pools

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


### Notes:
- Recommended drivers for AMD - 18.3.4 or 18.6.1.
  18.4.1/18.7.1 are problematic and not recommended
  18.8.1 and higher have issues with Optiminer and some others
  you can use https://forums.guru3d.com/threads/atic-install-tool-radeon-drivers-download-utility.422576/ to easily find and download specific driver version

- Recommended drivers for NVIDIA on Win 10 - 411.31+ for CUDA 10. Set CUDAVersion = 10.0 in Config.ini
- Recommended drivers for NVIDIA on Win 10 - 398.+ for CUDA 9.2
- Recommended drivers for NVIDIA on Win 7 - 390.65-391.01 Set CUDAVersion = 9.1 in Config.ini

- Using PowerShell Core recommended - https://github.com/PowerShell/PowerShell/releases
- Windows 7 will require PowerShell Core or PowerShell v5 installed: https://www.microsoft.com/en-us/download/details.aspx?id=54616

- Recommended MSI Afterburner version is 4.5.0 or newer
  prior versions don't support Intel CPU power usage and may not fully support your GPU

- Some miners when benchmarking X16r/X16s (AMD) submit "fake" shares that get rejected by the pools.
  Ignore this and after benchmarking it will work normally.

- XMR-Stak (AMD and NVIDIA) doesn't support multiple groups per GPU Vendor (2+ AMD or NVIDIA) out of the box.
  Of first run it will create "GroupName-Algorithm.txt" files for each group that you can edit once to include only the relevant GPUs.

- Mixed rigs (AMD+NVIDIA) are not recommended. Use at your own risk.
  You may have problems with some miners selecting specific devices. Disable problematic miners if you have issues.


### Getting started:
- Option 1:
 Download latest Forager release (7zip or self-extracting SFX) from https://github.com/yuzi-co/Forager/releases and extract it

- Option 2:
Install GIT (https://git-scm.com/download/win), open command line and run "git clone https://github.com/yuzi-co/Forager/" to get latest master version

### Configure:
Copy Config-SAMPLE.ini to Config.ini and edit it with your preferred currencies, wallets and pool users
See Autostart*.bat files for launch examples

When using mixed card models (i.e. RX580 + RX Vega), it is recommended to define separate GpuGroups in Config.ini to be able to benchmark benchmark them separately and mine the algos most profitable for the specific card models.

When run, Forager will benchmark all available Miner/Algo combinations and afterwards will start mining the most profitable combination.
Be aware that benchmarking can be a long process

### Upgrade:
- Option 1:
Download latest Forager release (7zip or self-extracting SFX) and extract to a new folder
Copy your customized Autostart.bat, Config.ini and Stats folder to new version folder

- Option 2 (if initially installed using GIT):
Run "git pull" in Forager folder to get latest master version


### Forager folder structure:
```
/Additional Miners/	- Miners disabled by default, usually because of low profitability or issues
/Bin/			- Installed miners are located in this folder
/Cache/			- Cached API requests storage. Can be purged at will. Old files automatically cleaned on start.
/Data/			- Data files containing different mappings and lists required for Forager
/Downloads/		- Downloaded miner archives. Can be purged at will.
/Includes/		- Code includes and binary helper programs
/Logs/			- Runtime logs and session reports (if enabled). Old files automatically cleaned on start.
/Miners/		- Miner definitions
/Patterns/		- Miner config templates
/Pools/			- Pool definitions
/Stats/			- Miner benchmarks and run statistics
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
