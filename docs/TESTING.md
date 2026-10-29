# Windows Health Monitor: testing

The project instructions name four levels of testing. Every release goes through each level that exists, in order. Only level 4 counts as "tested on Windows".

| Level | What it is | Status |
|---|---|---|
| 1. Static checks | Parser, PSScriptAnalyzer | In use |
| 2. Unit tests and simulations | Sample or simulated data; nothing real runs | Simulation in use; Pester planned (version 2.5, stage 2) |
| 3. Integration tests | Real but harmless Windows programs (cmd.exe, ping.exe) | Planned (version 2.5, stage 3) |
| 4. Real DISM and SFC runs | The script on Benn's PC | In use |

## Level 1: static checks (any computer)

Run in PowerShell 7. Parse errors must be zero. The 5.1-syntax and non-ASCII counts only matter while the script still supports Windows PowerShell 5.1 (not required since 29 October 2026).

```powershell
$path = 'C:\Scripts\WindowsHealthMonitor\WindowsHealthMonitor.ps1'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
"Parse errors: $($errors.Count)"

# Syntax that Windows PowerShell 5.1 cannot read (ternary, ??, &&, ?.)
$ps7Only = $ast.FindAll({ param($n)
    $n -is [System.Management.Automation.Language.TernaryExpressionAst] -or
    $n -is [System.Management.Automation.Language.PipelineChainAst] -or
    ($n -is [System.Management.Automation.Language.BinaryExpressionAst] -and $n.Operator -eq 'QuestionQuestion') -or
    ($n -is [System.Management.Automation.Language.MemberExpressionAst] -and $n.NullConditional) }, $true)
"PowerShell 7-only syntax: $(@($ps7Only).Count)"

# Non-ASCII characters (Windows PowerShell 5.1 reads BOM-less files as ANSI)
"Non-ASCII lines: $(@(Select-String -Path $path -Pattern '[^\x00-\x7F]').Count)"
```

Also run PSScriptAnalyzer: `Invoke-ScriptAnalyzer -Path $path` (and, while 5.1 is still supported, the PSUseCompatibleSyntax rule targeting 5.1 and 7.0). Write-Host, ShouldProcess and unused-parameter warnings are expected.

## Level 2: unit tests and simulations with sample data

### 2a. Simulated runs (Claude's Linux workspace)

The real script runs end to end in PowerShell 7 on Linux, against **fake** DISM.exe and sfc.exe programs. They print the same messages and exit codes as the real tools, including SFC's UTF-16LE output, DISM's progress bars and CBS.log [SR] lines. This exercises every decision in the script, but it is a simulation, not a Windows test.

Expected results (all passed for 2.4.0 on 29 October 2026):

| Scenario | What the fake tools do | Expected code |
|---|---|---|
| healthy | DISM healthy, SFC clean | 0 |
| healthy, -SfcMode AfterDismRepairOnly | DISM healthy; SFC skipped | 0 |
| dism-repair | DISM repairable, repair succeeds, confirmation healthy, SFC /scannow clean | 2 |
| dism-fail | DISM repairable, repair exits 87 | 3, with advice for error 87 |
| not-repairable | "The component store cannot be repaired." | 3 |
| unrecognised | Unknown DISM message, exit code 0 | 5 |
| sfc-repair | SFC finds violations, /scannow repairs, confirmation clean | 2; CBS details hold only this run's lines |
| sfc-repair, -SfcMode AlwaysRepair | Straight to /scannow, then confirmation | 2 |
| sfc-partial | "unable to fix some of them" | 4 |
| sfc-pending | "system repair pending which requires reboot" | 6 |
| lock | A second run starts while the first holds the lock | 10 for the second run |
| time-out | DISM runs past -DismTimeoutMinutes 10 | 7; output kept; no processes left |

Known differences on Linux: no Event Viewer, no Get-CimInstance (so no free-space line) and no registry. The script handles each of these as a logged problem and carries on, which the simulation also confirms.

### 2b. Pester unit and regression tests (planned: version 2.5, stage 2)

Unit and regression tests with Pester, runnable on Benn's PC and in Claude's workspace. They include whole-run tests that replace `Invoke-Tool` with a mock, so they can eventually replace the Linux-only simulation. See docs/PLAN-2.5.md.

## Level 3: integration tests with safe Windows programs (planned: version 2.5, stage 3)

Real Windows processes on Benn's PC that touch nothing in the system: `cmd.exe /u /c echo` for genuine UTF-16LE output, `cmd.exe /c exit 3010` for exit codes, and `cmd.exe /c ping -n 120 127.0.0.1` for the time limit and process-tree clean-up. These tests do not need administrator rights. See docs/PLAN-2.5.md.

## Level 4: real DISM and SFC runs on Benn's PC

1. Open PowerShell **as administrator**.
2. Run the script in PowerShell 7, the target runtime:
   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\WindowsHealthMonitor\WindowsHealthMonitor.ps1"
   ```
3. On a healthy PC, expect in Summary.txt (about 2 minutes on Benn's PC):
   - `PowerShell: PowerShell 7.6.9 (...\pwsh.exe).`
   - `Windows drive (C:) has ... free of ... (..% free).`
   - `Component store state: Healthy.`
   - `SFC /verifyonly result: Clean.`
   - `OUTCOME [0]: No problems found. ...`
4. Check the report folder holds Summary.txt, Result.json, Full-Transcript.txt, 1-DISM-ScanHealth.txt (about 10 lines) and 4-SFC-VerifyOnly.txt.
5. Check Event Viewer:
   ```powershell
   Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'WindowsHealthMonitor' } -MaxEvents 3 |
       Format-List TimeCreated, Id, Message
   ```
   Expect event ID 1000 for a healthy run.
6. Check that the pop-up appeared, and closed itself after 60 seconds.
7. Start a second copy while the first is running: it should stop at once with code 10.

## Record of real Windows runs

| Date | Version | PowerShell | Path exercised | Result |
|---|---|---|---|---|
| 29 Oct 2026 09:44 | 2.1.0 | 5.1 | Healthy | 0; Result.json failed (bug fixed) |
| 29 Oct 2026 09:53 | 2.1.0 + fixes | 5.1 | Healthy | 0; all reports written |
| 29 Oct 2026 10:11 | 2.2.0 | 5.1 then 7.6.9 | Healthy, hand-over | 0 |
| 29 Oct 2026 11:00 | 2.4.0 | 5.1 | Healthy | 0; new PowerShell line and Result.json correct; 2 min 6 s |
| 29 Oct 2026 11:31 | 2.4.0 | 7.6.9 (Microsoft Store), started with `pwsh -File` | Healthy | 0; 2 min 2 s; Result.json records Edition Core and the pwsh.exe path. **The known-good baseline** for version 2.5 and for any change of AI tool |

Not yet confirmed for 2.4.0: the Event Viewer entry, the pop-up, and a second copy stopping with code 10 (level 4, steps 5 to 7).

The repair paths (codes 2 to 7) have been simulated but never run on Windows. They will run for real the first time Windows actually needs a repair. Do not damage system files to test them.
