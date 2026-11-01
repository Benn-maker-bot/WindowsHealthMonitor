# Ideas from similar projects (researched 1 November 2026)

## Resume note
- **What this is:** a review of open-source tools that do similar jobs, and which of their ideas suit this project.
- **Script version reviewed:** 2.5.0-dev.2.
- **Nothing in the script has changed.** These are proposals only.
- **Recommended next action:** carry on with PLAN-2.5.md Stage 1 and Stage 2. Idea 2 (gap 2) fits Stage 1 now; the rest are for 2.6.

## How to read this
Each idea says what it is, where it came from, why it might help, the risk, and how it would be tested. They are in priority order. Ideas marked **2.6 or later** should not disturb the 2.5 plan.

---

## Recommended

### 1. Add DISM `/CheckHealth` as a cheap first look (2.6)
- **Source:** WindowsUpdateTools module, `Test-WUComponentStore`.
- **What:** `/CheckHealth` takes seconds. It reads a flag Windows sets after a failed servicing operation. It does not scan.
- **Why:** it gives an extra piece of evidence in Result.json at almost no cost. If it reports "repairable" before ScanHealth even runs, that is useful history.
- **Important:** keep ScanHealth unconditional. CheckHealth only knows about corruption that Windows already noticed. That tool's weakness is that it *skips* ScanHealth in some cases; we should not copy that.
- **Test:** sample-output classification in Pester (healthy, repairable, non-repairable), using the same healthy-first precedence as the DISM false-positive regression test.

### 2. Count postponed runs, and make restart detection testable (2.5 Stage 1/2, then 2.6)
- **Sources:** Test-PendingReboot (PowerShell Gallery), dbatools `Test-PendingReboot`, the PendingReboot module.
- **What they do:** check `CBS\RebootPending`, `WindowsUpdate\Auto Update\RebootRequired` and `PendingFileRenameOperations`, and treat all three as an equal true/false.
- **What our script already does better:** `Get-PendingRestartReason` blocks only on the two servicing keys, ignores `PendingFileRenameOperations`, treats a pre-restart `pending.xml` as stale (a note, not a block) and treats a computer rename as informational.
- **Gap 1 - repeated postponement:** if Windows keeps a servicing key set for days, every run is skipped with no escalation. Proposal: read the previous Result.json; after, say, 3 consecutive postponed runs, add a warning that recommends a restart (still never restarting automatically).
- **Gap 2 - testability:** the function reads the registry directly, so Pester cannot test it. Split it into a small "collect" part (reads registry, pending.xml dates, boot time) and a pure "classify" part that takes those facts as a hashtable. The classify part is then fully unit-testable, including the stale pending.xml rule. This fits PLAN-2.5 Stage 1 because it does not change behaviour.

### 3. Record component-store size with `/AnalyzeComponentStore` (report only) (2.6)
- **Sources:** WURepair v2.9.0; saotn.org article on parsing it.
- **What:** reports WinSxS size, reclaimable packages and "Component Store Cleanup Recommended: Yes/No".
- **Why:** observability. Store growth over time is a useful trend; cleanup-recommended can explain low disk space.
- **Do not copy:** WURepair goes on to run `/StartComponentCleanup /ResetBase`. ResetBase makes updates permanently non-removable. That is outside "health monitoring and supported repair" and breaks the conservative safety rules. Report only.
- **Cost:** it takes a minute or two; make it a configuration switch, default off for the scheduled task.

### 4. Read-only disk check: `chkdsk C: /scan` (2.6, optional)
- **Source:** limehawk rmm-scripts DISM/SFC/chkdsk maintenance script.
- **What:** `/scan` is an online, read-only check. It never needs a restart.
- **Why:** file-system damage is a common root cause of repeated SFC failures, so it improves diagnosis.
- **Do not copy:** their option for `/f /r` (needs a restart) and their automatic scheduled reboot. Both break our "never restart" rule.
- **Test:** sample output classification; chkdsk exit codes (0 clean, 1 fixed, 2 cleanup needed, 3 failed) as a table-driven Pester test.

### 5. Pull relevant Event Log evidence for the run window (2.6)
- **Source:** general practice in health-check scripts; none of the DISM/SFC tools did this well.
- **What:** `Get-WinEvent -FilterHashtable` for the run's start/finish time: `Microsoft-Windows-Servicing`, `Disk`, `Ntfs`, and `volsnap` errors.
- **Why:** answers "did anything else go wrong while this ran?" and gives evidence when a result is Unknown.
- **Test:** the filter-building function is pure and unit-testable; the live query is an integration test (Stage 3 style).

---

## Worth knowing, but not recommended now

### 6. The DISM PowerShell module (`Repair-WindowsImage`)
- `Repair-WindowsImage -Online -ScanHealth` returns an object with a health state instead of text, which would avoid text parsing.
- **Why not now:** the Microsoft documentation does not state PowerShell 7 support, and it loses the raw output, timing and timeout control that Invoke-Tool gives. Raw output is a project requirement. It could be a **second opinion** recorded alongside dism.exe output, after testing on your PC under pwsh.

### 7. Pester-as-health-check (markwragg/PowerShell-ServerHealthCheck)
- Writes each health condition as a Pester test. Neat, but mixes "testing our code" with "checking the PC". Keep Pester for testing the script, as PLAN-2.5 already does.

### 8. Toast notifications (BurntToast module)
- Adds a dependency, and toasts do not appear when the task runs with no logged-on desktop. The existing Event Log entry plus pop-up is the right design.

---

## Things the research confirmed we already do better
- **Restart detection.** The reboot modules treat every indicator as a block; ours separates servicing indicators from stale and informational ones.
- **Healthy-first matching.** WindowsUpdateTools still uses broad `*successfully*` wildcards that could hide a real error; our precedence rules and regression test avoid that.
- **CBS extraction for the current run.** That module reads the last 500 lines of CBS.log, which can miss or mix runs (our regression history item 5).
- **Repair confirmation.** None of the scripts reviewed re-verified after RestoreHealth or SFC repair.
- **Exit codes.** The RMM script uses only 0 and 1; ours distinguish the outcome model.
- **No automatic restart.** Two of the tools reviewed schedule reboots.

## Sources
- WindowsUpdateTools `Test-WUComponentStore`: https://www.powershellgallery.com/packages/WindowsUpdateTools/1.6.5/Content/dist%5Ctemp%5CWindowsUpdateTools%5CPrivate%5CTest-WUComponentStore.ps1
- limehawk DISM/SFC/chkdsk script: https://github.com/limehawk/rmm-scripts/wiki/windows_dism_sfc_chkdsk_maintenance.ps1
- Test-PendingReboot: https://www.powershellgallery.com/packages/Test-PendingReboot/1.1/Content/Test-PendingReboot.ps1
- WURepair v2.9.0: https://github.com/SysAdminDoc/WURepair/releases/tag/v2.9.0
- Repair-WindowsImage (Microsoft Learn): https://learn.microsoft.com/en-us/powershell/module/dism/repair-windowsimage
- PowerShell-ServerHealthCheck: https://github.com/markwragg/PowerShell-ServerHealthCheck
