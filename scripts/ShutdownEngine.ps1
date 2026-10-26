$ErrorActionPreference = 'SilentlyContinue'

function Show-Header([string]$Text, [string]$Color = 'Cyan') {
    Clear-Host
    Write-Host ''
    Write-Host ('=' * 64) -ForegroundColor $Color
    Write-Host ('  ' + $Text) -ForegroundColor $Color
    Write-Host ('=' * 64) -ForegroundColor $Color
    Write-Host ''
}

function Test-AnyKey {
    if ([Console]::KeyAvailable) { return $true }
    for ($vk = 8; $vk -le 254; $vk++) {
        if (([Native.Keys]::GetAsyncKeyState($vk) -band 0x8000) -ne 0) { return $true }
    }
    return $false
}

function Clear-SafeTempFolder([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return -1 }
    $resolved = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
    # Only clear folders explicitly named Temp; never a drive root.
    if ($resolved.Length -le 3 -or $resolved -notmatch '(?i)\\Temp$') { return -1 }

    Get-ChildItem -LiteralPath $resolved -Force | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
    return @(Get-ChildItem -LiteralPath $resolved -Force).Count
}

try {
    Add-Type -Namespace Native -Name Keys -MemberDefinition '[DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);'
} catch {}

Show-Header 'OneClick Shutdown - Preparation'
Write-Host 'This utility requests apps to close normally. It does NOT force-kill apps.' -ForegroundColor White
Write-Host 'Save your work before continuing.' -ForegroundColor Yellow
Write-Host ''
$answer = Read-Host 'Continue? Type Y and press Enter'
if ($answer -notmatch '^(?i)y(es)?$') { exit 10 }

# Identify visible apps in the current interactive session, excluding Windows components
# and this script's own PowerShell/cmd parent chain.
$protected = @(
    'explorer','svchost','csrss','wininit','services','lsass','winlogon','smss','system','idle','registry',
    'dwm','fontdrvhost','sihost','taskhostw','ctfmon','runtimebroker','applicationframehost','searchhost',
    'searchapp','searchindexer','startmenuexperiencehost','shellexperiencehost','textinputhost','lockapp',
    'securityhealthsystray','securityhealthservice','msmpeng','nissrv','wudfhost','audiodg','spoolsv',
    'dllhost','backgroundtaskhost','widgets','memory compression','logonui','userinit',
    'conhost','openconsole','windowsterminal','cmd','powershell','pwsh'
)
$sysUserApps = @('notepad','mspaint','wordpad','calc','write','charmap','snippingtool')
$skipIds = New-Object 'System.Collections.Generic.HashSet[int]'
$cur = $PID
for ($k = 0; $k -lt 8 -and $cur; $k++) {
    [void]$skipIds.Add([int]$cur)
    $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$cur"
    if (-not $parent -or -not $parent.ParentProcessId) { break }
    $cur = [int]$parent.ParentProcessId
}

$sid = (Get-Process -Id $PID).SessionId
$winDir = $env:windir
$apps = @(Get-Process | Where-Object {
    $_.SessionId -eq $sid -and
    $_.MainWindowHandle -ne 0 -and
    $_.MainWindowTitle -ne '' -and
    ($protected -notcontains $_.ProcessName.ToLowerInvariant()) -and
    (-not $skipIds.Contains([int]$_.Id))
} | Where-Object {
    $p = $_.Path
    $n = $_.ProcessName.ToLowerInvariant()
    -not ($p -and $p.StartsWith($winDir, [StringComparison]::OrdinalIgnoreCase) -and ($sysUserApps -notcontains $n))
})

Show-Header 'Step 1/4 - Requesting apps to close'
if ($apps.Count -eq 0) {
    Write-Host 'No visible user applications were detected.' -ForegroundColor Green
} else {
    Write-Host "Found $($apps.Count) visible application process(es)." -ForegroundColor White
    Write-Host 'A save prompt may appear. If an app remains open, shutdown will be cancelled.' -ForegroundColor Yellow
    foreach ($app in $apps) {
        try {
            $p = Get-Process -Id $app.Id
            if ($p -and $p.MainWindowHandle -ne 0) {
                Write-Host ("  Requesting close: " + $p.ProcessName)
                [void]$p.CloseMainWindow()
            }
        } catch {}
    }
    Start-Sleep -Seconds 3
    $remaining = @()
    foreach ($app in $apps) {
        $p = Get-Process -Id $app.Id
        if ($p -and $p.MainWindowHandle -ne 0) { $remaining += $p }
    }
    if ($remaining.Count -gt 0) {
        Write-Host ''
        Write-Host 'These apps are still open:' -ForegroundColor Yellow
        $remaining | ForEach-Object { Write-Host ("  - " + $_.ProcessName + " (PID " + $_.Id + ")") }
        Write-Host ''
        Write-Host 'They may have unsaved work. Save/close them yourself, then run this utility again.' -ForegroundColor Yellow
        exit 20
    }
}

Show-Header 'Step 2/4 - Cleaning user TEMP'
$r = Clear-SafeTempFolder $env:TEMP
if ($r -lt 0) { Write-Host 'Skipped: TEMP path did not pass safety checks.' -ForegroundColor Yellow }
elseif ($r -eq 0) { Write-Host 'User TEMP cleanup complete.' -ForegroundColor Green }
else { Write-Host "$r item(s) remain (possibly in use or access denied)." -ForegroundColor Yellow }

Write-Host ''
Write-Host 'Cleaning Windows TEMP (may require Administrator)...' -ForegroundColor White
$r = Clear-SafeTempFolder (Join-Path $env:windir 'Temp')
if ($r -lt 0) { Write-Host 'Skipped: Windows TEMP path did not pass safety checks.' -ForegroundColor Yellow }
elseif ($r -eq 0) { Write-Host 'Windows TEMP cleanup complete.' -ForegroundColor Green }
else { Write-Host "$r item(s) remain (possibly in use or access denied)." -ForegroundColor Yellow }

Show-Header 'Step 3/4 - Recycle Bin and DNS'
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Host 'Recycle Bin emptied.' -ForegroundColor Green
} catch {
    Write-Host 'Recycle Bin cleanup skipped or unavailable.' -ForegroundColor Yellow
}
& ipconfig.exe /flushdns | Out-Null
if ($LASTEXITCODE -eq 0) { Write-Host 'DNS cache flushed.' -ForegroundColor Green }
else { Write-Host 'DNS flush skipped or requires elevated permissions.' -ForegroundColor Yellow }

Show-Header 'Step 4/4 - Final shutdown countdown' 'Yellow'
Write-Host 'Press ANY KEY during the next 6 seconds to cancel.' -ForegroundColor White
Write-Host 'Shutdown uses the normal Windows flow; no force-close flag is used.' -ForegroundColor DarkGray
Write-Host ''

# Discard input typed before the countdown.
while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) }

$cancel = $false
for ($i = 6; $i -ge 1 -and -not $cancel; $i--) {
    Write-Host ("        " + $i) -ForegroundColor Yellow
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt 1000) {
        if (Test-AnyKey) { $cancel = $true; break }
        Start-Sleep -Milliseconds 25
    }
}
if ($cancel) {
    Write-Host ''
    Write-Host 'Shutdown cancelled by keyboard input.' -ForegroundColor Yellow
    exit 10
}
exit 0
