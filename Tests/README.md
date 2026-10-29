# Simulation harness

These files let Claude run the real WindowsHealthMonitor.ps1 end to end on Linux
(PowerShell 7) against fake DISM.exe and sfc.exe programs. They are bash scripts, so
they do not run on Windows itself. See TESTING.md, level 2.

- mock-dism.sh   fake DISM: replies per scenario, with progress bars and exit codes
- mock-sfc.sh    fake SFC: replies in UTF-16LE, and writes [SR] lines to a fake CBS.log
- run-scenario.sh  runs one scenario: ./run-scenario.sh <scenario> [script options]

Scenarios: healthy, dism-repair, dism-fail, not-repairable, unrecognised, sfc-repair,
sfc-partial, sfc-pending; add "#name" to run a variant, for example
./run-scenario.sh "sfc-repair#always" -SfcMode AlwaysRepair
