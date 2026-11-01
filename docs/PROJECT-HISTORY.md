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

### Git (29 October 2026)

- The project folder became a local Git repository, branch `main`. The baseline commit `4239d2b` holds version 2.4.0 exactly as it ran at 11:31, with all the documents: 21 files.
- `.gitignore` leaves out `Logs\`. `.gitattributes` keeps the LF line endings that every text file already used, so Git never converts them. The bash test files need LF, and LF also avoids confusing warnings.
- Benn ran each step himself; Claude rehearsed them first on a temporary copy, then checked the result.

### Version 2.5.0-dev.1: making the script testable (29 October 2026)

- **The problem:** until 2.4.0 the main section sat loose at the end of the file, so loading the script always started a health check, and `#requires -RunAsAdministrator` stopped it loading at all in a normal window. No function could be tested on its own.
- **The change:** the main section became `Invoke-WindowsHealthMonitor`, and the last lines call it unless `$MyInvocation.InvocationName` is `.` (dot-sourcing). The administrator check moved into `Test-IsAdministrator`. The DISM repair options moved into `Get-RestoreHealthArgument`. Result.json gained `SchemaVersion = 1`.
- **Why `return`, not `exit`, inside the function:** `exit` would also close a test session that called the function. The busy branch (code 10) now stores its result in `$script:Outcome` like every other path.
- **Why no reports when administrator rights are missing:** 2.4.0 wrote none either (PowerShell refused to start the script), and creating the report folder or the event source may itself need the missing rights.
- **A test that could not fail (found and fixed the same day):** the first version of `Tests\Test-DotSource.ps1` checked that the verdict was still code 1. On purpose, Claude broke the guard on a copy, and the test still passed: in a window without administrator rights, the refusal also sets code 1. The test now checks the starting message instead, and fails as it should on the broken copy. *Lesson: prove that a test can fail before trusting it when it passes.*
- **Observed in PowerShell 7.6.9 (Claude's Linux workspace):** `exit` inside a dot-sourced script returns to the script that dot-sourced it; it does not close PowerShell.
- **Tested:** static checks; the 12 simulated scenarios; `Test-DotSource.ps1`, also on Benn's PC; a real run on Benn's PC at 13:19 (healthy, code 0), which matched the 11:31 baseline.

### Pasting problems

- Pasting the script into a chat box converts `<#` to `&lt;#`, `>` to `&gt;` and web addresses into HTML links. Several "corruption" reports came from pasted copies; the files themselves were clean. Never move the script by pasting.

### VS Code commit failed without an accepted message (30 October 2026)

- **Symptom:** the Source Control view showed activity for several minutes without a new commit.
- **Cause:** `git commit --quiet` invoked VS Code's `git-editor.sh` helper without an accepted message. The Git output recorded a 566,842 ms run followed by "Please supply the message using either -m or -F option." The author name and email were configured; this was not a repository lock or missing identity.
- **Resolution:** the failed operation created no commit. The 33 staged paths remained in the index, and no index lock remained.
- **Verification:** checked the Git output, `git status`, staged-path count, `HEAD`, process list and index-lock state.
- **Prevention:** enter the message in the Source Control message box before selecting Commit; review staged paths, particularly if VS Code staged changes automatically. See `docs/SOURCE-CONTROL-GUIDE.md`.

## Design decisions

- DISM first, then SFC: repair the master copies before using them to repair the working copies.
- SFC: read-only /verifyonly first; /scannow only when needed, or straight after a DISM repair.
- Task Scheduler with highest privileges; never restart Windows automatically.
- Keep PowerShell installation and updating out of this script (version 2.4.0).
- Target the latest stable PowerShell 7 and schedule with `pwsh.exe` (project instructions, 29 October 2026). Windows PowerShell 5.1 compatibility is no longer required; 2.4.0 still happens to run in it.
- One run at a time; reports kept 90 days; optional DISM repair source (-RepairSource).
- The project's rules are tool-neutral (PROJECT.md, AGENTS.md), so that no single AI tool is required; the tests and real Windows runs are the referee.
- Every repair confirmed; the verdict starts as "failed"; the script file stays plain ASCII while it still supports 5.1.
- Loading is not running: dot-sourcing the script defines everything and runs nothing, so tests can call functions one at a time (2.5.0-dev.1).

## Known environment

- Windows 11 Pro 26H2, build 26300.9711; computer name NEW; 1.82 TB system drive.
- PowerShell 7.6.9 (Microsoft Store), Windows PowerShell 5.1.26100.9711.
- Script: `C:\Scripts\WindowsHealthMonitor\WindowsHealthMonitor.ps1` (master copy, since 29 October 2026).

## Open items

- Build the rest of version 2.5 (docs/PLAN-2.5.md): testability (done: 2.5.0-dev.1), Pester tests, Windows integration tests, PowerShell 7 only, scheduled task, release. Decide D1 to D4 before stage 4.
- A private GitHub repository can follow the local Git repository later, if wanted.
- Change of AI tool: follow docs/AI-MIGRATION.md; no replacement tool chosen yet.
- The repair paths have been simulated but not yet run on Windows; they will be tested for real the first time Windows needs a repair.
