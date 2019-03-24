## Work in Progress, but should be usable

### Limitations
Currently only AMD and CPU miners are tested


### Prerequisites
- Powershell Core (Latest Release: https://github.com/PowerShell/PowerShell/releases/tag/v6.1.3). Do not use version from Snap
- Ubuntu 18.04+, Linux Mint 19.1
- Packages: p7zip-full
- AMD Drivers: AMDGPU-PRO drivers require kernel 4.15.0 currently. ROCm Drivers untested
- To install the drivers on Mint or Ubuntu 19.10, you must (temporary) set the following values in /etc/os-release
```
ID=ubuntu
VERSION_ID="18.04"
```
- Read the divers documentation for install instructions. I do not provide support for installing drivers, operating systems and other
- Other configurations may work, but untested. Reports are welcome


### AMD Configuration
add to ~/.profile
```
export GPU_FORCE_64BIT_PTR=0    # Use 1 if only 3GB video memory is detected
export GPU_MAX_HEAP_SIZE=100
export GPU_USE_SYNC_OBJECTS=1
export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100
```


### NVIDIA Configuration
add to ~/.profile
```
export CUDA_DEVICE_ORDER='PCI_BUS_ID'
```


### Troubleshooting miners
- Some miners will require additional packages installed. Most common ones are:
- libuv1-dev libmicrohttpd-dev libcurl3 libcurl-openssl1.0-dev libssl-dev

- If miner fails to start, check console.log and error.log in specific miner folder.
