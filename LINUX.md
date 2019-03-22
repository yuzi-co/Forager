## Work in Progress, but should be usable with AMD

### Limitations
Currently only AMD and CPU miners are supported


### Prerequisites
- Powershell Core (Latest Release: https://github.com/PowerShell/PowerShell/releases/tag/v6.1.3). Do not use version from Snap
- Ubuntu 18.04
- Packages: p7zip-full
- AMD Drivers: AMDGPU-PRO (ROCm untested). Read the documentation!


### Configuration
add to ~/.profile
```
export GPU_FORCE_64BIT_PTR=0    # Use 1 if only 3GB video memory is detected
export GPU_MAX_HEAP_SIZE=100
export GPU_USE_SYNC_OBJECTS=1
export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100
```
