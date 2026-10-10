# Start RDR2 in Windows Efficiency Mode

`Start-RDR2.ps1` launches Red Dead Redemption 2 through Steam, waits for
`RDR2.exe`, and asks Windows to enable **Efficiency Mode** for that process.
It is intended to automate the same per-launch change available from Windows
Task Manager.

## Why this project exists

This project has two goals.

First, it removes a frustrating manual step for players whose RDR2 experience
improves when Windows Efficiency Mode is enabled. Instead of launching the game,
opening Task Manager, finding `RDR2.exe`, and remembering to enable the setting
every time, the launcher performs that work automatically and confirms the
result.

Second, it is meant to be a practical introduction to PowerShell automation.
Learning examples are much easier to understand when they solve a real problem
you recognize and care about. This script is deliberately documented so a
curious player can inspect it and see a useful automation pattern in action:
launch something, wait for the right process, make a targeted change, verify the
result, and provide clear feedback. If it sparks an interest in using PowerShell
to remove other small frustrations, it has succeeded beyond its immediate
purpose.

## What the script changes

The script does not modify game files, registry settings, Steam settings, or
Windows' permanent configuration. It applies the two process-level settings
that Task Manager uses for Efficiency Mode: an `Idle` base priority and Windows
EcoQoS. Both changes end when the game process ends.

> **Note**
> Efficiency Mode asks Windows to favor efficiency over execution speed and
> lowers the process priority. Its behavior and effectiveness can vary across
> Windows versions and hardware. Use it only if it improves your own system's
> RDR2 experience.

## Requirements

- Windows 11 (supported)
- Windows 10 is unsupported and not guaranteed to provide the required
  Efficiency Mode behavior or verification APIs.
- Steam with Red Dead Redemption 2 installed and signed in
- Windows PowerShell 5.1 or newer (included with supported Windows versions)

No administrator rights should normally be needed. If Windows reports that the
game process could not be opened, start the script at the same privilege level
as Steam and the Rockstar Games Launcher. Do not run it as administrator unless
those applications are also running as administrator.

## Quick start

1. Download this repository with **Code** > **Download ZIP** on GitHub.
2. Extract the ZIP somewhere permanent, for example `C:\Scripts\Start-RDR2`.
   Do not run it from inside the ZIP file.
3. Choose one launcher, then double-click it:

   - `Start-RDR2.bat` — plays the result sound and closes the console window
     when finished.
   - `Start-RDR2-Keep-Window-Open.bat` — plays the result sound and leaves the
     console window open until you press Enter. Choose this one if you want to
     read the final message or cannot rely on an audible notification.

4. Steam starts RDR2. The script waits for `RDR2.exe`, keeps the setting applied
   for 30 seconds while the game initializes, verifies it, then plays a Windows
   success sound. The first launcher closes its console window; the second one
   leaves it open.

If Steam or the Rockstar Games Launcher needs longer than two minutes, fix its
sign-in/update issue and run the launcher again. The script times out after 120
seconds rather than waiting indefinitely.

### Run directly from PowerShell

If you are comfortable using PowerShell, you can skip the batch launchers.
Open PowerShell in this folder and run:

```powershell
.\Start-RDR2.ps1
```

Because you launched the script from an interactive PowerShell session, that
window remains open after the script finishes. You can read the final result
there without using `-KeepWindowOpen`.

If your execution policy prevents the script from starting, use this one-time
command instead. It bypasses the policy only for this new PowerShell process; it
does not change your system-wide or user-level execution-policy setting:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Start-RDR2.ps1
```

## Keep the result window open

The default launcher communicates its result with a sound because RDR2 usually
opens full screen. Visual confirmation is equally important: some players may
be unable to hear that sound, may have a hearing impairment, may be playing
without speakers or headphones, or may simply prefer to read the outcome.

`Start-RDR2-Keep-Window-Open.bat` was included specifically for those players.
Double-click it for a launch with visual confirmation; no editing is needed.
It leaves the console open until you press Enter and shows whether Efficiency
Mode was successfully confirmed or why the attempt failed.

`-KeepWindowOpen` is useful only when the script is launched from a console
that would otherwise close as soon as it finishes. For example, you can pass it
to the standard batch launcher from Command Prompt:

```text
Start-RDR2.bat -KeepWindowOpen
```

With `-KeepWindowOpen`, the same success or failure sound plays and the window
stays open until you press Enter. You can also change the startup timeout when
running directly from PowerShell, for example:

```powershell
.\Start-RDR2.ps1 -TimeoutSeconds 300
```

If you create your own batch launcher, keep the script path and its parameters
separate. This is correct:

```bat
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-RDR2.ps1" -KeepWindowOpen
```

This is not correct, because PowerShell treats the parameter as though it were
part of the file name:

```bat
powershell.exe -File "%~dp0Start-RDR2.ps1 -KeepWindowOpen"
```

The script applies and verifies the setting for 30 seconds after the game is
first detected. This accommodates RDR2 changing its own process settings during
startup. You can adjust that window when needed:

```powershell
.\Start-RDR2.ps1 -StabilizationSeconds 60
```

## What the script does

1. Opens Steam's official RDR2 launch URI (`steam://rungameid/1174180`).
2. Checks once per second for `RDR2.exe`.
3. When it finds the process, it sets the process base priority to `Idle` and
   calls the Windows `SetProcessInformation` API with the
   `ProcessPowerThrottling` policy and the execution-speed flag (EcoQoS).
4. Reapplies those settings during the 30-second startup stabilization window,
   then reads them back from Windows.
5. Plays a success sound only when the final state is confirmed, or a failure
   sound and a readable error message if any step fails.

The script chooses the newest `RDR2.exe` process if Windows reports more than
one while an earlier instance is shutting down.

## Troubleshooting

| What you see | What to try |
| --- | --- |
| Failure sound after two minutes | Confirm Steam and Rockstar Games Launcher are signed in, then start the launcher again with `-KeepWindowOpen` to read the error. |
| “Could not open RDR2.exe” or “Access is denied” | Run Steam, Rockstar Games Launcher, and this script at the same privilege level. Close an older RDR2 instance before retrying. |
| No sound | Use `-KeepWindowOpen` to read the result. Check Windows volume/output settings independently. |
| Game is already running | The script applies Efficiency Mode to the newest running `RDR2.exe`; restart the game if you need Steam to launch a fresh session. |

## Safety and transparency

The launcher batch file uses `-ExecutionPolicy Bypass` only for the PowerShell
process that it starts. This avoids asking users to weaken their machine-wide
execution-policy setting; it does not change that setting. Both launcher files
are plain text and can be inspected in Notepad before use.

As with any downloaded script, read the files before running them and download
releases only from the repository you trust.

## Technical reference

Windows documents `SetProcessInformation` with `ProcessPowerThrottling` as the
API used to control the power-throttling policy. Opting into the execution-speed
flag classifies a process as EcoQoS. Task Manager's Efficiency Mode combines
EcoQoS with a lower process priority. See [Microsoft's SetProcessInformation
documentation](https://learn.microsoft.com/windows/win32/api/processthreadsapi/nf-processthreadsapi-setprocessinformation)
and [Microsoft's Efficiency Mode overview](https://devblogs.microsoft.com/performance-diagnostics/reduce-process-interference-with-task-manager-efficiency-mode/).
