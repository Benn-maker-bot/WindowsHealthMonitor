# Windows Health Monitor: learning log

This log makes progress visible. It is not a test score. It is updated at the end of each stage of work.

**What the status words mean:**

- **Introduced:** explained in the guide, the script's comments or a chat.
- **Practised:** you used it yourself.
- **Comfortable:** you can explain it or use it without help.
- **Revisit:** worth going over again.

Only you can say when something is "comfortable", so that column changes only when you say so.

## Concepts so far (to 29 October 2026)

| Concept | Where it appears in the project | Status |
|---|---|---|
| Variables, `$script:` scope | Run state (section 3); guide 6.1 | Introduced |
| Functions and parameters, `[ValidateSet]`, `[switch]` | Every function; guide 6.2 | Introduced |
| Hashtables, ordered tables, custom objects | `$DismErrorHints`, `Save-ResultFile`; guide 6.3 | Introduced |
| Strings, quotes, `-f` formatting | `Write-Summary`; guide 6.4 | Introduced |
| Comparisons and regular expressions | `Get-DismScanState`, `Get-SfcState`; guide 6.5 | Introduced |
| The pipeline, `Where-Object`, `Select-Object` | `ConvertFrom-ToolOutput`, `Invoke-Tool`; guide 6.6 | Introduced |
| Errors: `try`, `catch`, `finally`, `$ErrorActionPreference` | Main section; guide 6.7 | Introduced |
| Using .NET from PowerShell | `Process`, `Mutex`, `Encoding`; guide 6.8 | Introduced |
| Exit codes | `Test-DismExitCode`, the script's own result codes; guide 6.9 | Introduced |
| Text encodings (ASCII, UTF-16LE, BOM) | The SFC bug; guide 7.6 | Introduced |
| Processes, output buffers, time limits | `Invoke-Tool`; guide 7.6 | Introduced |
| Mutex (single-run lock) | Main section; guide 7.2 | Introduced |
| JSON | Result.json; guide chapter 8 | Introduced |
| Windows PowerShell 5.1 versus PowerShell 7 | Guide chapter 4 | Introduced |
| Running a script elevated, and reading its reports | Your runs on 29 October | Practised |
| Starting a script in PowerShell 7 with `pwsh -NoProfile -ExecutionPolicy Bypass -File` | Your 11:31 run; the future scheduled task | Practised |
| Getting a second opinion on a design, and checking it against the project's evidence | Copilot's reviews of the script and its change-of-tool plan | Practised |
| Checking evidence before accepting a claim | You questioned the "PowerShell 5.1" statement; the transcript proved it | Practised |

## Debugging case studies from this project

Each one is written up in PROJECT-HISTORY.md:

1. SFC results never recognised (text encoding).
2. "Result.json could not be written: Argument types do not match" (a PowerShell quirk with `@()`).
3. Why the reports said 5.1 when your window was 7.6.9 (`powershell.exe` versus `pwsh`).
4. "Corrupted" scripts that were really pasting damage (HTML in a chat box).

## Tools used so far

- **PowerShell 7 and Windows PowerShell 5.1:** used.
- **Event Viewer, `Get-WinEvent`:** introduced.
- **PSScriptAnalyzer:** used by Claude.
- **Coming in version 2.5:** Git, Pester and Task Scheduler.

## Suggested next learning objectives (version 2.5)

1. **Stage 0:** Git basics: repository, commit, history, undo.
2. **Stage 1:** dot-sourcing, and separating "define" from "run".
3. **Stage 2:** Pester: `Describe`, `It`, `Should`, `Mock`. Optional: write one test yourself.
4. **Stage 3:** process trees and exit codes, seen with real Windows programs.
5. **Stage 5:** Task Scheduler accounts and sessions.
