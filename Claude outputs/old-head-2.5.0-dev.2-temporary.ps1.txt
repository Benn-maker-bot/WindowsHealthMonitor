#requires -Version 5.1
# Administrator rights are checked inside Invoke-WindowsHealthMonitor (Test-IsAdministrator)
# rather than with "#requires -RunAsAdministrator", which would stop a test from even loading
# the functions in an ordinary, non-elevated window.

<#
.SYNOPSIS
  Checks and repairs the Windows component store (DISM) and protected system files (SFC),
  and confirms every repair with a second scan before it reports success.

.DESCRIPTION
  Windows Health Monitor 2.5 (in development).

  Designed for Task Scheduler ("Run with highest privileges"); also safe to run by hand
  from an elevated PowerShell window. Without administrator rights it stops at once with
  exit code 1.

  Testing
    Dot-sourcing the script (. .\WindowsHealthMonitor.ps1) loads its settings and functions
    WITHOUT running a health check, so tests can call each function on its own. Starting
    it any other way (-File, & or .\) runs the health check as normal.

  PowerShell versions
    Designed for the latest stable PowerShell 7 (pwsh.exe), which the scheduled task should
    use. This version also still runs in Windows PowerShell 5.1 (powershell.exe), but future
    versions need not. It needs no internet access and installs nothing. Keep PowerShell 7
    up to date separately, through the Microsoft Store or WinGet.

  Sequence
    1. Pre-flight: administrator check, single-instance lock, report folder, removal of
       old report folders, pending-restart check, free-space check.
    2. DISM /ScanHealth classifies the component store as healthy, repairable or not repairable.
    3. If repairable: DISM /RestoreHealth, then a second /ScanHealth confirms the repair.
    4. SFC: /verifyonly (read-only) when the store is healthy; /scannow only when SFC finds
       violations or DISM has just repaired the store. A second /verifyonly confirms any
       SFC repair.
    5. Reports: Summary.txt, Result.json (machine-readable), one output file per tool,
       the CBS.log [SR] lines written during this run only, an Application event log
       entry (source "WindowsHealthMonitor"), and an optional pop-up.

  Exit codes (the Application event ID is 1000 + exit code)
     0  Healthy - nothing needed repairing.
     1  The script itself failed.
     2  Repaired - corruption was found, repaired and verified. A restart is recommended.
     3  The component store could not be repaired automatically.
     4  SFC could not repair every file, or could not run.
     5  DISM failed, or a tool's result was not recognised - review the output files.
     6  A restart is pending - checks skipped. Restart Windows and run again.
        (Only signals that affect servicing block a run: the CBS and Windows Update
        restart flags, and a WinSxS\pending.xml written since the last restart.
        A pending.xml that survived a restart, or a pending computer rename, is
        recorded as a note instead, so a stale file cannot stop every run.)
     7  A tool exceeded its time limit and was stopped.
    10  Another run was already in progress.

.PARAMETER SfcMode
  VerifyThenRepair    (default) Run SFC /verifyonly; run /scannow only if it finds violations.
  AlwaysRepair        Always run SFC /scannow.
  AfterDismRepairOnly Run SFC only after DISM has repaired the store (the version 1 behaviour).

.PARAMETER RepairSource
  Optional repair source for DISM /RestoreHealth, for example
  'WIM:D:\sources\install.wim:6' or 'ESD:D:\sources\install.esd:6'.
  When supplied, the script adds /LimitAccess so that DISM does not contact Windows Update.

.PARAMETER RetainDays
  Report folders older than this are deleted. 0 keeps everything.

.PARAMETER IgnorePendingRestart
  Run the checks even when Windows reports a pending restart (results may be unreliable).

.PARAMETER NoPopup
  Suppress the on-screen pop-up.

.EXAMPLE
  pwsh.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Scripts\WindowsHealthMonitor\WindowsHealthMonitor.ps1"
  The scheduled-task command: PowerShell 7, with no profile and no prompts.

.EXAMPLE
  pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\WindowsHealthMonitor\WindowsHealthMonitor.ps1" -SfcMode AlwaysRepair
  A manual run that always uses the repairing SFC scan.
#>

# ============================================================================================
#  HOW TO READ THIS SCRIPT
# ============================================================================================
#  PowerShell reads this file from top to bottom, but almost all of it only DEFINES things
#  (settings and functions). Nothing happens until the very last lines:
#
#     1. param(...)        What you can type on the command line.
#     2. Configuration     Fixed settings: version, file paths, error hints.
#     3. Run state         Variables that collect results while the script runs.
#     4. Helpers           Small reusable functions (logging, formatting, reading output).
#     5. Health check      The DISM and SFC logic - the heart of the script.
#     6. Main              Invoke-WindowsHealthMonitor: lock, reports, checks, finish up.
#     7. Start             The last few lines: run section 6, unless a test is loading
#                          the script (see "dot-sourcing" there).
#
#  So things HAPPEN when section 7 calls section 6, which calls sections 4 and 5.
#  The companion guide, WindowsHealthMonitor-Guide.docx, explains every part with diagrams.
#
#  POWERSHELL BASICS USED THROUGHOUT
#    $name               A variable. Inside a function, $script:name means the script's own
#                        copy; without "script:", assigning to $name inside a function would
#                        create a separate private variable that vanishes when it returns.
#    function Verb-Noun { param(...) ... }
#                        A reusable block of code. The verb (Get, Set, Test, Invoke...) says
#                        what it does; param(...) lists its inputs.
#    Verb-Noun -Name value
#                        Calling a function or command with a named input.
#    [type]              A .NET type, such as [int], [string], [version] or [datetime].
#                        [Some.Type]::Member uses a built-in method or property of that type.
#    @( ... )            An array (a list).   @{ ... }  A hashtable (name = value pairs).
#    [ordered]@{ ... }   A hashtable that keeps its entries in the order written.
#    [pscustomobject]@{ ... }   An object with named properties, like a record card.
#    "text $var"         Double quotes insert variables; 'text $var' (single quotes) does not.
#    "... $( ... ) ..."  Runs an expression inside a double-quoted string.
#    'Hello {0}' -f $x   The format operator: puts $x where {0} is.
#    -eq -ne -lt -gt -ge Comparisons: equal, not equal, less than, greater than, at least.
#    -like / -match      Wildcard match ('*.txt') / regular-expression match.
#    |                   The pipeline: passes one command's output to the next command.
#    try { } catch { } finally { }
#                        Error handling: catch runs if try fails; finally ALWAYS runs.
#    ` (back-tick)       At the end of a line, continues the command on the next line.
#    # and <# ... #>     Comments, which PowerShell ignores.
# ============================================================================================
[CmdletBinding()]
# --------------------------------------------------------------------------------------------
#  Parameters (section 1)
#  Each entry is a command-line option, e.g.  -SfcMode AlwaysRepair  or  -NoPopup.
#  The attributes in square brackets check the value before the script even starts:
#    [ValidateSet(...)]      only the listed words are accepted;
#    [ValidateRange(a, b)]   only whole numbers from a to b are accepted;
#    [switch]                an on/off option: typing it means on, leaving it out means off.
#  The value after "=" is the default, used when you leave the option out.
# --------------------------------------------------------------------------------------------
param(
    [ValidateSet('VerifyThenRepair', 'AlwaysRepair', 'AfterDismRepairOnly')]
    [string]$SfcMode = 'VerifyThenRepair',

    [string]$RepairSource,

    [ValidateRange(10, 600)]
    [int]$DismTimeoutMinutes = 120,

    [ValidateRange(10, 600)]
    [int]$SfcTimeoutMinutes = 90,

    [ValidateRange(0, 3650)]
    [int]$RetainDays = 90,

    [switch]$IgnorePendingRestart,

    [switch]$NoPopup
)

# Error handling ($ErrorActionPreference = 'Stop') and strict mode are switched on at the
# start of Invoke-WindowsHealthMonitor (section 6), not here. Dot-sourcing runs this part of
# the file in the caller's own scope, so setting them here would also change the settings of
# a test, or of your own PowerShell window, that merely loads the script (2.5.0-dev.2).

# --------------------------------------------------------------------------------------------
#  Configuration
# --------------------------------------------------------------------------------------------

# Settings that never change during a run (section 2).
#  * Join-Path builds a file path safely, adding the "\" between the parts.
#  * $env:SystemRoot, $env:ProgramFiles and similar are Windows environment variables;
#    $env:SystemRoot is normally C:\Windows.
#  * The lock name starts with "Global\" so that every sign-in session shares one lock:
#    a scheduled run and a run in your own window cannot overlap.
$ScriptVersion = '2.5.0-dev.2'
# The layout version of Result.json. Raise it only when a field is renamed, removed or changes
# meaning, so that a program reading old and new reports can tell them apart.
$ResultSchemaVersion = 1
$EventSource   = 'WindowsHealthMonitor'
$MutexName     = 'Global\WindowsHealthMonitor-DISM-SFC'

# A 32-bit PowerShell host on 64-bit Windows sees System32 redirected to SysWOW64, and
# 32-bit DISM and SFC cannot service a 64-bit installation. Sysnative avoids the redirection.
$NativeSystemDir = if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Join-Path $env:SystemRoot 'Sysnative'
} else {
    Join-Path $env:SystemRoot 'System32'
}
$DismExe = Join-Path $NativeSystemDir 'Dism.exe'
$SfcExe  = Join-Path $NativeSystemDir 'sfc.exe'

# $PSScriptRoot is the folder that holds this .ps1 file, so the reports go in a "Logs"
# folder beside the script. Each run gets its own sub-folder named after its start time,
# for example Logs\2026-10-29_101120; that format also sorts the folders by date.
# Note the "if" used as a value: $x = if (test) { a } else { b } stores a or b in $x.
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Join-Path $env:ProgramData 'WindowsHealthMonitor' }
$LogRoot    = Join-Path $ScriptRoot 'Logs'
$RunStarted = Get-Date
$RunFolder  = Join-Path $LogRoot ($RunStarted.ToString('yyyy-MM-dd_HHmmss'))

$SummaryFile    = Join-Path $RunFolder 'Summary.txt'
$TranscriptFile = Join-Path $RunFolder 'Full-Transcript.txt'
$ResultFile     = Join-Path $RunFolder 'Result.json'
$CbsDetailsFile = Join-Path $RunFolder 'SFC-CBS-Details.txt'

# A hashtable that maps each DISM error code (written in hexadecimal) to plain-English
# advice. Get-DismHint looks codes up here; any other code gets general advice instead.
# Guidance for the DISM errors most often seen during /RestoreHealth.
$DismErrorHints = @{
    '0x800F081F' = 'DISM could not find the repair files. Supply a matching install.wim or install.esd with -RepairSource, or check that Windows Update is reachable.'
    '0x800F0906' = 'DISM could not download the repair files. Check the internet connection and that Windows Update is not paused.'
    '0x800F0907' = 'Group Policy stopped DISM contacting Windows Update. Supply -RepairSource, or review the policy "Specify settings for optional component installation and component repair".'
    '0x00000057' = 'DISM rejected a command-line option (error 87). Check the -RepairSource syntax.'
    '0x000006BE' = 'The remote procedure call failed (error 1726), usually because another servicing operation interfered. Restart Windows and run again.'
    '0x00000005' = 'Access was denied (error 5). Confirm that the task runs with highest privileges.'
}

# --------------------------------------------------------------------------------------------
#  Run state
# --------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------
#  Run state (section 3)
#  These variables collect everything a run learns. The $script: prefix keeps them in the
#  script's own scope, so every function reads and updates the same copy.
#
#    Outcome         The verdict: result code, severity and message. It starts as "failed"
#                    on purpose: if the script stops unexpectedly, the report says so rather
#                    than wrongly claiming success. Set-Outcome replaces it.
#    Steps           One entry per check (time, step, result), for Result.json.
#    ToolRuns        One entry per DISM or SFC run (exit code, duration, report file).
#    Notes           Observations worth reading that do not change the result code.
#    PowerShellInfo  Which PowerShell ran the script: 5.1 (Desktop) or 7 (Core).
#    State           The before-and-after results of DISM and SFC.
#
#  List[object] and List[string] are .NET lists that grow efficiently with .Add(). They
#  become plain arrays with .ToArray() when Result.json is written (see Save-ResultFile).
# --------------------------------------------------------------------------------------------
$script:Outcome = [pscustomobject]@{
    Code    = 1
    Type    = 'Error'
    Message = 'The health check stopped before it reached a result.'
}
$script:Steps             = New-Object System.Collections.Generic.List[object]
$script:ToolRuns          = New-Object System.Collections.Generic.List[object]
$script:Notes             = New-Object System.Collections.Generic.List[string]
$script:PowerShellInfo    = [ordered]@{
    Version = $PSVersionTable.PSVersion.ToString()
    Edition = $PSVersionTable.PSEdition
    Path    = $null
}
$script:State = [ordered]@{
    DismInitialState    = $null
    DismRepairAttempted = $false
    DismConfirmedState  = $null
    SfcInitialState     = $null
    SfcRepairAttempted  = $false
    SfcConfirmedState   = $null
    RestartRecommended  = $false
}
$script:PendingReasons    = @()
$script:FreeSpaceGB       = $null
$script:OsDescription     = $null
$script:SummaryAvailable  = $false

# --------------------------------------------------------------------------------------------
#  Helpers
# --------------------------------------------------------------------------------------------

# Write-Summary - the script's logging function. Every message goes to the screen and,
# once the report folder exists, is added to the end of Summary.txt with a time stamp.
# '{0}  {1}' -f $a, $b produces "$a  $b": here, the date and time, then the message.
function Write-Summary {
    param([Parameter(Mandatory)][string]$Text)
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Text
    if ($script:SummaryAvailable) {
        Add-Content -LiteralPath $SummaryFile -Value $line -Encoding UTF8
    }
    Write-Host $line
}

# Add-Step - records one finished check, e.g. "DISM /ScanHealth -> Healthy", for Result.json.
function Add-Step {
    param([string]$Step, [string]$Result, [string]$Detail)
    $script:Steps.Add([pscustomobject]@{
        Time   = (Get-Date).ToString('s')
        Step   = $Step
        Result = $Result
        Detail = $Detail
    })
}

# Set-Outcome - replaces the run's verdict. Every branch of the health check ends by calling
# this with a result code (see the table at the top), a severity and a message. The severity
# (Information, Warning or Error) also sets the Event Viewer level and the pop-up icon.
# Result code 2 (repaired) also marks a restart as recommended.
function Set-Outcome {
    param(
        [Parameter(Mandatory)][int]$Code,
        [Parameter(Mandatory)][ValidateSet('Information', 'Warning', 'Error')][string]$Type,
        [Parameter(Mandatory)][string]$Message
    )
    $script:Outcome = [pscustomobject]@{ Code = $Code; Type = $Type; Message = $Message }
    if ($Code -eq 2) { $script:State.RestartRecommended = $true }
    Write-Summary "OUTCOME [$Code]: $Message"
}

# Add-Note - records something worth reading that does not change the result code, such as
# a stale pending.xml or an unexpected SFC exit code. The final message counts the notes.
function Add-Note {
    # Records an observation that does not change the outcome but deserves attention.
    param([Parameter(Mandatory)][string]$Text)
    $script:Notes.Add($Text)
    Write-Summary "NOTE: $Text"
}

# Test-DismExitCode - DISM's exit code must show success before the script trusts its text.
# Returns $true for 0 (success) and 3010 (success, but Windows needs a restart).
function Test-DismExitCode {
    # DISM's success codes are 0 and 3010 (ERROR_SUCCESS_REBOOT_REQUIRED).
    param([Parameter(Mandatory)]$Run)
    if ($Run.ExitCode -eq 3010) {
        $script:State.RestartRecommended = $true
        Write-Summary "$($Run.Name) reports that Windows needs a restart (exit code 3010)."
    }
    return ($Run.ExitCode -eq 0 -or $Run.ExitCode -eq 3010)
}

# Test-SfcExitCode - SFC is judged by its message (see Get-SfcState); this only adds a note
# when the exit code is unexpectedly non-zero, so nothing unusual goes unrecorded.
function Test-SfcExitCode {
    # Microsoft does not document SFC's exit codes, so its message decides the result.
    # A non-zero code is still recorded prominently rather than ignored.
    param([Parameter(Mandatory)]$Run, [Parameter(Mandatory)][string]$State)
    if ($Run.ExitCode -ne 0) {
        Add-Note ("{0} returned exit code {1} alongside the result '{2}'. The script relies on SFC's message, because SFC's exit codes are undocumented; review {3} if the result looks wrong." -f
            $Run.Name, $Run.ExitCodeHex, $State, (Split-Path -Leaf $Run.OutputFile))
    }
}

# Get-ExitCodeHex - shows an exit code as 0x followed by 8 hexadecimal digits, the form that
# Microsoft's documentation uses (for example 0x800F081F).
# Why the BitConverter step? Exit codes are 32-bit values. Error codes such as 0x800F081F
# have their top bit set, so PowerShell receives them as NEGATIVE numbers (-2146498529).
# Converting a negative number straight to an unsigned one fails - the bug found in
# Copilot's version. GetBytes + ToUInt32 instead re-reads the same four bytes as an unsigned
# number, which always works.
function Get-ExitCodeHex {
    param([int]$Code)
    '0x{0:X8}' -f [BitConverter]::ToUInt32([BitConverter]::GetBytes($Code), 0)
}

# Get-DismHint - turns a DISM error code into advice, using the $DismErrorHints table.
function Get-DismHint {
    param([int]$Code)
    # A success code with an unrecognised message has no error code to look up.
    if ($Code -eq 0 -or $Code -eq 3010) {
        return "Review the DISM report file in the report folder, and $env:SystemRoot\Logs\DISM\dism.log."
    }
    $hex = Get-ExitCodeHex $Code
    if ($DismErrorHints.ContainsKey($hex)) { return $DismErrorHints[$hex] }
    return "Look up DISM error $hex, and check $env:SystemRoot\Logs\DISM\dism.log."
}

# ConvertFrom-ToolOutput - turns the raw bytes a tool printed into clean, readable text.
#
#  1. Work out the text encoding. Computers store text as numbers (bytes), and different
#     encodings store the same letters differently:
#         "Wi" in ASCII/OEM (DISM):    57 69
#         "Wi" in UTF-16LE  (SFC):     57 00 69 00    <- a zero byte after every letter
#     So the function counts zero bytes: many zeros at odd positions means UTF-16LE.
#     It also recognises a byte-order mark (BOM): a short marker some programs put at the
#     very start to announce the encoding.
#  2. Remove progress lines, such as "[====  10.0%  ]" and "Verification 5% complete".
#  3. Collapse the runs of blank lines that the progress updates leave behind.
function ConvertFrom-ToolOutput {
    <#
      SFC writes UTF-16LE when its output is redirected, whereas DISM writes in the OEM
      code page. Decoding SFC's bytes as OEM text yields a NUL between every character,
      so no text match ever succeeds. This detects the encoding from the bytes themselves,
      then strips progress-bar lines so that the saved files stay readable.
    #>
    param([byte[]]$Bytes)

    if ($null -eq $Bytes -or $Bytes.Length -eq 0) { return '' }

    $sample = [Math]::Min($Bytes.Length, 4096)
    $oddZeroes  = 0
    $evenZeroes = 0
    for ($i = 0; $i -lt $sample; $i++) {
        if ($Bytes[$i] -eq 0) {
            if ($i % 2) { $oddZeroes++ } else { $evenZeroes++ }
        }
    }

    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        $text = [Text.Encoding]::UTF8.GetString($Bytes, 3, $Bytes.Length - 3)
    } elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
        $text = [Text.Encoding]::Unicode.GetString($Bytes, 2, $Bytes.Length - 2)
    } elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) {
        $text = [Text.Encoding]::BigEndianUnicode.GetString($Bytes, 2, $Bytes.Length - 2)
    } elseif ($oddZeroes -gt ($sample / 4)) {
        $text = [Text.Encoding]::Unicode.GetString($Bytes)
    } elseif ($evenZeroes -gt ($sample / 4)) {
        $text = [Text.Encoding]::BigEndianUnicode.GetString($Bytes)
    } else {
        $oemCodePage = [Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage
        $text = [Text.Encoding]::GetEncoding($oemCodePage).GetString($Bytes)
    }

    $text = $text -replace "`0", '' -replace '^\uFEFF', ''

    # -split with a regular expression cuts the text into lines, whichever line ending was
    # used: Windows (CR LF), Unix (LF), or a bare CR, which DISM uses to redraw its progress
    # bar. Where-Object keeps only the lines for which the test in { } is true. In the tests:
    #   ^ and $        the start and end of the line
    #   \s* and \d+    any amount of white space / one or more digits
    #   (\.\d+)?       an optional decimal part, such as ".0"
    # so the first pattern means "a line that contains only something like [==== 12.3% ====]".
    $lines = $text -split "`r`n|`n|`r" | Where-Object {
        $_ -notmatch '^\s*\[[=\s]*\d+(\.\d+)?%[=\s]*\]\s*$' -and   # DISM progress bar
        $_ -notmatch '^\s*Verification\s+\d+% complete'              # SFC progress
    }

    # Each progress update leaves an empty line behind (over 100 for one DISM scan),
    # so collapse every run of blank lines into one.
    $clean = New-Object System.Collections.Generic.List[string]
    $previousBlank = $false
    foreach ($line in $lines) {
        $isBlank = [string]::IsNullOrWhiteSpace($line)
        if ($isBlank -and $previousBlank) { continue }
        $clean.Add($line.TrimEnd())
        $previousBlank = $isBlank
    }
    return ($clean.ToArray() -join [Environment]::NewLine).Trim()
}

function Format-Duration {
    # "48 s", "1 min 2 s" or "1 h 5 min": one decimal place of minutes hid the seconds.
    param([TimeSpan]$Span)
    $seconds = [int][Math]::Round($Span.TotalSeconds)
    if ($seconds -lt 60)   { return "$seconds s" }
    if ($seconds -lt 3600) { return '{0} min {1} s' -f [Math]::Floor($seconds / 60), ($seconds % 60) }
    return '{0} h {1} min' -f [Math]::Floor($seconds / 3600), [Math]::Floor(($seconds % 3600) / 60)
}

# Test-IsAdministrator - $true only when this PowerShell is running with administrator rights
# ("elevated"). DISM and SFC refuse to run without them.
#   WindowsIdentity   the Windows account running this process;
#   WindowsPrincipal  that account plus its group memberships, which IsInRole() checks.
# In an unelevated window, Windows hides the Administrators group from the process even for
# an administrator account, so IsInRole returns $false there - exactly the test needed.
# If the check itself fails, the answer is $false: refusing to run is the safe choice.
# It is a separate function so that a test can replace it with a stub.
function Test-IsAdministrator {
    try {
        $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Get-RunContext {
    # Who and what ran the script. Mainly useful for scheduled runs, which may run as
    # SYSTEM or another account, in session 0, or under a 32-bit host.
    $context = [ordered]@{
        User              = $null
        Is64BitProcess    = [Environment]::Is64BitProcess
        SessionId         = $null
        ScriptPath        = $PSCommandPath
    }
    try { $context.User = [Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { Write-Verbose 'User name unavailable.' }
    try { $context.SessionId = (Get-Process -Id $PID).SessionId } catch { Write-Verbose 'Session ID unavailable.' }
    return $context
}

# Invoke-Tool - runs DISM or SFC and captures everything it prints.
#
#  Rather than simply typing  & dism.exe /Online ...  it uses .NET's Process class, which
#  gives full control (the comment inside explains the two problems this avoids):
#
#    ProcessStartInfo   describes the program, its arguments and how to start it:
#                         UseShellExecute = $false   start it directly (needed to capture output)
#                         CreateNoWindow  = $true    no extra console window
#                         RedirectStandardOutput/Error = $true
#                                                    send its output to this script, not the screen
#    Start()            starts it.
#    CopyToAsync(...)   copies its output into memory IN THE BACKGROUND while it runs. This
#                       matters: if nobody reads a program's output, its output buffer fills
#                       up and the program freezes, waiting for space.
#    WaitForExit(ms)    waits up to the time limit; returns $false if the tool ran over.
#
#  If a tool runs over its limit, the script stops it AND the helper processes it started
#  (DISM starts DismHost.exe), keeps whatever output it had, and the caller reports code 7.
#  Finally it writes the tool's report file and returns an object describing the run.
function Invoke-Tool {
    <#
      Runs a native tool with a time limit and captures its raw output bytes.
      Using System.Diagnostics.Process avoids two Windows PowerShell 5.1 problems:
        * "& tool 2>&1" turns any standard-error line into a terminating error when
          $ErrorActionPreference is 'Stop'.
        * PowerShell decodes native output with the console code page, which garbles SFC.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$OutputFile,
        [Parameter(Mandatory)][int]$TimeoutMinutes
    )

    Write-Summary "Running $Name..."

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $FilePath
    # -join ' ' turns the array @('/Online', '/Cleanup-Image') into the single string
    # '/Online /Cleanup-Image', which is the form ProcessStartInfo expects.
    $psi.Arguments              = $ArgumentList -join ' '
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true

    $process      = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $stdout       = New-Object System.IO.MemoryStream
    $stderr       = New-Object System.IO.MemoryStream
    $started      = Get-Date
    $timedOut     = $false
    $stillRunning = $false

    # If Start() throws, the exception leaves this function through the finally block and
    # is reported by the main catch (result code 1), so nothing below can run unassigned.
    try {
        [void]$process.Start()
        $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)

        if (-not $process.WaitForExit($TimeoutMinutes * 60000)) {
            $timedOut = $true
            Write-Summary "$Name exceeded its $TimeoutMinutes-minute limit. Stopping it and its child processes."
            try {
                if ($PSVersionTable.PSEdition -eq 'Core') {
                    # PowerShell 7 (.NET) can stop the whole process tree, including DismHost.exe.
                    $process.Kill($true)
                } else {
                    Start-Process -FilePath (Join-Path $NativeSystemDir 'taskkill.exe') `
                        -ArgumentList "/PID $($process.Id) /T /F" -WindowStyle Hidden -Wait
                }
            }
            catch {
                Write-Summary "$Name could not be stopped cleanly: $($_.Exception.Message)"
            }
            if (-not $process.WaitForExit(60000)) {
                try { $process.Kill() } catch { Write-Verbose 'Kill() also failed.' }
                if (-not $process.WaitForExit(30000)) {
                    $stillRunning = $true
                    Add-Note "$Name (process ID $($process.Id)) is still running after the attempt to stop it. Restart Windows before the next run."
                }
            }
        }
        else {
            # The parameterless overload also waits for redirected output to drain.
            $process.WaitForExit()
        }
        [void]$outCopy.Wait(30000)
        [void]$errCopy.Wait(30000)

        # Whatever happened, keep the output captured so far.
        $exitCode  = if ($process.HasExited) { $process.ExitCode } else { -1 }
        $text      = ConvertFrom-ToolOutput -Bytes $stdout.ToArray()
        $errorText = ConvertFrom-ToolOutput -Bytes $stderr.ToArray()
    }
    finally {
        $process.Dispose()
        $stdout.Dispose()
        $stderr.Dispose()
    }

    $fileText = "Command: `"$FilePath`" $($psi.Arguments)" + [Environment]::NewLine +
                "Started: $($started.ToString('s'))   Exit code: $exitCode ($(Get-ExitCodeHex $exitCode))   Timed out: $timedOut   Still running: $stillRunning" +
                [Environment]::NewLine + [Environment]::NewLine + $text
    if ($errorText) {
        $fileText += [Environment]::NewLine + [Environment]::NewLine + '--- Standard error ---' + [Environment]::NewLine + $errorText
    }
    Set-Content -LiteralPath $OutputFile -Value $fileText -Encoding UTF8

    $elapsed = (Get-Date) - $started
    $run = [pscustomobject]@{
        Name            = $Name
        ExitCode        = $exitCode
        ExitCodeHex     = Get-ExitCodeHex $exitCode
        TimedOut        = $timedOut
        StillRunning    = $stillRunning
        DurationSeconds = [int][Math]::Round($elapsed.TotalSeconds)
        OutputFile      = $OutputFile
        Text            = $text
    }
    # Select-Object keeps only the listed properties, so the full output text stays out of
    # Result.json (it is already saved in the tool's own report file).
    $script:ToolRuns.Add(($run | Select-Object Name, ExitCode, ExitCodeHex, TimedOut, StillRunning, DurationSeconds, OutputFile))
    Write-Summary "$Name finished in $(Format-Duration $elapsed) with exit code $exitCode ($($run.ExitCodeHex))."
    return $run
}

# Get-DismScanState and Get-SfcState - read a tool's message and reduce it to one word.
# -match tests a regular expression; here the patterns are plain phrases. ORDER MATTERS:
# "No component store corruption detected" is tested first, because a looser test for
# "corruption detected" would also match the healthy message and raise a false alarm.
# DISM runs with /English, so its phrases match on any language of Windows. SFC has no such
# option: on a non-English Windows its results would show as "not recognised" (code 5).
function Get-DismScanState {
    param([string]$Text)
    if ($Text -match 'No component store corruption detected') { return 'Healthy' }
    if ($Text -match 'component store cannot be repaired')     { return 'NotRepairable' }
    if ($Text -match 'component store is repairable')          { return 'Repairable' }
    return 'Unknown'
}

function Get-SfcState {
    param([string]$Text)
    if ($Text -match 'system repair pending which requires reboot')   { return 'RestartPending' }
    if ($Text -match 'could not start the repair service')            { return 'ServiceFailed' }
    if ($Text -match 'could not perform the requested operation')     { return 'CouldNotRun' }
    if ($Text -match 'unable to fix some of them')                    { return 'PartiallyRepaired' }
    if ($Text -match 'successfully repaired')                         { return 'Repaired' }
    if ($Text -match 'did not find any integrity violations')         { return 'Clean' }
    if ($Text -match 'found integrity violations')                    { return 'ViolationsFound' }
    return 'Unknown'
}

# Get-RestoreHealthArgument - the command-line options for DISM /RestoreHealth.
# With a -Source, DISM takes its repair files from that installation image, and /LimitAccess
# stops it contacting Windows Update. The source is put in double quotes so that a path
# containing spaces reaches DISM as one option. The source is passed in as a parameter,
# rather than read from $RepairSource, so a test can check every case directly.
function Get-RestoreHealthArgument {
    param([string]$Source)
    $arguments = @('/Online', '/Cleanup-Image', '/RestoreHealth', '/English')
    if ($Source) {
        $arguments += "/Source:`"$Source`""
        $arguments += '/LimitAccess'
    }
    return $arguments
}

# Format-Size and Format-DriveSpace - build the free-space line in the summary, using the
# same units as File Explorer (1 GB here = 1,073,741,824 bytes).
function Format-Size {
    # Sizes use the same binary units as File Explorer, so the figures match what it shows.
    param([double]$Bytes)
    if ($Bytes -ge 1TB) { return '{0:N2} TB' -f ($Bytes / 1TB) }
    return '{0:N1} GB' -f ($Bytes / 1GB)
}

function Format-DriveSpace {
    # Records the drive figures for Result.json and returns a one-line description.
    param([string]$Drive, [double]$FreeBytes, [double]$TotalBytes)

    $freePercent = [Math]::Round(100 * $FreeBytes / $TotalBytes, 1)
    $script:FreeSpaceGB = [ordered]@{
        Drive       = $Drive
        FreeGB      = [Math]::Round($FreeBytes / 1GB, 1)
        TotalGB     = [Math]::Round($TotalBytes / 1GB, 1)
        FreePercent = $freePercent
    }

    $line = 'Windows drive ({0}) has {1} free of {2} ({3}% free).' -f
        $Drive, (Format-Size $FreeBytes), (Format-Size $TotalBytes), $freePercent.ToString('0.0')
    if ($FreeBytes -lt 10GB) {
        return "$line WARNING: DISM needs several GB of working space for repairs, so a repair may fail. Free up space first."
    }
    return "$line That is plenty of working space for DISM repairs."
}

# Get-PendingRestartReason - checks whether Windows is waiting for a restart. DISM and SFC
# give unreliable results while servicing work is queued, so such a run is skipped (code 6).
#   Test-Path 'HKLM:\...'  checks whether a registry key exists. HKLM: is a PowerShell
#                          "drive" for HKEY_LOCAL_MACHINE, so the registry can be browsed
#                          like folders. These two keys exist only while a restart is due.
#   WinSxS\pending.xml     lists servicing work queued for the next restart.
# It deliberately ignores "PendingFileRenameOperations", a registry value that many
# installers leave behind for good - checking it would skip every run.
function Get-PendingRestartReason {
    $reasons = @()
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $reasons += 'Component Based Servicing reports a pending restart'
    }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $reasons += 'Windows Update reports a pending restart'
    }

    # pending.xml written since the last restart means servicing work is genuinely queued.
    # One that survived a restart is stale: blocking on it would skip every run for ever,
    # so record it instead (a stale pending.xml is itself a known cause of repair failures).
    $pendingXml = Join-Path $env:SystemRoot 'WinSxS\pending.xml'
    if (Test-Path -LiteralPath $pendingXml) {
        try {
            $lastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
            $written  = (Get-Item -LiteralPath $pendingXml -Force).LastWriteTime
            if ($written -gt $lastBoot) {
                $reasons += 'servicing operations were queued in WinSxS\pending.xml after the last restart'
            }
            else {
                Add-Note ("WinSxS\pending.xml dates from {0:yyyy-MM-dd HH:mm}, before the last restart ({1:yyyy-MM-dd HH:mm}). A pending.xml that survives a restart can stop DISM and SFC from repairing; if repairs fail, this is a likely cause." -f $written, $lastBoot)
            }
        }
        catch {
            Add-Note "WinSxS\pending.xml exists, but its age could not be checked: $($_.Exception.Message)"
        }
    }

    # A pending computer rename needs a restart but does not affect servicing.
    try {
        $activeName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -Name ComputerName).ComputerName
        $targetName = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -Name ComputerName).ComputerName
        if ($activeName -ne $targetName) {
            Add-Note "A computer rename from '$activeName' to '$targetName' is waiting for a restart. It does not affect DISM or SFC."
        }
    }
    catch {
        Write-Verbose "Computer-name check skipped: $($_.Exception.Message)"
    }

    return $reasons
}

# Export-CbsSrLine - copies SFC's own lines (marked [SR]) from Windows' servicing log,
# C:\Windows\Logs\CBS\CBS.log, but only those written during this run.
function Export-CbsSrLine {
    <#
      Copies only the [SR] lines that SFC wrote during this run. The whole CBS.log can
      span weeks, so exporting every [SR] line would mix in results from earlier runs.
      The file is opened with full sharing because TrustedInstaller may still have it open.
    #>
    param([Parameter(Mandatory)][datetime]$Since, [Parameter(Mandatory)][string]$Destination)

    $cbsLog = Join-Path $env:SystemRoot 'Logs\CBS\CBS.log'
    if (-not (Test-Path -LiteralPath $cbsLog)) { return 0 }

    $threshold = $Since.AddSeconds(-5)
    $culture   = [Globalization.CultureInfo]::InvariantCulture
    $count     = 0
    $stream    = [IO.File]::Open($cbsLog, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]'ReadWrite, Delete')
    $reader    = New-Object IO.StreamReader($stream)
    $writer    = New-Object IO.StreamWriter($Destination, $false, (New-Object Text.UTF8Encoding($true)))
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($line.Length -lt 19 -or $line.IndexOf('[SR]', [StringComparison]::Ordinal) -lt 0) { continue }
            $stamp = [datetime]::MinValue
            if ([datetime]::TryParseExact($line.Substring(0, 19), 'yyyy-MM-dd HH:mm:ss', $culture,
                    [Globalization.DateTimeStyles]::None, [ref]$stamp) -and $stamp -ge $threshold) {
                $writer.WriteLine($line)
                $count++
            }
        }
    }
    finally {
        $writer.Dispose()
        $reader.Dispose()
        $stream.Dispose()
    }
    return $count
}

# Remove-OldRunFolder - deletes report folders older than -RetainDays (90 by default). It
# only touches folders whose names are dates in this script's format, so nothing else in
# the Logs folder is ever deleted. TryParseExact returns $true or $false, and hands back the
# date it read through [ref]$stamp (a "reference": the function fills in the variable).
function Remove-OldRunFolder {
    if ($RetainDays -eq 0 -or -not (Test-Path -LiteralPath $LogRoot)) { return }
    $cutoff  = (Get-Date).AddDays(-$RetainDays)
    $removed = 0
    foreach ($folder in Get-ChildItem -LiteralPath $LogRoot -Directory) {
        $stamp = [datetime]::MinValue
        if ([datetime]::TryParseExact($folder.Name, 'yyyy-MM-dd_HHmmss', [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::None, [ref]$stamp) -and $stamp -lt $cutoff) {
            try {
                Remove-Item -LiteralPath $folder.FullName -Recurse -Force
                $removed++
            }
            catch {
                Write-Summary "Could not remove old report folder $($folder.Name): $($_.Exception.Message)"
            }
        }
    }
    if ($removed -gt 0) { Write-Summary "Removed $removed report folder(s) older than $RetainDays days." }
}

# Write-HealthEvent - records the result in Event Viewer > Windows Logs > Application, under
# the source "WindowsHealthMonitor", with event ID 1000 + result code (1000 = healthy).
# The first run registers the source, which needs administrator rights. If writing fails,
# the script logs the problem and carries on.
function Write-HealthEvent {
    param([int]$EventId, [string]$EntryType, [string]$Message)
    try {
        if (-not [Diagnostics.EventLog]::SourceExists($EventSource)) {
            [Diagnostics.EventLog]::CreateEventSource($EventSource, 'Application')
        }
        [Diagnostics.EventLog]::WriteEntry($EventSource, $Message,
            [Diagnostics.EventLogEntryType]$EntryType, $EventId)
    }
    catch {
        Write-Summary "Could not write to the Application event log: $($_.Exception.Message)"
    }
}

# Show-ResultPopup - a message box that closes itself after 60 seconds. WScript.Shell is a
# COM object (an older Windows component) that PowerShell can use via New-Object -ComObject.
# Session 0 is where services and "run whether user is logged on or not" tasks run. It has
# no visible desktop, so the script does not try to show a pop-up there.
function Show-ResultPopup {
    param([string]$Title, [string]$Message, [string]$Type)

    # Session 0 has no visible desktop; a pop-up there would only wait for its timeout.
    if ($NoPopup -or (Get-Process -Id $PID).SessionId -eq 0) { return }

    $icon = switch ($Type) { 'Error' { 16 } 'Warning' { 48 } default { 64 } }
    try {
        $shell = New-Object -ComObject WScript.Shell
        [void]$shell.Popup($Message, 60, $Title, $icon)
    }
    catch {
        Write-Summary "The pop-up could not be displayed: $($_.Exception.Message)"
    }
}

# Save-ResultFile - gathers everything into one ordered table and writes it as Result.json.
# JSON is a plain-text data format that programs - and Claude - can read reliably.
# -Depth 5 tells ConvertTo-Json how many levels of nesting to include; the default would
# cut off the inner tables.
function Save-ResultFile {
    $finished = Get-Date
    $result = [ordered]@{
        Tool                  = 'Windows Health Monitor'
        SchemaVersion         = $ResultSchemaVersion
        ScriptVersion        = $ScriptVersion
        Computer              = $env:COMPUTERNAME
        OperatingSystem       = $script:OsDescription
        Started               = $RunStarted.ToString('s')
        Finished              = $finished.ToString('s')
        DurationSeconds       = [int][Math]::Round(($finished - $RunStarted).TotalSeconds)
        RunContext            = Get-RunContext
        PowerShell            = $script:PowerShellInfo
        ExitCode              = $script:Outcome.Code
        Severity              = $script:Outcome.Type
        Message               = $script:Outcome.Message
        Parameters            = [ordered]@{
            SfcMode              = $SfcMode
            RepairSource         = $RepairSource
            IgnorePendingRestart = [bool]$IgnorePendingRestart
        }
        RestartRecommended    = $script:State.RestartRecommended
        State                 = $script:State
        PendingRestartReasons = @($script:PendingReasons)
        # .ToArray() rather than @(): wrapping a generic List[object] in @() throws
        # "Argument types do not match" in Windows PowerShell 5.1 and PowerShell 7.
        Notes                 = $script:Notes.ToArray()
        WindowsDrive          = $script:FreeSpaceGB
        Steps                 = $script:Steps.ToArray()
        ToolRuns              = $script:ToolRuns.ToArray()
        ReportFolder          = $RunFolder
    }
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ResultFile -Encoding UTF8
}

# --------------------------------------------------------------------------------------------
#  Health check
# --------------------------------------------------------------------------------------------

# The health check (section 5). Invoke-HealthCheck runs the steps in order and stops at the
# first definite result ("return" leaves the function immediately). Every path ends with
# exactly one Set-Outcome call, so every run has exactly one verdict.
#
#   DISM /ScanHealth  -> Healthy ............. go on to SFC
#                     -> Repairable .......... DISM /RestoreHealth, then /ScanHealth again
#                                              to CONFIRM, then SFC /scannow
#                     -> Not repairable ...... stop: code 3
#   SFC /verifyonly   -> Clean ............... code 0 (healthy)
#                     -> Violations found .... SFC /scannow, then /verifyonly to CONFIRM
#
# The rule throughout: a repair only counts once a SECOND scan confirms it.
#
# Invoke-SfcScannow - runs the repairing scan (sfc /scannow), saves SFC's log lines and,
# if SFC says it repaired files, confirms the repair with sfc /verifyonly.
function Invoke-SfcScannow {
    param([bool]$AfterDismRepair)

    $script:State.SfcRepairAttempted = $true
    $sfcStarted = Get-Date
    $scannow = Invoke-Tool -Name 'SFC /scannow' -FilePath $SfcExe -ArgumentList @('/scannow') `
        -OutputFile (Join-Path $RunFolder '5-SFC-Scannow.txt') -TimeoutMinutes $SfcTimeoutMinutes

    try {
        $srLines = Export-CbsSrLine -Since $sfcStarted -Destination $CbsDetailsFile
        Write-Summary "Saved $srLines CBS.log [SR] line(s) from this SFC run."
    }
    catch {
        Write-Summary "Could not extract the [SR] lines from CBS.log: $($_.Exception.Message)"
    }

    if ($scannow.TimedOut) {
        Set-Outcome -Code 7 -Type Error -Message "SFC /scannow did not finish within $SfcTimeoutMinutes minutes and was stopped."
        return
    }

    $state = Get-SfcState $scannow.Text
    if ($null -eq $script:State.SfcInitialState) { $script:State.SfcInitialState = $state }
    $script:State.SfcConfirmedState = $state
    Add-Step -Step 'SFC /scannow' -Result $state -Detail "Exit code $($scannow.ExitCodeHex)"
    Write-Summary "SFC /scannow result: $state."
    Test-SfcExitCode -Run $scannow -State $state

    switch ($state) {
        'Clean' {
            if ($AfterDismRepair) {
                Set-Outcome -Code 2 -Type Warning -Message 'DISM repaired the component store and a second scan confirmed it is healthy. SFC found no integrity violations. Restart Windows when convenient.'
            } else {
                Set-Outcome -Code 0 -Type Information -Message 'No problems found. The component store is healthy and SFC found no integrity violations.'
            }
            return
        }
        'Repaired' {
            Write-Summary 'SFC reports repairs. Running SFC /verifyonly to confirm them.'
            $confirm = Invoke-Tool -Name 'SFC /verifyonly (confirmation)' -FilePath $SfcExe -ArgumentList @('/verifyonly') `
                -OutputFile (Join-Path $RunFolder '6-SFC-VerifyOnly-Confirm.txt') -TimeoutMinutes $SfcTimeoutMinutes
            if ($confirm.TimedOut) {
                Set-Outcome -Code 7 -Type Error -Message "SFC repaired files, but the confirmation scan did not finish within $SfcTimeoutMinutes minutes."
                return
            }
            $confirmState = Get-SfcState $confirm.Text
            $script:State.SfcConfirmedState = $confirmState
            Add-Step -Step 'SFC /verifyonly (confirmation)' -Result $confirmState -Detail "Exit code $($confirm.ExitCodeHex)"
            Test-SfcExitCode -Run $confirm -State $confirmState
            switch ($confirmState) {
                'Clean' {
                    Set-Outcome -Code 2 -Type Warning -Message 'SFC found corrupt system files and repaired them; a confirmation scan found no remaining violations. Restart Windows when convenient.'
                }
                'RestartPending' {
                    Set-Outcome -Code 2 -Type Warning -Message 'SFC repaired system files, but Windows must restart to finish some repairs. Restart Windows; the next run will confirm the result.'
                }
                default {
                    Set-Outcome -Code 4 -Type Error -Message "SFC reported repairs, but the confirmation scan still reports '$confirmState'. Review SFC-CBS-Details.txt."
                }
            }
            return
        }
        'PartiallyRepaired' {
            Set-Outcome -Code 4 -Type Error -Message 'SFC found corrupt files but could not repair some of them. Review SFC-CBS-Details.txt for the "Cannot repair member file" lines.'
            return
        }
        'RestartPending' {
            Set-Outcome -Code 6 -Type Warning -Message 'SFC reports a system repair waiting for a restart. Restart Windows and run the check again.'
            return
        }
        'ServiceFailed' {
            Set-Outcome -Code 4 -Type Error -Message 'SFC could not start the Windows Modules Installer service (TrustedInstaller). Check that the service is not disabled; its normal start type is Manual.'
            return
        }
        'CouldNotRun' {
            Set-Outcome -Code 4 -Type Error -Message 'SFC could not perform the requested operation. Restart Windows and run again; if it persists, run SFC from Safe Mode.'
            return
        }
        default {
            Set-Outcome -Code 5 -Type Warning -Message "SFC /scannow finished, but its result was not recognised (exit code $($scannow.ExitCodeHex)). Review 5-SFC-Scannow.txt."
            return
        }
    }
}

function Invoke-HealthCheck {

    # ---- Pre-flight ------------------------------------------------------------------------

    $script:PendingReasons = @(Get-PendingRestartReason)
    if ($script:PendingReasons.Count -gt 0) {
        foreach ($reason in $script:PendingReasons) { Write-Summary "Pending restart: $reason." }
        if (-not $IgnorePendingRestart) {
            Add-Step -Step 'Pre-flight' -Result 'RestartPending' -Detail ($script:PendingReasons -join '; ')
            Set-Outcome -Code 6 -Type Warning -Message 'Windows has a restart pending, so the checks were skipped. Restart Windows and run the check again.'
            return
        }
        Write-Summary 'Continuing because -IgnorePendingRestart was specified. Results may be unreliable.'
    }

    try {
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
        if ($null -eq $disk -or -not $disk.Size) { throw "Windows returned no size for drive $env:SystemDrive." }
        Write-Summary (Format-DriveSpace -Drive $env:SystemDrive -FreeBytes $disk.FreeSpace -TotalBytes $disk.Size)
    }
    catch {
        Write-Summary "The free space on the Windows drive could not be read: $($_.Exception.Message)"
    }

    # ---- Step 1: DISM ScanHealth -----------------------------------------------------------

    $scan = Invoke-Tool -Name 'DISM /ScanHealth' -FilePath $DismExe `
        -ArgumentList @('/Online', '/Cleanup-Image', '/ScanHealth', '/English') `
        -OutputFile (Join-Path $RunFolder '1-DISM-ScanHealth.txt') -TimeoutMinutes $DismTimeoutMinutes

    if ($scan.TimedOut) {
        Set-Outcome -Code 7 -Type Error -Message "DISM /ScanHealth did not finish within $DismTimeoutMinutes minutes and was stopped."
        return
    }

    $storeState = Get-DismScanState $scan.Text
    $script:State.DismInitialState   = $storeState
    $script:State.DismConfirmedState = $storeState
    Add-Step -Step 'DISM /ScanHealth' -Result $storeState -Detail "Exit code $($scan.ExitCodeHex)"
    Write-Summary "Component store state: $storeState."

    # The exit code must be a success code before the text is trusted. A failing DISM run
    # that happens to contain a recognisable phrase must not count as a clean result.
    if (-not (Test-DismExitCode -Run $scan)) {
        Set-Outcome -Code 5 -Type Error -Message "DISM /ScanHealth failed with exit code $($scan.ExitCodeHex). $(Get-DismHint $scan.ExitCode)"
        return
    }

    $dismRepaired = $false

    # switch compares $storeState with each label and runs the block that matches; "default"
    # catches anything else, i.e. a result the script does not recognise.
    switch ($storeState) {
        'Healthy' { }

        'NotRepairable' {
            Set-Outcome -Code 3 -Type Error -Message 'DISM reports that the component store cannot be repaired. Run the script with -RepairSource pointing to matching installation media, or use Settings > System > Recovery > "Fix problems using Windows Update".'
            return
        }

        'Repairable' {
            # ---- Step 2: DISM RestoreHealth --------------------------------------------------
            $script:State.DismRepairAttempted = $true
            $restoreArgs = Get-RestoreHealthArgument -Source $RepairSource
            $restore = Invoke-Tool -Name 'DISM /RestoreHealth' -FilePath $DismExe -ArgumentList $restoreArgs `
                -OutputFile (Join-Path $RunFolder '2-DISM-RestoreHealth.txt') -TimeoutMinutes $DismTimeoutMinutes

            if ($restore.TimedOut) {
                Set-Outcome -Code 7 -Type Error -Message "DISM /RestoreHealth did not finish within $DismTimeoutMinutes minutes and was stopped."
                return
            }

            $restoreReported = (Test-DismExitCode -Run $restore) -and
                               ($restore.Text -match 'restore operation completed successfully')
            Add-Step -Step 'DISM /RestoreHealth' -Result $(if ($restoreReported) { 'ReportedSuccess' } else { 'Failed' }) `
                -Detail "Exit code $($restore.ExitCodeHex)"

            if (-not $restoreReported) {
                Set-Outcome -Code 3 -Type Error -Message "DISM /RestoreHealth failed with exit code $($restore.ExitCodeHex). $(Get-DismHint $restore.ExitCode)"
                return
            }

            # ---- Step 3: confirm the repair --------------------------------------------------
            Write-Summary 'DISM reports a successful repair. Running a second scan to confirm it.'
            $verify = Invoke-Tool -Name 'DISM /ScanHealth (confirmation)' -FilePath $DismExe `
                -ArgumentList @('/Online', '/Cleanup-Image', '/ScanHealth', '/English') `
                -OutputFile (Join-Path $RunFolder '3-DISM-ScanHealth-Confirm.txt') -TimeoutMinutes $DismTimeoutMinutes

            if ($verify.TimedOut) {
                Set-Outcome -Code 7 -Type Error -Message "DISM repaired the store, but the confirmation scan did not finish within $DismTimeoutMinutes minutes."
                return
            }

            $verifyState = Get-DismScanState $verify.Text
            $script:State.DismConfirmedState = $verifyState
            Add-Step -Step 'DISM /ScanHealth (confirmation)' -Result $verifyState -Detail "Exit code $($verify.ExitCodeHex)"
            if (-not (Test-DismExitCode -Run $verify)) {
                Set-Outcome -Code 5 -Type Error -Message "DISM repaired the store, but the confirmation scan failed with exit code $($verify.ExitCodeHex). $(Get-DismHint $verify.ExitCode)"
                return
            }
            if ($verifyState -ne 'Healthy') {
                Set-Outcome -Code 3 -Type Error -Message "DISM reported a successful repair, but the confirmation scan reports '$verifyState'. Review 3-DISM-ScanHealth-Confirm.txt."
                return
            }

            Write-Summary 'Confirmed: the component store is now healthy.'
            $dismRepaired = $true
        }

        default {
            Set-Outcome -Code 5 -Type Warning -Message "DISM /ScanHealth finished with exit code $($scan.ExitCodeHex), but its result was not recognised. $(Get-DismHint $scan.ExitCode)"
            return
        }
    }

    # ---- Step 4: SFC -----------------------------------------------------------------------

    # Which SFC scan? After a DISM repair, or with -SfcMode AlwaysRepair, go straight to the
    # repairing scan. Otherwise start with the read-only /verifyonly, which changes nothing.
    if ($dismRepaired -or $SfcMode -eq 'AlwaysRepair') {
        Invoke-SfcScannow -AfterDismRepair $dismRepaired
        return
    }

    if ($SfcMode -eq 'AfterDismRepairOnly') {
        Add-Step -Step 'SFC' -Result 'Skipped' -Detail 'SfcMode AfterDismRepairOnly'
        Set-Outcome -Code 0 -Type Information -Message 'No component store corruption detected. SFC was not run (-SfcMode AfterDismRepairOnly).'
        return
    }

    $sfcVerify = Invoke-Tool -Name 'SFC /verifyonly' -FilePath $SfcExe -ArgumentList @('/verifyonly') `
        -OutputFile (Join-Path $RunFolder '4-SFC-VerifyOnly.txt') -TimeoutMinutes $SfcTimeoutMinutes

    if ($sfcVerify.TimedOut) {
        Set-Outcome -Code 7 -Type Error -Message "SFC /verifyonly did not finish within $SfcTimeoutMinutes minutes and was stopped."
        return
    }

    $sfcState = Get-SfcState $sfcVerify.Text
    $script:State.SfcInitialState   = $sfcState
    $script:State.SfcConfirmedState = $sfcState
    Add-Step -Step 'SFC /verifyonly' -Result $sfcState -Detail "Exit code $($sfcVerify.ExitCodeHex)"
    Write-Summary "SFC /verifyonly result: $sfcState."
    Test-SfcExitCode -Run $sfcVerify -State $sfcState

    switch ($sfcState) {
        'Clean' {
            Set-Outcome -Code 0 -Type Information -Message 'No problems found. The component store is healthy and SFC found no integrity violations.'
        }
        'ViolationsFound' {
            Write-Summary 'SFC found integrity violations. Running SFC /scannow to repair them.'
            Invoke-SfcScannow -AfterDismRepair $false
        }
        'RestartPending' {
            Set-Outcome -Code 6 -Type Warning -Message 'SFC reports a system repair waiting for a restart. Restart Windows and run the check again.'
        }
        'ServiceFailed' {
            Set-Outcome -Code 4 -Type Error -Message 'SFC could not start the Windows Modules Installer service (TrustedInstaller). Check that the service is not disabled; its normal start type is Manual.'
        }
        'CouldNotRun' {
            Set-Outcome -Code 4 -Type Error -Message 'SFC could not perform the requested operation. Restart Windows and run again; if it persists, run SFC from Safe Mode.'
        }
        default {
            Set-Outcome -Code 5 -Type Warning -Message "SFC /verifyonly finished, but its result was not recognised (exit code $($sfcVerify.ExitCodeHex)). Review 4-SFC-VerifyOnly.txt."
        }
    }
}

# --------------------------------------------------------------------------------------------
#  Main (section 6)
# --------------------------------------------------------------------------------------------

# Invoke-WindowsHealthMonitor - THE WHOLE RUN (section 6). Everything above only defines
# settings and functions; this function uses them, and section 7 calls it.
#
# Until version 2.4.0 this code sat loose at the end of the file, so loading the file always
# started a health check. As a function it runs only when called, which lets tests load the
# script without running DISM or SFC (version 2.5, stage 1). It does not call "exit": it
# leaves the result in $script:Outcome and returns, and section 7 turns that into the exit
# code. An "exit" here would also close a test session that called the function.
#
# A mutex is a lock provided by Windows: only one process can hold it at a time. If a second
# copy starts while one is running, it finds the lock taken and stops with code 10, rather
# than running DISM twice at once. "Abandoned" means the previous holder was stopped without
# releasing it; the lock then passes to this run, which is safe.
function Invoke-WindowsHealthMonitor {

    # Two safety settings for the whole run. They are set here, at the start of the run, so
    # that merely loading the script changes nothing in the caller (see the note at the top
    # of the file). Every function called from here still uses them: a function sees the
    # variables and strict mode of whatever called it, and they end when this function ends.
    #  * $ErrorActionPreference = 'Stop' makes every error stop the current step and jump to
    #    the nearest catch block, instead of printing a message and carrying on with bad data.
    #    The try/catch/finally blocks throughout the script rely on this.
    #  * Set-StrictMode -Version 2.0 makes PowerShell refuse to use a variable that was never
    #    set, or a property that does not exist, instead of quietly treating it as empty.
    #    That turns typing mistakes into clear errors rather than hidden wrong results.
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version 2.0

    # Administrator rights first, as "#requires -RunAsAdministrator" did until 2.4.0: without
    # them nothing else can work, so stop at once with code 1 and say why. No reports are
    # written, because creating the report folder or the event source may itself need the
    # rights that are missing.
    if (-not (Test-IsAdministrator)) {
        $script:Outcome = [pscustomobject]@{
            Code    = 1
            Type    = 'Error'
            Message = 'Windows Health Monitor needs administrator rights, because DISM and SFC do. Open PowerShell with "Run as administrator", or set the scheduled task to "Run with highest privileges".'
        }
        Write-Host $script:Outcome.Message
        return
    }

    # Single-instance lock. Opening without initial ownership and then waiting for zero
    # milliseconds also recovers a lock abandoned by a run that was killed.
    $mutex   = New-Object System.Threading.Mutex($false, $MutexName)
    $hasLock = $false
    try {
        $hasLock = $mutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        $hasLock = $true
    }

    if (-not $hasLock) {
        $mutex.Dispose()
        $script:Outcome = [pscustomobject]@{
            Code    = 10
            Type    = 'Information'
            Message = 'Another Windows Health Monitor run is already in progress, so this run was skipped.'
        }
        Write-Host $script:Outcome.Message
        Write-HealthEvent -EventId 1010 -EntryType 'Information' -Message $script:Outcome.Message
        return
    }

    try {
        # | Out-Null discards a command's output so that it does not appear on screen.
        New-Item -ItemType Directory -Path $RunFolder -Force | Out-Null
        $script:SummaryAvailable = $true

        try { Start-Transcript -LiteralPath $TranscriptFile -Force | Out-Null }
        catch { Write-Summary "The transcript could not be started: $($_.Exception.Message)" }

        try {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem
            $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
            $script:OsDescription = '{0} {1}, build {2}.{3}' -f $os.Caption, $cv.DisplayVersion, $cv.CurrentBuild, $cv.UBR
        }
        catch {
            $script:OsDescription = [Environment]::OSVersion.VersionString
        }

        Write-Summary "Windows Health Monitor $ScriptVersion started on $env:COMPUTERNAME ($($script:OsDescription))."
        Write-Summary "SFC mode: $SfcMode. Reports: $RunFolder"

        # Record which PowerShell is running the script. Nothing is downloaded or installed.
        try { $script:PowerShellInfo.Path = (Get-Process -Id $PID).Path }
        catch { Write-Verbose 'The PowerShell path could not be read.' }
        $editionName = if ($script:PowerShellInfo.Edition -eq 'Core') { 'PowerShell' } else { 'Windows PowerShell' }
        Write-Summary "PowerShell: $editionName $($script:PowerShellInfo.Version) ($($script:PowerShellInfo.Path))."

        Remove-OldRunFolder
        Invoke-HealthCheck
    }
    # Any error not handled elsewhere lands here and becomes result code 1, with its line number.
    catch {
        Set-Outcome -Code 1 -Type Error -Message "The script failed at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    }
    # finally runs whatever happened above - success, a problem found, or an unexpected error -
    # so the summary, Result.json, Event Viewer entry and lock release always happen.
    finally {
        if ($script:State.RestartRecommended -and $script:Outcome.Message -notmatch 'restart') {
            $script:Outcome.Message += ' Windows also reports that a restart is required.'
        }
        if ($script:Notes.Count -gt 0) {
            $script:Outcome.Message += " See the $($script:Notes.Count) note(s) in Summary.txt."
        }

        Write-Summary "Finished in $(Format-Duration ((Get-Date) - $RunStarted)) with result code $($script:Outcome.Code)."

        try { Save-ResultFile }
        catch { Write-Summary "Result.json could not be written: $($_.Exception.Message)" }

        try { Stop-Transcript | Out-Null }
        catch { Write-Verbose 'No transcript was running.' }

        $eventMessage = "$($script:Outcome.Message)`r`n`r`nResult code: $($script:Outcome.Code)`r`nReport folder: $RunFolder"
        Write-HealthEvent -EventId (1000 + $script:Outcome.Code) -EntryType $script:Outcome.Type -Message $eventMessage

        # Release the lock before the pop-up, which can wait up to 60 seconds.
        try { $mutex.ReleaseMutex() }
        catch { Write-Verbose "The lock could not be released: $($_.Exception.Message)" }
        $mutex.Dispose()

        Show-ResultPopup -Title 'Windows health check' `
            -Message "$($script:Outcome.Message)`n`nReport: $SummaryFile" -Type $script:Outcome.Type
    }
}

# --------------------------------------------------------------------------------------------
#  Start (section 7)
# --------------------------------------------------------------------------------------------

# THIS IS WHERE THE SCRIPT STARTS DOING THINGS.
#
# $MyInvocation describes how this script was started. Its InvocationName is the word or
# path that started it: the script's path with "pwsh -File", "&" with the call operator, and
# a single dot "." when the script is DOT-SOURCED:
#
#     . .\WindowsHealthMonitor.ps1      <- note the dot and the space before the path
#
# Dot-sourcing runs a script in the caller's own scope, so its functions and variables stay
# available afterwards. Tests use it to load every function without starting a health
# check, then call the functions one at a time. Any other way of starting the script runs
# the health check as normal.
#
# The result code becomes the program's exit code, which Task Scheduler shows as
# "Last Run Result" (0x0 when healthy).
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WindowsHealthMonitor
    exit $script:Outcome.Code
}
