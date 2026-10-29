# Windows Health Monitor: CLAUDE.md

Working notes for Claude (chat or Claude Code) on this project. Read this file, docs/PROJECT-HISTORY.md, docs/TESTING.md and the whole of WindowsHealthMonitor.ps1 before changing anything.

**Authority:** the project instructions in the Claude Project "System Health Monitor" set the requirements. This file adds the facts about Benn's PC and the rules learned while building the script. If the two disagree, the project instructions win; correct this file.

## Purpose

A reliable Windows 11 health monitor: DISM checks and, if needed, repairs the component store; SFC checks and, if needed, repairs protected system files; every repair is confirmed by a second scan; every run produces readable and machine-readable reports; it runs unattended from Task Scheduler.

## Environment

- Windows 11 Pro 26H2 (build 26300), computer name NEW. Owner: Benn.
- Runs with administrator rights (elevated window, or a scheduled task with "Run with highest privileges").
- **Target runtime: the latest stable PowerShell 7 (`pwsh.exe`).** Currently 7.6.9, installed from the Microsoft Store, which keeps it up to date.
- Windows PowerShell 5.1 is built into Windows. Compatibility with it is **not required**. Version 2.4.0 still happens to run in 5.1, but a better PowerShell 7 design takes priority (project instructions).
- The scheduled task should run `pwsh.exe`. Open question: the Store version is installed for Benn's account only, so a task that runs as SYSTEM or "whether user is logged on or not" may not be able to start it. See docs/PLAN-2.5.md.
- The script must **not** install, update or switch PowerShell; that is a separate job (decided 29 October 2026, version 2.4.0).

## Where the files live

- **Master copy:** `C:\Scripts\WindowsHealthMonitor\` (since 29 October 2026). Not OneDrive.
  - `WindowsHealthMonitor.ps1`, `WindowsHealthMonitor-Guide.docx`, `CLAUDE.md` (this file)
  - `docs\` PROJECT-HISTORY, TESTING, CHANGELOG, PLAN-2.5, LEARNING-LOG
  - `Tests\` the simulation harness (fake DISM and SFC for Claude's Linux workspace)
  - `Logs\` one dated folder per run, kept 90 days
  - `Archive\` earlier versions
- The Claude Project holds reference copies of the script and documents. The folder on the PC is the master; refresh the project copies at each release.

## Reliability requirements already met (keep them)

- Test "No component store corruption detected" before any looser corruption pattern (regression: version 1 era false positive).
- Check DISM's exit code (0, or 3010 = success with restart needed) before trusting its text.
- Judge SFC by its message (its exit codes are undocumented); record any unusual exit code as a note.
- Capture native output as raw bytes and detect the encoding: SFC writes UTF-16LE (regression: version 1 never recognised SFC results).
- Confirm a DISM repair with another /ScanHealth, and an SFC repair with another /verifyonly.
- One run at a time (Windows mutex; a second run exits with code 10).
- Time limits; stop the whole process tree on time-out; keep the output captured so far.
- Never restart Windows. Skip the checks (code 6) only for restart signals that affect servicing; never use PendingFileRenameOperations.
- Fail visibly: the verdict starts as "failed"; an unrecognised result is code 5, never 0.
- Always report: Summary.txt, Result.json, Event Viewer entry and lock release sit in a `finally` block.
- Record the script version and the PowerShell version, edition and path in every report.

## Technical rules learned the hard way

- Never wrap a .NET `List[object]` in `@()`; use `.ToArray()` ("Argument types do not match", in 5.1 and 7).
- Convert exit codes to hexadecimal through `[BitConverter]`, never `[uint32]` (negative error codes crash it).
- Run native tools through `System.Diagnostics.Process`, not `& tool 2>&1`, and read their output in the background so their buffers cannot fill and freeze them.
- Compare versions as `[version]`, not as text.
- PowerShell variable names ignore case: `$B` and `$b` are the same variable.
- Keep the script file plain ASCII while it still supports Windows PowerShell 5.1 (5.1 reads BOM-less files as ANSI). Once 5.1 support is dropped, save it as UTF-8.

## How we work

1. Read the documents above and the whole script first; inspect the latest Logs if the change concerns runtime behaviour.
2. Explain significant behavioural or architectural changes before making them.
3. Make focused, reviewable changes; do not rewrite working code for style.
4. Run the checks in docs/TESTING.md. Distinguish static checks, unit tests on sample data, simulations, integration tests with safe native commands, and real DISM/SFC runs on Benn's PC. Never call something "tested on Windows" unless it ran there.
5. For each bug: record symptom, root cause, fix, how it was tested, whether a regression test was added, and whether a real Windows run is still needed (docs/PROJECT-HISTORY.md).
6. Never paste the script into a chat box (pasting turns `<#` into `&lt;#` and web addresses into HTML). Attach the file, or work from the connected folder.
7. One editor at a time. A version from another assistant is a draft until reviewed and tested.
8. For each material change, bump `$ScriptVersion` and update docs/CHANGELOG.md.
9. Explain PowerShell and Windows concepts in plain English; Benn is learning. British English, active voice.
10. Teach through the real work, as the learning section of the project instructions describes. Make one coherent change per stage, end each stage at a safe stopping point with a resume note, and offer one recommended default rather than a long list of options. Update docs/LEARNING-LOG.md at the end of each stage.
