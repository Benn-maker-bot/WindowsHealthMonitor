# Windows Health Monitor: changing AI coding tool

Status: **under consideration, 29 October 2026.** Based on Copilot's recommendations of 29 October 2026. No replacement tool has been chosen yet.

## Where we are now (resume note)

- **Done:**
  - Phase 0: version 2.4.0 is under Git (baseline commit `4239d2b`).
  - Phase 1: the baseline run is recorded.
  - Phase 2: the documents are tool-neutral.
  - Phase 3: AGENTS.md is the operating contract for any AI.
- **Next:** PLAN-2.5 stages 1 and 2 (testability and the Pester tests), before any trial of a new tool.

## The three principles

1. **Change one thing at a time.** First change the tool, then change the code. Never both at once.
2. **Migrate the engineering discipline, not just the code.** The rules in PROJECT.md and AGENTS.md go with the project, whichever AI is used.
3. **The tests are the referee.** Neither Claude Code nor the replacement is the authority; the tests and real Windows runs are. That is why Pester tests (version 2.5, stage 2) come before the cut-over.

## Phases

| Phase | What happens | Status |
|---|---|---|
| 0. Freeze the baseline | Keep `C:\Scripts\WindowsHealthMonitor` as the master. Put version 2.4.0 under Git and commit it unchanged | **Done:** baseline commit `4239d2b`, 29 October 2026 |
| 1. Runtime baseline | Record a successful real run in PowerShell 7 | **Done:** 29 October 2026 at 11:31, PowerShell 7.6.9, healthy, code 0 |
| 2. Tool-neutral documents | PROJECT.md (project rules) and AGENTS.md (how an AI must work); CLAUDE.md only points to them | **Done,** 29 October 2026 |
| 3. Operating contract | Give the new tool AGENTS.md before it writes anything | **Ready** |
| 4. Qualification test | A read-only examination of version 2.4.0 (below) | Not started |
| 5. Harmless editing trial | One small change away from DISM and SFC, such as a comment, a document or a small test; then inspect `git diff` | Not started |
| 6. Tests as referee | PLAN-2.5 stages 1 (testability) and 2 (Pester tests) | Not started |
| 7. Parallel period | One tool writes, the other reviews, then swap once (below) | Not started |
| 8. Historical regressions | Confirm the new tool keeps every protection (below) | Not started |
| 9. Cut-over | When every condition below is met | Not started |

## Phase 4: the qualification test

Ask the new tool, **without letting it edit anything**, to explain how version 2.4.0 protects against problems in each area:

1. DISM classification (healthy, repairable, not repairable, unknown);
2. SFC's UTF-16LE output;
3. DISM exit codes, including 3010;
4. repair confirmation;
5. pending restarts, including why PendingFileRenameOperations is ignored;
6. the single-run lock (mutex);
7. time limits for native programs, including stopping the whole process tree;
8. Result.json, including the `.ToArray()` rule.

Compare its answers with docs/PROJECT-HISTORY.md. For example, it must recognise why "component store corruption detected" must not be matched loosely: that text also appears inside the healthy message "No component store corruption detected".

**If it proposes "simplifying" any of these protections without understanding their history, do not let it edit the master copy.**

## Phase 7: the parallel period

- **Round A:** the new tool analyses an issue, proposes a change, edits a Git branch and runs the tests. Claude Code reviews the diff only.
- **Round B:** Claude Code proposes a small change, and the new tool reviews it.

Only one tool edits at any time (AGENTS.md section 2). This shows up systematic differences between the tools without creating competing versions of the script.

## Phase 8: historical regressions

Before declaring the change of tool a success, the new tool must work safely around each of these. The Pester suite planned in PLAN-2.5 stage 2 covers them all:

- **DISM false positive:** "No component store corruption detected" stays Healthy.
- **SFC encoding:** SFC output is decoded deliberately, as UTF-16LE.
- **Repair confirmation:** a successful repair command alone never proves Windows is healthy.
- **Native error output:** a line on standard error never becomes a misleading terminating error.
- **JSON collections:** the `List[object]` / `@()` problem stays fixed.

## Phase 9: cut-over conditions

The change of tool is complete only when **all** of these are true:

1. Git protects the project (done).
2. The new tool understands the whole project, not isolated snippets.
3. It can make changes across several files without damaging unrelated code.
4. Static analysis works in the new workflow.
5. The Pester regression tests work in the new workflow.
6. The harmless Windows integration tests work (PLAN-2.5 stage 3).
7. A supervised real run on Benn's PC succeeds after a representative change.
8. The project documents are tool-neutral (done).
9. Benn can inspect and undo one of the new tool's changes himself.

The last condition matters most: the long-term aim is for Benn to be able to review and maintain the software himself, not to depend on any one AI.

## What not to do

- Do not uninstall or abandon Claude Code before the cut-over.
- Do not copy and paste WindowsHealthMonitor.ps1 between assistants (pasting has damaged it before).
- Do not let the new tool rewrite the script wholesale.
- Do not change tool while also redesigning DISM or SFC behaviour.
- Do not accept code because it "looks right".
- Do not let AI changes bypass Git.
- Do not treat simulation results as proof of Windows behaviour.

## The recommended order

This fits around docs/PLAN-2.5.md rather than replacing it:

1. Known-good 2.4.0 baseline (done).
2. Git baseline (PLAN-2.5 stage 0) (done).
3. Record the PowerShell 7 run in the documents (done).
4. Tool-neutral documents (done).
5. PLAN-2.5 stage 1: make the script testable.
6. PLAN-2.5 stage 2: the Pester regression suite.
7. Phases 4 and 5: qualification test and harmless editing trial of the new tool.
8. Phase 7: the parallel review period.
9. PLAN-2.5 stage 3: the harmless Windows integration tests.
10. A supervised real Windows run.
11. Retire Claude Code, if the new tool has proved reliable.

There is no need to rush.
