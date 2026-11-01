# Test-DotSource.ps1 - checks that the health monitor can be LOADED without being RUN.
#
# Safe: it runs no DISM or SFC, changes nothing, and needs no administrator rights.
# Run it from any PowerShell 7 window:
#
#     pwsh -NoProfile -File "C:\Scripts\WindowsHealthMonitor\Tests\Test-DotSource.ps1"
#
# Every line should end in PASS. This is a stepping stone: in version 2.5 stage 2, Pester
# tests replace it.

$script = Join-Path (Split-Path -Parent $PSScriptRoot) 'WindowsHealthMonitor.ps1'
$logs   = Join-Path (Split-Path -Parent $PSScriptRoot) 'Logs'
$before = @(Get-ChildItem -LiteralPath $logs -Directory -ErrorAction SilentlyContinue).Count

# Loading must not change the caller's settings (version 2.5.0-dev.2). Record them first, so
# the checks below can compare. Strict mode has no command that reports it, so this tests its
# effect instead: under strict mode, reading a variable that was never set is an error.
function Test-StrictModeOn {
    try { $null = $notSetAnywhereForStrictModeCheck; return $false } catch { return $true }
}
$preferenceBefore = $ErrorActionPreference
$strictBefore     = Test-StrictModeOn

# The dot and the space: load the script into this scope without starting a health check.
. $script

$preferenceAfter = $ErrorActionPreference
$strictAfter     = Test-StrictModeOn

$failures = 0
function Assert {
    param([string]$Name, [bool]$Passed)
    $word = if ($Passed) { 'PASS' } else { 'FAIL' }
    if (-not $Passed) { $script:failures++ }
    Write-Host ('{0,-64} {1}' -f $Name, $word)
}

$after = @(Get-ChildItem -LiteralPath $logs -Directory -ErrorAction SilentlyContinue).Count
Assert 'Loading created no report folder'                         ($after -eq $before)
Assert 'The verdict is still the starting value (nothing ran)'     ($script:Outcome.Message -eq 'The health check stopped before it reached a result.' -and $script:Steps.Count -eq 0)
Assert 'Invoke-WindowsHealthMonitor is loaded'                     ([bool](Get-Command Invoke-WindowsHealthMonitor -CommandType Function -ErrorAction SilentlyContinue))
Assert 'Healthy DISM text is Healthy (the false-positive guard)'  ((Get-DismScanState 'No component store corruption detected.') -eq 'Healthy')
Assert 'Repair arguments without a source have no /LimitAccess'   (-not ((Get-RestoreHealthArgument) -contains '/LimitAccess'))
Assert 'A source path with spaces is quoted, with /LimitAccess'   (((Get-RestoreHealthArgument -Source 'WIM:D:\My Media\install.wim:6') -join ' ') -eq '/Online /Cleanup-Image /RestoreHealth /English /Source:"WIM:D:\My Media\install.wim:6" /LimitAccess')
# Restart detection (2.5.0-dev.3): the decision step takes made-up facts, so no registry is read.
$restartFacts = @{ CbsRebootPending = $false; WuRebootRequired = $false; PendingXmlExists = $true
                   PendingXmlWritten = [datetime]'2026-10-01'; LastBoot = [datetime]'2026-10-31'
                   PendingXmlError = $null; ActiveName = 'PC'; TargetName = 'PC' }
$restartDecision = Get-PendingRestartDecision -Fact $restartFacts
Assert 'A stale pending.xml is a note, not a reason to skip'       (@($restartDecision.Reasons).Count -eq 0 -and @($restartDecision.Notes).Count -eq 1)
$restartFacts.CbsRebootPending = $true
Assert 'A servicing restart key skips the run'                     (@((Get-PendingRestartDecision -Fact $restartFacts).Reasons).Count -eq 1)
Assert 'Result.json schema version is 1'                          ($ResultSchemaVersion -eq 1)
Assert 'Loading left $ErrorActionPreference unchanged'            ($preferenceAfter -eq $preferenceBefore)
Assert 'Loading left strict mode unchanged'                        ($strictAfter -eq $strictBefore)

Write-Host ''
Write-Host "Administrator rights in this window: $(Test-IsAdministrator) (either answer is fine for this test)."
Write-Host $(if ($failures -eq 0) { 'All checks passed.' } else { "$failures check(s) FAILED." })
exit $failures
