# Windows Health Monitor: start here (Notebook reference set, 30 October 2026)

Read this file first. It says what this set of files is, how current it is, and what the project's real state is. The same facts, in machine-readable form, are in `project-state.json`.

## 1. What this set is

- **Snapshot taken:** 30 October 2026 at 04:27 (UK time), read-only, from the master folder `C:\Scripts\WindowsHealthMonitor` on Benn's PC (computer name NEW). Nothing in that folder was changed.
- **Authority:** the PC folder is the master. Every file here is a **reference copy**. If a copy here disagrees with the PC, the PC is right.
- **Replaces:** every earlier Windows Health Monitor file in this Notebook. Older uploads of PLAN-2.5, CHANGELOG, TESTING, PROJECT-HISTORY and LEARNING-LOG described 2.4.0 and are superseded. So are "CLAUDE 1.md", "WindowsHealthMonitor - Copy.txt" and Copilot's earlier ZIP (see section 5).
- **Copied byte for byte.** Only the names changed: `.ps1` files end in `.txt` so the Notebook accepts them, and run reports carry the run's date and version in their names. `project-state.json` lists each file's SHA-256 hash, so any copy can be checked against the PC (section 8).

## 2. Current state at a glance

| Item | State |
|---|---|
| Script version | **2.5.0-dev.1** (`$ScriptVersion` in WindowsHealthMonitor.ps1) |
| Plan | docs/PLAN-2.5.md: stage 0 (Git) done; stage 1 (testability) done and tested; stages 2 to 6 not started |
| Known-good baseline | 29 Oct 2026 11:31, version 2.4.0, PowerShell 7.6.9: healthy, result code 0, 2 min 2 s |
| Last real Windows run | 29 Oct 2026 13:19, version 2.5.0-dev.1, PowerShell 7.6.9: healthy, result code 0, 2 min 9 s, matching the baseline |
| Git | **Stage 1 is not yet committed** (section 3) |
| Next work item | 2.5.0-dev.2: stop dot-sourcing from changing the caller's settings (section 6) |

## 3. Git: what the repository actually holds

Checked directly on the PC at the snapshot time:

- **Commits on `main`:** two.
  1. `4239d2b`: the 2.4.0 baseline.
  2. `b325a72`: "Docs: record stage 0 (Git) as done".
- **Not yet committed:** all of stage 1. Ten tracked files are modified (the script, PROJECT.md, the six documents in `docs\`, `Tests\README.md` and `Tests\run-scenario.sh`). Two new files are untracked: `Tests\Test-DotSource.ps1` and `Tests\run-all.sh`.
- **A difference to note:** PLAN-2.5.md's resume note lists "one commit for stage 1" with the message "Stage 1: make the script testable (2.5.0-dev.1)". That commit does not exist yet. The note names the commit to make, not one already made.
- **A stray file:** `WindowsHealthMonitor - Copy.txt` sits untracked in the master folder. It is identical to the 2.5.0-dev.1 script; it is the copy given to this Notebook earlier.

**Recommended before any further change:** commit stage 1 on its own, with the message the plan already names. Otherwise the 2.5.0-dev.2 change would be mixed into the same `git diff`, and could not be reviewed or undone separately.

## 4. Evidence for 2.5.0-dev.1

As recorded in docs/TESTING.md and docs/CHANGELOG.md (not re-run for this snapshot):

1. **Static checks:** passed.
2. **Simulations:** all 12 scenarios give the same result codes as 2.4.0 (Claude's Linux workspace; a simulation, not a Windows test).
3. **`Tests\Test-DotSource.ps1`:** passed on Benn's PC, all 7 checks.
4. **Real Windows run:** 13:19 on 29 October, healthy, code 0. Its reports are in this set (`Run-2026-10-29_1319_v2.5.0-dev.1_*`). Its Result.json has `"SchemaVersion": 1`.

**Still unconfirmed on Windows:** the Event Viewer entry, the pop-up, and a second copy stopping with code 10. Stage 1 rewrote the code-10 branch (from `exit 10` to `return`), and so far only the simulation has exercised it.

## 5. Superseded material

| Item | Status |
|---|---|
| Copilot's ZIP with the isolation fix | A draft sketch only, withdrawn by Copilot itself. Do not apply it |
| Earlier uploads of PLAN-2.5, CHANGELOG, TESTING, PROJECT-HISTORY, LEARNING-LOG | Described 2.4.0. Replaced by the copies here |
| "CLAUDE 1.md" | A duplicate. Replaced by CLAUDE.md here |
| "WindowsHealthMonitor - Copy.txt" | The same bytes as the script, but use `WindowsHealthMonitor.ps1.txt` from this set |

## 6. The agreed next work item: 2.5.0-dev.2

Claude's review and Copilot's corrected assessment (30 October 2026) agree on this.

**The problem:** the script's top level runs `$ErrorActionPreference = 'Stop'` and `Set-StrictMode -Version 2.0`. Dot-sourcing runs top-level code in the caller's scope, so loading the script changes the caller's settings. This affects an interactive console, Pester, and VS Code (the PowerShell extension dot-sources scripts on F5 by default; setting `powershell.debugging.executeMode`).

**The steps, in order:**

1. Commit stage 1 (section 3).
2. Add two checks to `Tests\Test-DotSource.ps1`:
   - `$ErrorActionPreference` is unchanged after loading;
   - strict mode did not leak (reading an undefined variable behaves as it did before loading).
3. Run the new checks against the unchanged 2.5.0-dev.1 and record that they **fail**.
4. Move the two lines to the start of `Invoke-WindowsHealthMonitor`, before the administrator check.
5. Correct the `.DESCRIPTION` pre-flight order (administrator check, lock, report folder, old-report removal, pending restart, free space). Comment only; the execution order does not change.
6. Set `$ScriptVersion` to `2.5.0-dev.2`.
7. Run the parser and PSScriptAnalyzer checks, `Test-DotSource.ps1` and all 12 simulations.
8. One elevated healthy run in PowerShell 7. While it holds the lock, start a second copy and confirm it stops with code 10.
9. Update CHANGELOG, PROJECT-HISTORY, TESTING, PROJECT.md rule 15 and LEARNING-LOG.
10. Inspect `git diff`, then commit.

**Acceptance criterion:** loading the script does not change the caller's preference variables or strict mode. Loading still defines the parameters, settings and functions; that is what dot-sourcing is for.

**Agreed for stage 2, not now:** run state is created when the file loads. Whole-run Pester tests should load the script afresh before each test, matching production's one load, one run. Add an `Initialize-RunState` function only if that proves impractical.

## 7. File map

| File in this set | Path on the PC | What it is |
|---|---|---|
| 00-START-HERE.md | (new) | This file |
| project-state.json | (new) | The same facts, machine-readable, with file hashes |
| PROJECT.md | PROJECT.md | The project's rules |
| AGENTS.md | AGENTS.md | How any AI assistant must work |
| CLAUDE.md | CLAUDE.md | Pointer for Claude Code |
| WindowsHealthMonitor.ps1.txt | WindowsHealthMonitor.ps1 | The script, 2.5.0-dev.1 |
| PLAN-2.5.md | docs\PLAN-2.5.md | Plan for version 2.5 |
| CHANGELOG.md | docs\CHANGELOG.md | Changes by version |
| PROJECT-HISTORY.md | docs\PROJECT-HISTORY.md | Bugs, lessons and decisions |
| TESTING.md | docs\TESTING.md | Test levels, procedures and the record of real runs |
| LEARNING-LOG.md | docs\LEARNING-LOG.md | Benn's learning record |
| AI-MIGRATION.md | docs\AI-MIGRATION.md | Plan for a possible change of AI tool |
| Tests-README.md | Tests\README.md | What the test files do |
| Test-DotSource.ps1.txt | Tests\Test-DotSource.ps1 | The Windows-safe loading test |
| Run-2026-10-29_1131_v2.4.0-baseline_*.txt/.json | Logs\2026-10-29_113113\ | The baseline run: Summary, Result.json, transcript |
| Run-2026-10-29_1319_v2.5.0-dev.1_*.txt/.json | Logs\2026-10-29_131948\ | The 2.5.0-dev.1 run: Summary, Result.json, transcript |

**Left out on purpose:**

- `WindowsHealthMonitor-Guide.docx`: it describes 2.4.0 by design and is updated at release (stage 6).
- The bash simulation files: they run only in Claude's Linux workspace, and Pester replaces them in stage 2.
- `Archive\`, older run folders and `.git\`: history, not current state.

## 8. Rules for any AI using this Notebook

- Follow AGENTS.md. In short: only one assistant edits at a time; anything another assistant produces is a **draft** until reviewed and tested; the tests and real Windows runs are the referee.
- Never move the script by pasting it into a chat box. Pasting has damaged it before.
- Say exactly which test levels a change has passed. Only a real run on Benn's PC counts as "tested on Windows".

**To check that a copy here matches the PC,** run this in PowerShell 7 and compare the result with the `sha256` value in `project-state.json`:

```powershell
(Get-FileHash 'C:\Scripts\WindowsHealthMonitor\WindowsHealthMonitor.ps1').Hash
```

`Get-FileHash` uses SHA-256 by default and shows the hash in capitals; the JSON uses lower case. The letters and digits are otherwise the same. A different hash means the PC file has changed since this snapshot, so the Notebook needs refreshing.

## 9. Refreshing this set

Refresh the Notebook after every stage or version change:

1. Remove the old set.
2. Upload a new snapshot.
3. Update this file and `project-state.json`.

CLAUDE.md asks for the same refresh of the Claude Project's reference copies.
