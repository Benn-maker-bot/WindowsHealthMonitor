# Windows Health Monitor: working instructions

Read this file, PROJECT-HISTORY.md and the current WindowsHealthMonitor.ps1 before changing anything.
(This is the project's equivalent of a CLAUDE.md file.)

## Purpose

A reliable Windows 11 health-monitoring PowerShell script that:

- checks the Windows component store with DISM;
- repairs component-store corruption with /RestoreHealth when appropriate;
- checks protected system files with SFC;
- repairs SFC corruption when necessary;
- confirms every repair with a second scan, rather than trusting exit codes alone;
- produces readable logs and machine-readable results;
- is suitable for Windows Task Scheduler.

## Environment

- Windows 11 Pro 26H2 (build 26300), computer name NEW. Owner: Benn.
- Run with administrator rights (elevated window, or a scheduled task with "Run with highest privileges").
- Windows PowerShell 5.1 is built in. PowerShell 7.6.9 is installed from the **Microsoft Store**, which keeps it up to date.
- The script must work in **both** Windows PowerShell 5.1 and PowerShell 7, in syntax and at run time, unless a change is explicitly agreed.
- The script must **not** install, update or switch PowerShell. Manage PowerShell 7 separately (Microsoft Store or WinGet). Decided 29 October 2026, version 2.4.0.

## Where the files live

- **Master copy:** `C:\Scripts\WindowsHealthMonitor\` (moved from `C:\temp` on 29 October 2026). Guide, docs and Tests folders sit beside the script; older versions are in `Archive`. Not OneDrive: OneDrive would upload every report, and a scheduled task may not be able to read it.
- Reports: a `Logs` folder beside the script, one dated folder per run, kept 90 days.
- The copy of the script in this Claude Project is a **reference copy** of the latest release. The folder on the PC is the master; refresh the reference copy at each release.

## Reliability requirements

- Never treat "No component store corruption detected" as corruption: test the healthy phrase first.
- Check DISM's exit code (0, or 3010 = success with restart needed) before trusting its text.
- Judge SFC by its message (its exit codes are undocumented), but record any unusual exit code as a note.
- Capture native output as raw bytes and detect the encoding: SFC writes UTF-16LE.
- Confirm a DISM repair with another /ScanHealth, and an SFC repair with another /verifyonly.
- Prevent concurrent runs (a Windows mutex; a second run exits with code 10).
- Apply time limits, stop the whole process tree on time-out, and keep the output captured so far.
- Never restart Windows automatically.
- Skip the checks (code 6) only for restart signals that affect servicing; never use PendingFileRenameOperations.
- Fail visibly: the verdict starts as "failed"; an unrecognised result is code 5, never code 0.
- Always report: Summary.txt, Result.json, Event Viewer entry and lock release sit in a `finally` block.

## Technical rules learned the hard way

- Keep the file plain ASCII. Windows PowerShell 5.1 reads a BOM-less file as ANSI, so any non-ASCII character can break it.
- Never wrap a .NET `List[object]` in `@()`; use `.ToArray()` (PowerShell throws "Argument types do not match").
- Convert exit codes to hexadecimal through `[BitConverter]`, never `[uint32]` (negative error codes crash it).
- Avoid `& tool 2>&1` under `$ErrorActionPreference = 'Stop'` in 5.1; run tools through `System.Diagnostics.Process`.
- Compare versions as `[version]`, not as text.
- PowerShell variable names ignore case: `$B` and `$b` are the same variable.

## Reporting

Each run produces, in `Logs\<yyyy-MM-dd_HHmmss>\`:

- Summary.txt, Result.json and Full-Transcript.txt;
- one report file per tool run (1- to 6-);
- SFC-CBS-Details.txt (this run's [SR] lines from CBS.log) after SFC /scannow;
- an Application event log entry, source WindowsHealthMonitor, event ID 1000 + result code;
- a 60-second pop-up when someone is signed in to see it.

## How we work

1. Read PROJECT-HISTORY.md and the current script first.
2. Explain significant behavioural changes before making them.
3. Keep Windows PowerShell 5.1 compatibility.
4. Run the checks in TESTING.md: parse check, 5.1-syntax scan, script analyser, and the simulated scenarios.
5. Never claim DISM or SFC behaviour was tested on Windows unless it actually ran on Windows. Say "simulated" for the Linux test harness.
6. Never paste the script into a chat box (pasting converts `<#` to `&lt;#` and web addresses to HTML). Attach the file, or work from the connected folder.
7. One editor at a time. A version from another assistant is a draft until it has been reviewed and has passed the checks.
8. For every release, bump `$ScriptVersion` and update CHANGELOG.md, and PROJECT-HISTORY.md if something was learned.
9. Write in British English, in the active voice.
