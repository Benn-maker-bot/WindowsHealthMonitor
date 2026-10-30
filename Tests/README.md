# Tests

## Test-DotSource.ps1 (runs on Windows; safe)

Checks that the health monitor can be loaded without running a health check (version 2.5,
stage 1). It runs no DISM or SFC, changes nothing and needs no administrator rights:

    pwsh -NoProfile -File "C:\Scripts\WindowsHealthMonitor\Tests\Test-DotSource.ps1"

Every line should end in PASS. Pester tests replace it in stage 2.

## Simulation harness (Claude's Linux workspace only)

These bash files let Claude run the real WindowsHealthMonitor.ps1 end to end on Linux
(PowerShell 7) against fake DISM.exe and sfc.exe programs. They do not run on Windows
itself. See docs/TESTING.md, level 2.

- mock-dism.sh     fake DISM: replies per scenario, with progress bars and exit codes
- mock-sfc.sh      fake SFC: replies in UTF-16LE, and writes [SR] lines to a fake CBS.log
- run-scenario.sh  runs one scenario: ./run-scenario.sh <script.ps1> <file|dot> <scenario> [options]
                     file  starts the script with pwsh -File, as Task Scheduler does
                     dot   dot-sources it, replaces Test-IsAdministrator with a stub (Linux has
                           no Windows administrator check), then calls Invoke-WindowsHealthMonitor
- run-all.sh       runs the ten quick scenarios: ./run-all.sh <script.ps1> <file|dot>

Scenarios: healthy, dism-repair, dism-fail, not-repairable, unrecognised, sfc-repair,
sfc-partial, sfc-pending; add "#name" to run a variant, for example
./run-scenario.sh WindowsHealthMonitor.ps1 dot "sfc-repair#always" -SfcMode AlwaysRepair

From 2.5.0-dev.1 the script needs Windows administrator rights, so "file" mode on Linux
stops with code 1 (which checks that refusal); "dot" mode runs the scenarios.
The lock and time-out scenarios are run by hand (TESTING.md).
