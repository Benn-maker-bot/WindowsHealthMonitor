# Windows Health Monitor: project history

## Original goal

Automatically check Windows for component-store corruption using DISM, repair it when necessary, run SFC, save logs and notify the user.

## Bugs found, and what each one taught us

### Version 1 (Benn's original script, 200 lines)

- **SFC results could never be recognised.** sfc.exe writes UTF-16LE when its output is captured. Version 1 decoded it as one byte per letter, so every letter was followed by a NUL character and no text match could succeed. Every SFC result fell through to "not recognised", which then reported SFC's own exit code (usually 0), so the run looked successful. *Lesson: capture native output as bytes and detect the encoding.*
- **SFC ran only after DISM found corruption.** DISM checks the component store; SFC checks the working copies of system files. Those are separate problems. *Lesson: run a read-only SFC check every time.*
- **Repairs were trusted on their exit codes.** *Lesson: confirm every repair with a second scan.*
- **`& tool 2>&1` with `$ErrorActionPreference = 'Stop'`.** In Windows PowerShell 5.1 any line on the error stream became a terminating error, so DISM could be reported as failed when it had worked.
- **CBS.log export took every [SR] line ever written**, mixing weeks of old results into each report.
- **32-bit hosts.** A 32-bit PowerShell on 64-bit Windows sees System32 redirected to SysWOW64, and 32-bit DISM and SFC cannot service 64-bit Windows. Fixed by using Sysnative when needed.
- **False DISM corruption detection (guarded against in version 1, kept since).** A loose test for "component store corruption detected" also matches "No component store corruption detected". The healthy phrase must be tested first.

### Copilot's 2.0 (reviewed 28 October 2026, not adopted)

- **DISM error codes crashed the script.** Codes such as 0x800F081F reach PowerShell as negative numbers, and `[uint32]` cannot convert them, so the script crashed and deleted its own output in exactly the case where it was needed. *Lesson: test the failure paths.*
- **It would probably skip every run.** It treated the PendingFileRenameOperations registry value as a pending restart; many PCs always have it.
- Its good ideas (before-and-after state fields, BOM detection, restart tracking, the rename check) went into 2.1.0.

### Versions 2.1.x (29 October 2026, first real runs on Benn's PC)

- **"Result.json could not be written: Argument types do not match".** Wrapping a .NET `List[object]` in `@()` triggers a PowerShell bug, in both 5.1 and 7. Fixed with `.ToArray()`. *Lesson: test every step, including the last one.*
- **113 blank lines in the DISM report**, left by progress-bar updates. Fixed by collapsing runs of blank lines.
- **Durations hid the seconds** ("1 min" was 1 min 2 s). Now shown as "1 min 2 s".
- **The free-space line was unclear** ("Free space on C:: 1355.7 GB"). Now shows size, percentage and a verdict.
- **The version number was not bumped** after two fixes, so logs could not show which code produced them.

### Version 2.2.0 and the PowerShell question

- The command `powershell.exe -File ...` always starts Windows PowerShell 5.1, even from a PowerShell 7 window. That is why early runs reported 5.1 while Benn's terminal was 7.6.9.
- 2.2.0 added a hand-over to PowerShell 7 and a PowerShell 7 installer/updater (download, SHA-256 and signature checks, silent MSI install).
- Reviewed again on 29 October 2026 and **removed in 2.4.0**: it nearly doubled the script, added internet and installer failure points unrelated to DISM and SFC, broke the rule to keep PowerShell updating separate, and would never have installed anything on Benn's PC (Microsoft Store installation).

### Change of direction on 29 October 2026

- Benn's project instructions make the latest stable PowerShell 7 the target and `pwsh.exe` the scheduled-task runtime, and say not to keep Windows PowerShell 5.1 compatibility at the expense of a better PowerShell 7 design. The documents written earlier that day required 5.1 compatibility and `powershell.exe` scheduling; they were corrected the same day.

### Tool-neutral documents (29 October 2026)

- Benn is considering moving from Claude Code to another AI coding tool, on Copilot's advice: gradually, with Git and tests first (docs/AI-MIGRATION.md).
- The project's rules moved into tool-neutral files: PROJECT.md (the rules) and AGENTS.md (how any AI must work). CLAUDE.md now only points to them.
- 2.4.0's run at 11:31 in PowerShell 7.6.9 (healthy, code 0) became the known-good baseline.

### Pasting problems

- Pasting the script into a chat box converts `<#` to `&lt;#`, `>` to `&gt;` and web addresses into HTML links. Several "corruption" reports came from pasted copies; the files themselves were clean. Never move the script by pasting.

## Design decisions

- DISM first, then SFC: repair the master copies before using them to repair the working copies.
- SFC: read-only /verifyonly first; /scannow only when needed, or straight after a DISM repair.
- Task Scheduler with highest privileges; never restart Windows automatically.
- Keep PowerShell installation and updating out of this script (version 2.4.0).
- Target the latest stable PowerShell 7 and schedule with `pwsh.exe` (project instructions, 29 October 2026). Windows PowerShell 5.1 compatibility is no longer required; 2.4.0 still happens to run in it.
- One run at a time; reports kept 90 days; optional DISM repair source (-RepairSource).
- The project's rules are tool-neutral (PROJECT.md, AGENTS.md), so that no single AI tool is required; the tests and real Windows runs are the referee.
- Every repair confirmed; the verdict starts as "failed"; the script file stays plain ASCII while it still supports 5.1.

## Known environment

- Windows 11 Pro 26H2, build 26300.9711; computer name NEW; 1.82 TB system drive.
- PowerShell 7.6.9 (Microsoft Store), Windows PowerShell 5.1.26100.9711.
- Script: `C:\Scripts\WindowsHealthMonitor\WindowsHealthMonitor.ps1` (master copy, since 29 October 2026).

## Open items

- Decide D0 to D4 in docs/PLAN-2.5.md (each has a recommended default), then build version 2.5 in its seven stages: Git, testability, Pester tests, Windows integration tests, PowerShell 7 only, scheduled task, release.
- Git: start with a local repository (plan stage 0); a private GitHub repository can follow later if wanted. Git also comes first in the change-of-tool plan.
- Change of AI tool: follow docs/AI-MIGRATION.md; no replacement tool chosen yet.
- The repair paths have been simulated but not yet run on Windows; they will be tested for real the first time Windows needs a repair.
