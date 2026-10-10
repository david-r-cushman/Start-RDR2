<#
.SYNOPSIS
Launches Red Dead Redemption 2 from Steam and enables Windows Efficiency Mode.

.DESCRIPTION
Waits for RDR2.exe after asking Steam to launch the game, then enables the
PROCESS_POWER_THROTTLING_EXECUTION_SPEED policy (EcoQoS / Efficiency Mode).
By default the script plays a result sound and finishes, allowing a console
opened by a batch file or Explorer to close normally. Use -KeepWindowOpen to
leave the result visible until Enter is pressed.

.PARAMETER KeepWindowOpen
Keeps the console open after the final success or failure message. This is a
visual alternative to relying on the result sound.

.PARAMETER TimeoutSeconds
The maximum number of seconds to wait for RDR2.exe to appear after Steam is
asked to launch the game. The default is 120 seconds.

.PARAMETER StabilizationSeconds
The number of seconds to keep reapplying Efficiency Mode while RDR2 starts.
The default is 30 seconds because the game can replace its own process settings
during startup.

.NOTES
This is a hybrid PowerShell script: most of the file is ordinary PowerShell,
while one small embedded C# class calls Windows APIs that do not have direct
PowerShell cmdlets. Useful terms to research from this example include
comment-based help, parameter validation, here-strings, Add-Type, P/Invoke,
static classes, and try/finally.

.EXAMPLE
.\Start-RDR2.ps1

Launches RDR2 using the default two-minute detection timeout and 30-second
startup stabilization window.

.EXAMPLE
.\Start-RDR2.ps1 -KeepWindowOpen

Leaves the final success or failure message visible until Enter is pressed.

.EXAMPLE
.\Start-RDR2.ps1 -TimeoutSeconds 300

Waits up to five minutes for RDR2.exe. This can help when Steam or the Rockstar
Games Launcher needs more time to sign in or update.

.EXAMPLE
.\Start-RDR2.ps1 -StabilizationSeconds 60

Keeps reapplying and verifying Efficiency Mode for 60 seconds after RDR2.exe is
first detected. Use this only when the default 30-second startup window is not
long enough for your system.
#>

[CmdletBinding()]
param(
    [switch] $KeepWindowOpen,

    [ValidateRange(1, 600)]
    [int] $TimeoutSeconds = 120,

    [ValidateRange(1, 120)]
    [int] $StabilizationSeconds = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Steam application ID for Red Dead Redemption 2.
$SteamGameUri = 'steam://rungameid/1174180'
$GameProcessName = 'RDR2'

function Initialize-NativeMethods {
    <#
    PowerShell does not include cmdlets for these particular Windows process
    settings. This function embeds a small amount of C# and uses Add-Type to
    compile it for this PowerShell session. The rest of the script can then
    call its public static methods with [TypeName]::MethodName(...).

    A static class is used here as a named container for related operations;
    the script does not need to create a NativeMethods object first.
    #>

    # Add-Type throws if a script is run again in the same PowerShell session.
    # Reuse the existing type in that case.
    if ('RDR2EfficiencyMode.NativeMethods' -as [type]) {
        return
    }

    $nativeCode = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace RDR2EfficiencyMode
{
    // This C# class is compiled by PowerShell's Add-Type command above.
    // "static" means its public methods are called directly from PowerShell:
    // [RDR2EfficiencyMode.NativeMethods]::EnableEfficiencyMode($processId)
    public static class NativeMethods
    {
        // These names and hexadecimal values come from the Windows API.
        // Keeping the documented names makes them easier to research.
        private const UInt32 PROCESS_SET_INFORMATION = 0x0200;
        private const UInt32 PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
        private const UInt32 IDLE_PRIORITY_CLASS = 0x0040;
        private const Int32 ProcessPowerThrottling = 4;
        private const UInt32 PROCESS_POWER_THROTTLING_CURRENT_VERSION = 1;
        private const UInt32 PROCESS_POWER_THROTTLING_EXECUTION_SPEED = 0x1;

        [StructLayout(LayoutKind.Sequential)]
        private struct PROCESS_POWER_THROTTLING_STATE
        {
            public UInt32 Version;
            public UInt32 ControlMask;
            public UInt32 StateMask;
        }

        // DllImport declares a C# method that forwards to a function already
        // provided by Windows in kernel32.dll. The private declarations below
        // are the low-level bridge; the public methods later in this class give
        // the PowerShell script a smaller, clearer interface.
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr OpenProcess(
            UInt32 processAccess,
            [MarshalAs(UnmanagedType.Bool)] bool inheritHandle,
            Int32 processId);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetProcessInformation(
            IntPtr process,
            Int32 processInformationClass,
            ref PROCESS_POWER_THROTTLING_STATE processInformation,
            UInt32 processInformationSize);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetProcessInformation(
            IntPtr process,
            Int32 processInformationClass,
            ref PROCESS_POWER_THROTTLING_STATE processInformation,
            UInt32 processInformationSize);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern UInt32 GetPriorityClass(IntPtr process);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetPriorityClass(IntPtr process, UInt32 priorityClass);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CloseHandle(IntPtr handle);

        public static void EnableEfficiencyMode(Int32 processId)
        {
            // A process handle is Windows' temporary reference to another
            // running program. It must be closed in the finally block below.
            IntPtr process = OpenProcess(
                PROCESS_SET_INFORMATION | PROCESS_QUERY_LIMITED_INFORMATION,
                false,
                processId);
            if (process == IntPtr.Zero)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not open RDR2.exe");
            }

            try
            {
                UInt32 originalPriority = GetPriorityClass(process);
                if (originalPriority == 0)
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read RDR2.exe priority");
                }

                // Task Manager's Efficiency Mode consists of both an idle base
                // priority and EcoQoS. EcoQoS alone does not show as the full
                // Efficiency Mode state in Task Manager.
                if (!SetPriorityClass(process, IDLE_PRIORITY_CLASS))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not set RDR2.exe to idle priority");
                }

                PROCESS_POWER_THROTTLING_STATE state = new PROCESS_POWER_THROTTLING_STATE();
                state.Version = PROCESS_POWER_THROTTLING_CURRENT_VERSION;
                state.ControlMask = PROCESS_POWER_THROTTLING_EXECUTION_SPEED;
                state.StateMask = PROCESS_POWER_THROTTLING_EXECUTION_SPEED;

                if (!SetProcessInformation(
                    process,
                    ProcessPowerThrottling,
                    ref state,
                    (UInt32)Marshal.SizeOf(typeof(PROCESS_POWER_THROTTLING_STATE))))
                {
                    Int32 error = Marshal.GetLastWin32Error();
                    // Do not leave a partial priority change when the second
                    // half of Task Manager's Efficiency Mode could not apply.
                    SetPriorityClass(process, originalPriority);
                    throw new Win32Exception(error, "Windows rejected the Efficiency Mode request");
                }
            }
            finally
            {
                CloseHandle(process);
            }
        }

        public static bool IsEfficiencyModeEnabled(Int32 processId)
        {
            // This separate read-back method prevents a successful API call
            // from being mistaken for a setting that the game later replaced.
            IntPtr process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, processId);
            if (process == IntPtr.Zero)
            {
                return false;
            }

            try
            {
                if (GetPriorityClass(process) != IDLE_PRIORITY_CLASS)
                {
                    return false;
                }

                PROCESS_POWER_THROTTLING_STATE state = new PROCESS_POWER_THROTTLING_STATE();
                state.Version = PROCESS_POWER_THROTTLING_CURRENT_VERSION;
                if (!GetProcessInformation(
                    process,
                    ProcessPowerThrottling,
                    ref state,
                    (UInt32)Marshal.SizeOf(typeof(PROCESS_POWER_THROTTLING_STATE))))
                {
                    return false;
                }

                return (state.StateMask & PROCESS_POWER_THROTTLING_EXECUTION_SPEED) != 0;
            }
            finally
            {
                CloseHandle(process);
            }
        }
    }
}
'@

    Add-Type -TypeDefinition $nativeCode -Language CSharp -ErrorAction Stop
}

function Get-Rdr2Process {
    <#
    Returns the RDR2 process that should receive the setting, or $null when it
    is not running. A PowerShell pipeline produces zero, one, or many objects;
    @() forces the result into an array so .Count behaves consistently.
    #>

    # The game normally has one process. Selecting the newest one makes a
    # re-launch deterministic if a stale process is still shutting down.
    $processes = @(Get-Process -Name $GameProcessName -ErrorAction SilentlyContinue |
        Where-Object { -not $_.HasExited } |
        Sort-Object -Property StartTime -Descending)

    if ($processes.Count -gt 0) {
        return $processes[0]
    }

    return $null
}

function Complete-Script {
    <#
    Centralizes the final user feedback so success and failure always behave
    the same way: a colored message, an appropriate sound, and an optional
    visible prompt. "Complete" is an approved PowerShell verb.
    #>

    param(
        [Parameter(Mandatory)] [bool] $Succeeded,
        [Parameter(Mandatory)] [string] $Message
    )

    if ($Succeeded) {
        Write-Host $Message -ForegroundColor Green
        [System.Media.SystemSounds]::Asterisk.Play()
    }
    else {
        Write-Host $Message -ForegroundColor Red
        [System.Media.SystemSounds]::Hand.Play()
    }

    # Give Windows time to start the sound before a console launched from a
    # double-click closes. This does not affect -KeepWindowOpen users.
    Start-Sleep -Milliseconds 750

    if ($KeepWindowOpen) {
        Write-Host ''
        Read-Host 'Press Enter to close this window' | Out-Null
    }
}

try {
    # A try/catch block lets every error take the same friendly failure path,
    # including launch errors, a timeout, and a rejected Windows API request.
    Initialize-NativeMethods

    Write-Host 'Launching Red Dead Redemption 2 through Steam...' -ForegroundColor Cyan
    # Explorer reliably hands custom steam:// URIs to Windows' registered handler.
    Start-Process -FilePath 'explorer.exe' -ArgumentList $SteamGameUri -ErrorAction Stop

    Write-Host "Waiting up to $TimeoutSeconds seconds for RDR2.exe..." -ForegroundColor Yellow
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $gameProcess = $null

    do {
        $gameProcess = Get-Rdr2Process
        if ($null -eq $gameProcess) {
            Start-Sleep -Seconds 1
        }
    } while ($null -eq $gameProcess -and (Get-Date) -lt $deadline)

    if ($null -eq $gameProcess) {
        throw "RDR2.exe did not start within $TimeoutSeconds seconds. Check Steam and the Rockstar Games Launcher, then try again."
    }

    Write-Host "RDR2.exe detected. Applying and verifying Efficiency Mode for $StabilizationSeconds seconds while the game initializes..." -ForegroundColor Cyan
    $stabilizationDeadline = (Get-Date).AddSeconds($StabilizationSeconds)

    # RDR2 can reset its own priority and QoS while it is still starting. Keep
    # applying the two settings during that period instead of reporting a
    # one-time API success that the game immediately replaces.
    do {
        $gameProcess = Get-Rdr2Process
        if ($null -eq $gameProcess) {
            throw 'RDR2.exe stopped before Efficiency Mode could be confirmed.'
        }

        # This is a static C# method call. The [TypeName]::MethodName syntax
        # calls the Windows-API wrapper without creating a .NET object.
        [RDR2EfficiencyMode.NativeMethods]::EnableEfficiencyMode($gameProcess.Id)
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $stabilizationDeadline)

    $gameProcess = Get-Rdr2Process
    # The same static-class syntax now asks Windows to read the setting back.
    if ($null -eq $gameProcess -or -not [RDR2EfficiencyMode.NativeMethods]::IsEfficiencyModeEnabled($gameProcess.Id)) {
        throw 'Windows did not retain Efficiency Mode after RDR2 finished initializing.'
    }

    Complete-Script -Succeeded $true -Message 'Success: Windows Efficiency Mode was enabled for RDR2.exe.'
}
catch {
    $detail = $_.Exception.Message
    Complete-Script -Succeeded $false -Message "Failed to enable Efficiency Mode: $detail"
}
