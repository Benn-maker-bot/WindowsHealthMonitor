# Windows Health Monitor: plan for version 2.5

Status: **in progress.** Stage 0 (Git) done on 29 October 2026; stages 1 to 6 not started.

## Where we are now (resume note)

- **Current version:** 2.4.0, in `C:\Scripts\WindowsHealthMonitor\WindowsHealthMonitor.ps1`.
- **Last real run:** 29 October 2026 at 11:31, in PowerShell 7.6.9. Healthy, result code 0, 2 min 2 s. This is the **known-good baseline**: every later change is compared against it.
- **Git:** in use since 29 October 2026. The baseline commit is `4239d2b`, version 2.4.0 exactly as it ran at 11:31.
- **Next action:** stage 1, making the script testable. It needs no decisions. D1 to D4 are needed only from stage 4 onwards.

## At a glance

Version 2.5 makes the script **testable, tested, schedulable and PowerShell 7-only**. What DISM and SFC do, and the result codes, stay exactly as in 2.4.0.

The work is split into seven small stages. Each one makes one coherent change and is tested. Each one ends at a safe stopping point with:

1. all tests passing;
2. a version label in the script (2.5.0-dev.1, 2.5.0-dev.2 and so on), so every report shows which code produced it;
3. a line in CHANGELOG.md;
4. an entry in LEARNING-LOG.md;
5. a resume note in the chat;
6. a Git commit, if decision D0 is agreed.

| Stage | What changes | What you will learn | Needs a decision |
|---|---|---|---|
| 0. Safety net | A local Git repository for the project folder | Version control, commits, undoing a change | D0 |
| 1. Make the script testable | The main section becomes a function; no change in behaviour | Functions, dot-sourcing, scope | No |
| 2. Pester tests | A test file covering every function and every past bug | Pester, mocks, regression tests | No |
| 3. Tests with real Windows programs | Safe tests using cmd.exe and ping.exe on your PC | Processes, exit codes, text encodings | No |
| 4. PowerShell 7 only | Code that exists only for Windows PowerShell 5.1 is removed | Differences between PowerShell 5.1 and 7 | D4 |
| 5. Scheduled task | A script that creates the task, and a document describing every setting | Task Scheduler, accounts, sessions | D1, D2, D3 |
| 6. Release 2.5.0 | Documents, guide, real runs on your PC | Release testing | No |

## How this fits with a change of AI tool

Benn is considering moving from Claude Code to another AI coding tool (docs/AI-MIGRATION.md). The two plans fit together:

1. Stage 0 (Git) and stages 1 and 2 (testability and the Pester tests) come **before** any trial of a new tool, because the tests become the referee.
2. The new tool's qualification test, harmless editing trial and parallel review period come after stage 2.
3. Stage 3 (the Windows integration tests) and a supervised real run then follow.

Never change tool and redesign DISM or SFC behaviour at the same time.

## Decisions, with recommended defaults

Each decision has one recommended default. Say "accept the defaults" to take them all, or name the one you want to change.

**D0. Git (stage 0).** **Decided: yes (29 October 2026).** Start a local Git repository in `C:\Scripts\WindowsHealthMonitor`, with `Logs\` excluded, and no GitHub yet. Git records every change, so any stage can be undone. It is also one of your learning goals. If `git --version` fails, install Git with `winget install --id Git.Git -e --source winget`.

**D1. How the scheduled task gets PowerShell 7 (stage 5).** *Recommended: install PowerShell 7 for the whole computer, and run the task as SYSTEM.*
- **Why:** your current PowerShell 7 comes from the Microsoft Store and is installed for your account only, so a task running as SYSTEM probably cannot start it.
- **How:** `winget install --id Microsoft.PowerShell -e --source winget` installs it in `C:\Program Files\PowerShell\7`, alongside the Store copy.
- **Benefits:** the task runs whether or not you are signed in, and no password is stored.
- **Cost:** two copies of PowerShell 7. WinGet (`winget upgrade Microsoft.PowerShell`) or Microsoft Update keeps the new one up to date.
- **Alternative:** keep only the Store copy and run the task as you, "only when user is logged on". Nothing new to install, but the check runs only while you are signed in.

**D2. When it runs (stage 5).** *Recommended: weekly, Sunday at 12:00*, or another time your PC is usually on. If that time is missed, the task runs as soon as possible afterwards.

**D3. How you hear about problems (stage 5).** *Recommended: a short message when you next sign in, but only after a run that needs attention (any result code other than 0).*
- **Why:** a task running as SYSTEM has no visible desktop, so its pop-up cannot appear. Without this, you would only find out by checking Event Viewer or the reports, and telling you about important results is one of the project's main purposes.
- **How:** a small, separate sign-in task reads the newest Result.json. It does not change the health check itself.

**D4. Drop Windows PowerShell 5.1 support (stage 4).** *Recommended: yes*, in line with your project instructions.
- The script would require PowerShell 7.6, the current long-term-support release. 7.4 is not enough: its support ends on 10 November 2026.
- **What can go:**
  - the taskkill fallback, since `$process.Kill($true)` stops the whole process tree;
  - the Sysnative branch for 32-bit hosts, replaced by a clear refusal;
  - the plain-ASCII rule for the script file.
- **Cost:** if PowerShell 7 were ever missing, the task would fail to start instead of falling back. Task Scheduler's Last Run Result would show this.

## Stage details

### Stage 0. Safety net: Git (done, 29 October 2026)

Done: `git init -b main`; `.gitignore` leaves out `Logs\`; `.gitattributes` keeps every text file's LF line endings; baseline commit `4239d2b` holds 21 files. Benn ran every step himself.

- **Steps:**
  1. `git init` in the project folder.
  2. A `.gitignore` that leaves out `Logs\`.
  3. A first commit of version 2.4.0, exactly as it is today.
- **You will learn:** what a repository and a commit are, how to write a useful commit message, and how to see or undo a change (`git log`, `git diff`, `git restore`).
- **Test:** `git status` shows a clean working tree.

### Stage 1. Make the script testable (no behaviour change)

- **Changes:**
  - **The main section becomes a function,** `Invoke-WindowsHealthMonitor`. It runs only when the script is started, not when a test loads it:
    `if ($MyInvocation.InvocationName -ne '.') { Invoke-WindowsHealthMonitor; exit $script:Outcome.Code }`
    Tests then load the functions with `. .\WindowsHealthMonitor.ps1`, which is called dot-sourcing, without running DISM or SFC.
  - **The administrator check moves into the code.** `#requires -RunAsAdministrator` is replaced by a check inside `Invoke-WindowsHealthMonitor`, so tests can load the script without administrator rights. A run without administrator rights still stops at once with result code 1 and a clear message.
  - **A new function, `Get-RestoreHealthArgument`,** builds the `/RestoreHealth` arguments (including `/Source:` and `/LimitAccess`), so they can be tested on their own.
  - **Result.json gains `SchemaVersion = 1`,** so later changes to its layout can be detected.
- **You will learn:** what dot-sourcing does, what `$MyInvocation` tells a script about how it was started, and why separating "define" from "run" makes code testable.
- **Tests:**
  - static checks;
  - all 12 simulated scenarios give the same result codes as 2.4.0;
  - one real healthy run on your PC.

### Stage 2. Pester unit and regression tests

- **The test file:** `Tests\WindowsHealthMonitor.Tests.ps1`. Pester is PowerShell's standard testing tool.
- **Install Pester once on your PC,** in PowerShell 7: `Install-PSResource -Name Pester -Scope CurrentUser`. Stage 2 will confirm the exact command, because Windows also contains a very old Pester 3.4.
- **Run the tests with:** `Invoke-Pester C:\Scripts\WindowsHealthMonitor\Tests -Output Detailed`

| Area | Tests | Regression test for |
|---|---|---|
| Get-DismScanState | Healthy, repairable, not repairable, unknown; "No component store corruption detected" is Healthy | DISM false positive |
| Get-SfcState | All seven states, using real SFC wording | |
| ConvertFrom-ToolOutput | UTF-16LE without BOM (SFC), UTF-8 and UTF-16 with BOM, OEM text; progress lines removed; blank lines collapsed | SFC decoding; 113 blank lines |
| Get-ExitCodeHex / Get-DismHint | 0, 3010, 87, negative codes such as 0x800F081F; a success code gives "review" advice | uint32 crash; meaningless 0x00000000 advice |
| Test-DismExitCode | 0 and 3010 succeed (3010 sets RestartRecommended); others fail | |
| Export-CbsSrLine | Only lines from this run are copied, from a sample CBS.log | Old CBS lines |
| Get-PendingRestartReason | Each signal blocks; a stale pending.xml only adds a note; PendingFileRenameOperations ignored (using mocks) | Copilot's skip-every-run |
| Remove-OldRunFolder | Deletes only dated folders past the limit; leaves other folders alone | |
| Save-ResultFile | Valid JSON with every field, including SchemaVersion; lists become arrays | `@()` "Argument types do not match" |
| Get-RestoreHealthArgument | No source; a source path with spaces is quoted; `/LimitAccess` only with a source | |
| Invoke-Tool | A program that writes to standard error does not stop the script, even with `$ErrorActionPreference = 'Stop'`; exit code, duration and output kept | Native stderr and ErrorActionPreference |
| Format-Duration / Format-DriveSpace | Boundary values | |
| **Whole runs** | `Invoke-Tool` is replaced by a mock that returns recorded DISM and SFC output for each scenario: healthy, both repairs, each failure, time-out, unrecognised. The test checks the result code, the State fields and the report files | Repairs trusted without confirmation; SFC skipped when DISM was healthy |

- **The Linux-only simulation:** the whole-run tests run on any computer, so they replace it. The bash files in `Tests\` move to `Archive\`.
- **Optional exercise:** write one test yourself, for `Format-Duration`, with hints first.

### Stage 3. Integration tests with safe Windows programs (on your PC)

These use real Windows processes, but nothing that touches the system. They run without administrator rights.

| Program run | What it tests |
|---|---|
| `cmd.exe /u /c echo ...` | Genuine UTF-16LE output, like SFC's, is decoded |
| `cmd.exe /c exit 3010` | Exit codes are captured |
| `cmd.exe /c ping -n 120 127.0.0.1` | A parent with a child process: the time limit stops both, and the output so far is kept |
| A command that writes to standard error | Error output is captured, not thrown |

- **You will learn:** process trees, standard output and error, and how exit codes travel from one program to another.

### Stage 4. PowerShell 7 only (if D4 is agreed)

- **Changes:**
  - `#requires -Version 7.6`;
  - `$process.Kill($true)` only;
  - a clear refusal on a 32-bit host instead of the Sysnative branch;
  - the plain-ASCII rule lifted (the file is saved as UTF-8).
- **The rule:** keep only changes that make the script clearer, not newer syntax for its own sake.
- **Tests:** every test from stages 2 and 3, in PowerShell 7.
- **You will learn:** the main differences between Windows PowerShell 5.1 and PowerShell 7, and how to check a version requirement.

### Stage 5. The scheduled task

- **New files:**
  - `Register-WindowsHealthMonitorTask.ps1` creates or updates the task. It is kept separate from the health monitor.
  - `docs\SCHEDULED-TASK.md` explains every setting.
  - If D3 is agreed, `Show-WindowsHealthMonitorNotice.ps1` is the small sign-in task.
- **Proposed settings:**

| Tab | Setting | Why |
|---|---|---|
| General | Name "Windows Health Monitor"; run as SYSTEM (D1); **Run with highest privileges**; Configure for "Windows 10" (the label Task Scheduler also uses for Windows 11) | DISM and SFC need administrator rights |
| Triggers | Weekly (D2) | |
| Actions | Program: `C:\Program Files\PowerShell\7\pwsh.exe`; Arguments: `-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Scripts\WindowsHealthMonitor\WindowsHealthMonitor.ps1"`; Start in: `C:\Scripts\WindowsHealthMonitor` | A fixed path, no profile, no prompts |
| Conditions | Idle conditions **off**: neither "Start only if idle" nor "Stop if the computer ceases to be idle". AC-power condition off (desktop PC). No network condition. Do not wake the computer | Stopping when you touch the mouse could interrupt a repair |
| Settings | Allow run on demand; **run as soon as possible after a missed start**; stop if running longer than **12 hours**; force stop if it does not end; if already running, **do not start a new instance** | 12 hours is a backstop: the script's own time limits add up to at most 9 hours |

- **Priority:** Task Scheduler runs tasks at below-normal priority by default, which stops DISM and SFC slowing the PC while you use it.
- **Result:** "Last Run Result" shows the script's result code (0x0 = healthy).
- **You will learn:** how Task Scheduler starts programs, what SYSTEM and session 0 are, and how to use the ScheduledTasks commands (`Register-ScheduledTask` and related commands).

### Stage 6. Release 2.5.0

1. Update CHANGELOG, PROJECT-HISTORY, TESTING, PROJECT.md, AGENTS.md, the guide and the learning log.
2. Set the version to 2.5.0.
3. On your PC:
   - run the Pester tests;
   - do one manual elevated run in PowerShell 7;
   - start the task with Task Scheduler's **Run** button;
   - check Last Run Result, Summary.txt, Result.json, the report files and Event Viewer.

## What will still not be tested on Windows

The real repair paths (DISM /RestoreHealth, and SFC /scannow finding damage) can only be tested for real when Windows actually needs a repair. Until then, they are covered by the whole-run Pester tests and the stage 3 integration tests. Do not damage system files to test them.
