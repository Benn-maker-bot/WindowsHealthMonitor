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
| Git: repository, staging (`git add`), commit, history (`git log`) | Stage 0: you created the repository and made the baseline commit | Practised |
| `.gitignore` and why run reports are left out of Git | Stage 0 | Introduced |
| Checking evidence before accepting a claim | You questioned the "PowerShell 5.1" statement; the transcript proved it | Practised |
| Reading a change before committing it (`git diff`, `git diff --stat`) | Your second commit, `b325a72` | Practised |
| Keeping tools up to date, and what the ".windows.N" part of a Git version means | Updating Git for Windows | Practised |
| Separating "define" from "run": the main section as a function | `Invoke-WindowsHealthMonitor`; stage 1 | Introduced |
| Dot-sourcing (`. .\script.ps1`) and `$MyInvocation.InvocationName` | Section 7 of the script; `Tests\Test-DotSource.ps1` | Introduced |
| `return` versus `exit` inside a function | The code-10 branch in stage 1 | Introduced |
| Checking administrator rights in code (`WindowsPrincipal`, `IsInRole`) | `Test-IsAdministrator` | Introduced |
| A test that can fail: checking a test catches a deliberately broken version | `Test-DotSource.ps1` (Claude broke the guard on a copy; the test failed) | Introduced |
| VS Code Source Control: Changes vs Staged Changes, reviewing diffs, staging, un-staging, commit messages, and local commits vs pushing | `docs/SOURCE-CONTROL-GUIDE.md` | Introduced |

## Debugging case studies from this project

Each one is written up in PROJECT-HISTORY.md:

1. SFC results never recognised (text encoding).
2. "Result.json could not be written: Argument types do not match" (a PowerShell quirk with `@()`).
3. Why the reports said 5.1 when your window was 7.6.9 (`powershell.exe` versus `pwsh`).
4. "Corrupted" scripts that were really pasting damage (HTML in a chat box).
5. A Source Control commit that appeared stuck because VS Code was waiting for a commit message.

## Tools used so far

- **PowerShell 7 and Windows PowerShell 5.1:** used.
- **Event Viewer, `Get-WinEvent`:** introduced.
- **PSScriptAnalyzer:** used by Claude.
- **Git:** used (stage 0, 29 October 2026). Git for Windows updated the same day.
- **Coming in version 2.5:** Pester and Task Scheduler.

## Suggested next learning objectives (version 2.5)

1. **Stage 0:** Git basics: repository, commit, history, `git diff` (done). Still to practise: undoing a change with `git restore`.
2. **Stage 1:** dot-sourcing, and separating "define" from "run" (introduced; you will run `Test-DotSource.ps1` yourself).
   - **Pure functions (1 November 2026, 2.5.0-dev.3):** introduced. Restart detection now has a "collect" step that reads Windows and a "decide" step that only takes facts in and gives a decision out. A pure function is easy to test, because a test can hand it any facts it likes. Also seen: `[System.Collections.Generic.List[string]]`, a list that grows without copying.
3. **Stage 2:** Pester: `Describe`, `It`, `Should`, `Mock`. Optional: write one test yourself.
4. **Stage 3:** process trees and exit codes, seen with real Windows programs.
5. **Stage 5:** Task Scheduler accounts and sessions.
