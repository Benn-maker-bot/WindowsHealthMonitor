# Windows Health Monitor: project rules

This file states what is true about the project, whichever person or tool works on it. How an AI assistant must behave is in AGENTS.md.

**Authority.** Benn's requirements are set out in full in the project instructions of his Claude Project "System Health Monitor". This file restates them so that any tool can follow them. If the two disagree, ask Benn, then correct whichever is wrong.

## Contents

1. Purpose
2. Environment
3. Where the files live
4. How a run works
5. Result codes
6. Reliability rules (protected behaviour)
7. Technical rules learned the hard way
8. Safety
9. Code quality
10. Testing
11. Versioning and documents

## 1. Purpose

WindowsHealthMonitor.ps1 is a dependable Windows 11 health monitor. It:

- checks the Windows component store with DISM, and repairs it when there is genuine corruption;
- checks the protected system files with SFC, and repairs them when needed;
- confirms every repair with a second scan;
- records what happened, readable both by people and by programs;
- tells Benn about important results;
- runs unattended from Task Scheduler.

The project has a second, equally important purpose: it is where Benn learns PowerShell 7 and professional software development. See AGENTS.md, section 6.

Avoid feature creep. Health monitoring and supported repair are the core purpose; this is not a general Windows tweaking tool.

## 2. Environment

- **Computer:** Windows 11 Pro 26H2 (build 26300), computer name NEW. Owner: Benn.
- **Rights:** runs with administrator rights, either in an elevated window or as a scheduled task with "Run with highest privileges".
- **Target runtime:** the latest stable PowerShell 7 (`pwsh.exe`). Currently 7.6.9, from the Microsoft Store.
- **Windows PowerShell 5.1** is built into Windows. Compatibility with it is **not required**. Version 2.4.0 still runs in it, but a better PowerShell 7 design takes priority.
- **Scheduled task:** runs `pwsh.exe`. Open question: the Store copy of PowerShell 7 is installed for Benn's account only, so a task running as SYSTEM may not be able to start it (docs/PLAN-2.5.md, decision D1).
- **PowerShell updates:** the script must **not** install, update or switch PowerShell. That is a separate job (decided 29 October 2026).

## 3. Where the files live

The **master copy** is `C:\Scripts\WindowsHealthMonitor\` on Benn's PC (not OneDrive).

| Path | Contents |
|---|---|
| `WindowsHealthMonitor.ps1` | The script |
| `WindowsHealthMonitor-Guide.docx` | The illustrated learning guide |
| `PROJECT.md` | This file |
| `AGENTS.md` | The operating contract for AI assistants |
| `CLAUDE.md` | A short pointer to the two files above, read automatically by Claude Code |
| `docs\` | PROJECT-HISTORY, TESTING, CHANGELOG, PLAN-2.5, AI-MIGRATION, LEARNING-LOG |
| `Tests\` | Test files (currently a simulation harness that runs only in Claude's Linux workspace) |
| `Logs\` | One dated folder per run, kept 90 days |
| `Archive\` | Earlier versions and superseded documents |

Copies kept elsewhere, such as in a Claude Project, are reference copies only. Refresh them at each release.

## 4. How a run works

1. **Pre-flight:**
   - take the single-run lock;
   - create the report folder;
   - record the Windows version and the PowerShell version, edition and path;
   - remove reports older than 90 days.
2. **Restart check:** skip the checks (result code 6) if Windows has servicing work waiting for a restart.
3. **Free space:** read the free space on the Windows drive, and warn below 10 GB.
4. **DISM /ScanHealth:** classifies the component store as Healthy, Repairable, NotRepairable or Unknown.
5. **If Repairable:** run DISM /RestoreHealth, optionally from `-RepairSource` with `/LimitAccess`. Then run /ScanHealth again; the repair counts only if this second scan finds the store healthy.
6. **SFC:**
   - by default, `/verifyonly` first, which changes nothing;
   - `/scannow` only if violations are found, straight after a DISM repair, or with `-SfcMode AlwaysRepair`;
   - after any SFC repair, `/verifyonly` again to confirm it.
7. **Always,** in a `finally` block:
   - write Summary.txt and Result.json;
   - write an Event Viewer entry (Application log, source WindowsHealthMonitor, event ID 1000 + result code);
   - release the lock;
   - show a 60-second pop-up if someone can see it;
   - exit with the result code.

## 5. Result codes

Keep these stable. Task Scheduler shows the code as "Last Run Result".

| Code | Meaning |
|---|---|
| 0 | Healthy: nothing needed repairing |
| 1 | The script itself failed |
| 2 | Repaired: corruption was found, repaired and confirmed. A restart is recommended |
| 3 | The component store could not be repaired automatically |
| 4 | SFC could not repair every file, or could not run |
| 5 | DISM failed, or a tool's result was not recognised |
| 6 | A restart is pending; the checks were skipped |
| 7 | A tool exceeded its time limit and was stopped |
| 10 | Another run was already in progress |

Never use code 0 for an unrecognised or unconfirmed result, even if a tool returned 0.

## 6. Reliability rules (protected behaviour)

Each rule exists because of a real bug, described in docs/PROJECT-HISTORY.md. Do not "simplify" any of them without understanding that history, and without tests that prove the protection still works.

1. **DISM false positive.** Test "No component store corruption detected" before any looser corruption pattern.
2. **DISM exit codes.** Check DISM's exit code (0, or 3010 = success with restart needed) before trusting its text.
3. **SFC encoding.** Capture native output as raw bytes and detect the encoding: SFC writes UTF-16LE.
4. **SFC exit codes.** Judge SFC by its message, because its exit codes are undocumented, but record any unusual exit code as a note.
5. **Every run gets an SFC check.** SFC checks the system files even when DISM finds the store healthy.
6. **Repairs are confirmed.** Confirm a DISM repair with another /ScanHealth, and an SFC repair with another /verifyonly.
7. **Current-run CBS lines only.** SFC-CBS-Details.txt holds only the CBS.log [SR] lines written during this run.
8. **Native error output.** A line on a tool's error stream must never become a terminating PowerShell error. Run tools through `System.Diagnostics.Process`, not `& tool 2>&1`.
9. **One run at a time.** A Windows mutex enforces this; a second run exits with code 10.
10. **Time limits.** Stop the whole process tree on time-out, and keep the output captured so far.
11. **Restart signals.** Skip the checks only for signals that affect servicing; never use PendingFileRenameOperations. A pending.xml older than the last restart adds a note instead of blocking.
12. **Fail visibly.** The verdict starts as "failed"; an unrecognised result is code 5.
13. **Always report.** The reports, Event Viewer entry and lock release must happen even after an unexpected error.
14. **Identify every report.** Every report records the script version and the PowerShell version, edition and path.

## 7. Technical rules learned the hard way

- **`@()` and .NET lists.** Never wrap a .NET `List[object]` in `@()`; use `.ToArray()`. Otherwise PowerShell throws "Argument types do not match", in both 5.1 and 7.
- **Exit codes in hexadecimal.** Convert them through `[BitConverter]`, never `[uint32]`, because negative error codes crash `[uint32]`.
- **Tool output buffers.** Read a tool's output in the background while it runs, so its output buffer cannot fill and freeze it.
- **Version numbers.** Compare versions as `[version]`, not as text.
- **Variable names.** PowerShell variable names ignore case: `$B` and `$b` are the same variable.
- **File encoding.** Keep the script file plain ASCII while it still supports Windows PowerShell 5.1, which reads files without a byte-order mark as ANSI. Once 5.1 support is dropped, save it as UTF-8.
- **Pasting.** Never move the script by pasting it into a chat box. Pasting turns `<#` into `&lt;#` and web addresses into HTML. Attach the file, or work on it in its folder.

## 8. Safety

Never:

- restart Windows automatically;
- delete or alter Windows servicing data to make a check pass;
- replace protected system files by hand when DISM or SFC can repair them;
- hide an error, or turn an unknown state into "healthy";
- report a repair as confirmed when only the repair command succeeded;
- delete diagnostic evidence because it is inconvenient;
- damage system files to test the repair paths;
- make undocumented system changes unrelated to health monitoring.

Before any potentially disruptive change, explain four things: what will change, why administrator rights are needed, the risks, and how the result will be checked.

## 9. Code quality

**Prefer:**

- focused functions;
- clear data flow and descriptive names;
- structured objects rather than loose strings;
- one central place for running tools and one for classifying results;
- explicit configuration;
- comments that explain why, not just what;
- separate detection, repair, confirmation, reporting and notification;
- functions that can be tested on their own.

**Avoid:**

- very large functions;
- duplicated parsing logic;
- loose text matching without an explicit order of precedence;
- hidden side effects;
- catch blocks that swallow failures;
- reporting success merely because no error occurred;
- unnecessary dependencies.

Do not rewrite working code for style. Prefer small, reviewable changes.

## 10. Testing

Four levels, in order. Only level 4 counts as "tested on Windows". Details are in docs/TESTING.md.

1. **Static checks:** the parser and PSScriptAnalyzer.
2. **Unit tests and simulations:** sample or simulated data. Pester is planned for version 2.5.
3. **Integration tests:** harmless real Windows programs, such as cmd.exe and ping.exe. Planned for version 2.5.
4. **Real DISM and SFC runs** on Benn's PC.

The **known-good baseline** is version 2.4.0's run on 29 October 2026 at 11:31: PowerShell 7.6.9, healthy, result code 0.

## 11. Versioning and documents

- **Version numbers:** for every material change, bump `$ScriptVersion` (pre-release labels such as 2.5.0-dev.1 during a stage) and add a line to docs/CHANGELOG.md.
- **Keeping documents in step:** when behaviour changes, update the relevant documents in the same piece of work. The guide and the learning log must not drift out of step with the script.
- **Recording bugs:** for each bug, record in docs/PROJECT-HISTORY.md:
  - the symptom and the root cause;
  - the fix, and how it was tested;
  - whether a regression test was added;
  - whether a real Windows run is still needed.
