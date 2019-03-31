
enum CreationFlags {
    NONE = 0
    DEBUG_PROCESS = 0x00000001
    DEBUG_ONLY_THIS_PROCESS = 0x00000002
    CREATE_SUSPENDED = 0x00000004
    DETACHED_PROCESS = 0x00000008
    CREATE_NEW_CONSOLE = 0x00000010
    CREATE_NEW_PROCESS_GROUP = 0x00000200
    CREATE_UNICODE_ENVIRONMENT = 0x00000400
    CREATE_SEPARATE_WOW_VDM = 0x00000800
    CREATE_SHARED_WOW_VDM = 0x00001000
    CREATE_PROTECTED_PROCESS = 0x00040000
    EXTENDED_STARTUPINFO_PRESENT = 0x00080000
    CREATE_BREAKAWAY_FROM_JOB = 0x01000000
    CREATE_PRESERVE_CODE_AUTHZ_LEVEL = 0x02000000
    CREATE_DEFAULT_ERROR_MODE = 0x04000000
    CREATE_NO_WINDOW = 0x08000000
}

enum WindowStyle {
    Normal = 5
    Maximized = 3
    Minimized = 7
}

enum STARTF {
    STARTF_USESHOWWINDOW = 0x00000001
    STARTF_USESIZE = 0x00000002
    STARTF_USEPOSITION = 0x00000004
    STARTF_USECOUNTCHARS = 0x00000008
    STARTF_USEFILLATTRIBUTE = 0x00000010
    STARTF_RUNFULLSCREEN = 0x00000020 #ignored for non-x86 platforms
    STARTF_FORCEONFEEDBACK = 0x00000040
    STARTF_FORCEOFFFEEDBACK = 0x00000080
    STARTF_USESTDHANDLES = 0x00000100
}

function Invoke-CreateProcess {
    param (
        [parameter(mandatory = $true)][string]$FilePath,
        [parameter(mandatory = $false)][string]$ArgumentList = $null,
        [CreationFlags][parameter(mandatory = $true)]$CreationFlags,
        [WindowStyle][parameter(mandatory = $true)]$WindowStyle,
        [StartF][parameter(mandatory = $true)]$StartF,
        [parameter(Mandatory = $false)][string]$WorkingDirectory = ""
    )

    Add-Type -TypeDefinition @"
	using System;
	using System.Diagnostics;
	using System.Runtime.InteropServices;

	[StructLayout(LayoutKind.Sequential)]
	public struct PROCESS_INFORMATION
	{
		public IntPtr hProcess; public IntPtr hThread; public uint dwProcessId; public uint dwThreadId;
	}

	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
	public struct STARTUPINFO
	{
		public uint cb; public string lpReserved; public string lpDesktop; public string lpTitle;
		public uint dwX; public uint dwY; public uint dwXSize; public uint dwYSize; public uint dwXCountChars;
		public uint dwYCountChars; public uint dwFillAttribute; public uint dwFlags; public short wShowWindow;
		public short cbReserved2; public IntPtr lpReserved2; public IntPtr hStdInput; public IntPtr hStdOutput;
		public IntPtr hStdError;
	}

	[StructLayout(LayoutKind.Sequential)]
	public struct SECURITY_ATTRIBUTES
	{
		public int length; public IntPtr lpSecurityDescriptor; public bool bInheritHandle;
	}

	public static class Kernel32
	{
		[DllImport("kernel32.dll", SetLastError=true)]
		public static extern bool CreateProcess(
			string lpApplicationName, string lpCommandLine, ref SECURITY_ATTRIBUTES lpProcessAttributes,
			ref SECURITY_ATTRIBUTES lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags,
			IntPtr lpEnvironment, string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo,
			out PROCESS_INFORMATION lpProcessInformation);
	}
"@

    # StartupInfo Struct
    $StartupInfo = New-Object STARTUPINFO
    $StartupInfo.dwFlags = $StartF # StartupInfo.dwFlag
    $StartupInfo.wShowWindow = $WindowStyle # StartupInfo.ShowWindow
    $StartupInfo.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($StartupInfo) # Struct Size

    # ProcessInfo Struct
    $ProcessInfo = New-Object PROCESS_INFORMATION

    # SECURITY_ATTRIBUTES Struct (Process & Thread)
    $SecAttr = New-Object SECURITY_ATTRIBUTES
    $SecAttr.Length = [System.Runtime.InteropServices.Marshal]::SizeOf($SecAttr)

    if (-not $WorkingDirectory) {
        # CreateProcess --> lpCurrentDirectory
        $WorkingDirectory = (Get-Item -Path ".\" -Verbose).FullName
    }

    $ArgumentList = '"' + $FilePath + '" ' + $ArgumentList

    # Call CreateProcess
    [Kernel32]::CreateProcess($FilePath, $ArgumentList, [ref]$SecAttr, [ref]$SecAttr, $false, $CreationFlags, [IntPtr]::Zero, $WorkingDirectory, [ref]$StartupInfo, [ref]$ProcessInfo) | Out-Null

    $Process = Get-Process -Id $ProcessInfo.dwProcessId
    $Process.Handle | Out-Null
    $Process
}
