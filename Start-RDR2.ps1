# ==============================================================================
# CONFIGURATION
# ==============================================================================
$SteamGameURL     = "steam://rungameid/1174180"
$GameProcessName  = "RDR2"
$TimeoutSeconds   = 120  # Extended to allow Rockstar Launcher to log in and sync

# ==============================================================================
# WIN32 API FOR ECO-QOS (EFFICIENCY MODE)
# ==============================================================================
$Win32Code = @"
using System;
using System.Runtime.InteropServices;

public class Win32Power {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, int processId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetProcessPowerThrottling(
        IntPtr hProcess, 
        int ControlStructure, 
        ref PROCESS_POWER_THROTTLING_STATE State, 
        uint StateBufferSize
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_POWER_THROTTLING_STATE {
        public uint Version;
        public uint ControlMask;
        public uint StateMask;
    }

    public static bool EnableEcoQoS(int pid) {
        IntPtr hProcess = OpenProcess(0x0200, false, pid); // PROCESS_SET_INFORMATION
        if (hProcess == IntPtr.Zero) return false;

        PROCESS_POWER_THROTTLING_STATE state = new PROCESS_POWER_THROTTLING_STATE();
        state.Version = 1; 
        state.ControlMask = 0x00000001; // PROCESS_POWER_THROTTLING_EXECUTION_SPEED
        state.StateMask = 0x00000001;   // Enable Throttling (EcoQoS)

        bool success = SetProcessPowerThrottling(hProcess, 1, ref state, (uint)Marshal.SizeOf(state));
        CloseHandle(hProcess);
        return success;
    }
}
"@
Add-Type -TypeDefinition $Win32Code

# ==============================================================================
# SCRIPT EXECUTION
# ==============================================================================
try {
    Write-Host "Initializing Red Dead Redemption 2 via Steam Protocol..." -ForegroundColor Cyan
    # Explicitly using explorer.exe forces Windows to execute the custom steam:// URI path
    Start-Process "explorer.exe" -ArgumentList $SteamGameURL

    Write-Host "Monitoring background infrastructure. Waiting for RDR2.exe..." -ForegroundColor Yellow
    $SecondsElapsed = 0
    $GameProcess = $null

    # Watch loop for RDR2 process initialization
    while ($null -eq $GameProcess -and $SecondsElapsed -lt $TimeoutSeconds) {
        $GameProcess = Get-Process -Name $GameProcessName -ErrorAction SilentlyContinue
        if ($null -eq $GameProcess) {
            Start-Sleep -Seconds 1
            $SecondsElapsed++
        }
    }

    # Handle timeout if Rockstar Launcher fails to boot the actual game
    if ($null -eq $GameProcess) {
        throw "RDR2.exe failed to instantiate within the allocated $TimeoutSeconds seconds."
    }

    Write-Host "RDR2 Detected (PID: $($GameProcess.Id)). Downscaling resource footprints..." -ForegroundColor Cyan

    # Step 1: Lower Process Priority
    $GameProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle

    # Step 2: Apply EcoQoS (Efficiency Mode / Green Leaf status)
    $EcoSuccess = [Win32Power]::EnableEcoQoS($GameProcess.Id)

    if ($EcoSuccess) {
        Write-Host "Efficiency Mode actively applied to RDR2." -ForegroundColor Green
        # SUCCESS AUDIO: Clear chime directly over the game's splash screen audio
        [System.Media.SystemSounds]::Asterisk.Play()
    } else {
        throw "EcoQoS parameters rejected by the Windows kernel framework."
    }
}
catch {
    Write-Error "Optimization pipeline failure: $_"
    # FAILURE AUDIO: Distinct heavy system drop to flag a launch sequence breakdown
    [System.Media.SystemSounds]::Hand.Play()
}
