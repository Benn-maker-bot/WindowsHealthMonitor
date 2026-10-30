# Windows Health Monitor: changelog

Newest first. Dates are UK dates.

## 2.5.0-dev.1 (29 October 2026, stage 1 of PLAN-2.5)

The script is now testable. What DISM and SFC do, and the result codes, are unchanged.

- **Changed:** the main section is now a function, `Invoke-WindowsHealthMonitor`. The last lines of the file call it, unless the script is being dot-sourced (`. .\WindowsHealthMonitor.ps1`). Tests can therefore load every function without running a health check.
- **Changed:** `#requires -RunAsAdministrator` is replaced by a check at the start of a run (new function `Test-IsAdministrator`). Without administrator rights, a run still stops at once with result code 1, and now says how to fix it.
- **Changed:** a second run that finds the lock taken now leaves code 10 in `$script:Outcome` instead of calling `exit 10` from inside the function. The exit code, message and Event Viewer entry (ID 1010) are the same.
- **New:** `Get-RestoreHealthArgument` builds the DISM /RestoreHealth options, including `/Source:` and `/LimitAccess`. The options themselves are unchanged.
- **New:** Result.json has a `SchemaVersion` field (1), so later changes to its layout can be detected.
- **New:** `Tests\Test-DotSource.ps1`, a safe check that runs on Windows without administrator rights. The simulation harness now takes the script and a mode (`file` or `dot`).
- **Tested:** static checks; all 12 simulated scenarios give the same result codes as 2.4.0; dot-sourcing runs nothing. On Benn's PC on 29 October 2026: `Test-DotSource.ps1` passed, and a real run at 13:19 in PowerShell 7.6.9 was healthy (code 0) and matched the 11:31 baseline.
- **Not yet updated:** the Word guide still describes 2.4.0. It is updated at release (stage 6).

## 2.4.0 (29 October 2026)

- **Removed** the PowerShell 7 hand-over, version check, download and installer (about 460 lines, with their comments). The script no longer needs internet access and installs nothing.
- **Removed** the `-PowerShellUpdate` option and the internal `-HandoverInfo` parameter.
- **Changed:** Result.json's `PowerShell` section now records just the version, edition and path in use. Summary.txt shows one "PowerShell:" line.
- **Fixed:** an unrecognised DISM message with a success exit code no longer suggests looking up "DISM error 0x00000000"; it points to the report file and dism.log.
- **Tested:** a full simulation of every path with fake DISM and SFC programs (see TESTING.md). Real Windows runs on 29 October 2026, both on the healthy path with code 0: at 11:00 in Windows PowerShell 5.1, and at 11:31 in PowerShell 7.6.9 (the known-good baseline).
- **Help text updated (same day, code unchanged):** PowerShell 7 (`pwsh.exe`) is now named as the scheduled-task runtime, following the project instructions. Windows PowerShell 5.1 still works but is no longer required.
- **Documents (same day):**
  - Tool-neutral rules: PROJECT.md (the project's rules) and AGENTS.md (how any AI assistant must work). CLAUDE.md is now a short pointer to them; the earlier INSTRUCTIONS.md and CLAUDE.md are kept in Archive.
  - AI-MIGRATION.md is new: a staged plan for possibly moving from Claude Code to another AI coding tool, based on Copilot's recommendations.
  - TESTING.md now uses the four test levels from the project instructions.
  - LEARNING-LOG.md is new.
  - Git: the project folder is now a Git repository (baseline commit `4239d2b`). `.gitignore` leaves out Logs; `.gitattributes` keeps LF line endings.
  - PLAN-2.5.md sets out version 2.5 in seven stages, each with a recommended default for any decision it needs.

## 2.3 (Copilot draft, not adopted)

- Offered as a link that could not be opened. Never reviewed or tested.

## 2.2.0 (29 October 2026)

- Added the hand-over to PowerShell 7 and the PowerShell 7 updater (since removed in 2.4.0).
- Added teaching comments throughout (code unchanged; all 5,696 code tokens compared).
- Ran on Windows: healthy path, in PowerShell 7.6.9 after a hand-over from 5.1.

## 2.1.1 (29 October 2026)

- Collapses blank lines left by progress bars (the DISM report went from 120 lines to 10).
- Durations in minutes and seconds; DurationSeconds in Result.json.
- RunContext in Result.json (user, 64-bit, session, script path).

## 2.1.0 (28 to 29 October 2026)

- DISM exit code checked before its text is trusted, on every scan.
- Unexpected SFC exit codes recorded as notes.
- Safer time-out handling; output kept; "still running" detection.
- pending.xml blocks a run only if written since the last restart.
- Byte-order-mark detection; before-and-after states and RestartRecommended in Result.json; pending computer rename noted.
- Clearer free-space line (size, percentage, verdict).
- Fixed Result.json "Argument types do not match" (`.ToArray()` instead of `@()`).
- Ran on Windows: healthy path, in Windows PowerShell 5.1.

## 2.0.0 (28 October 2026)

- Rewrite of version 1: raw-byte capture and encoding detection (SFC fixed); SFC every run, read-only first; confirmation scans; time limits; pending-restart and free-space checks; Event Viewer entry; Result.json; current-run CBS lines; report retention; Sysnative for 32-bit hosts; abandoned-lock recovery.

## 1 (original)

- DISM /ScanHealth, /RestoreHealth if corrupt, then SFC /scannow; Summary.txt; pop-up. Could not read SFC's results.
