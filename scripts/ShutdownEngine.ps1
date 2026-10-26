# OneClick Shutdown - PowerShell engine
# Compatible with Windows PowerShell 5.1+.
# Does not force-terminate applications.

$ErrorActionPreference = 'Continue'
$scriptRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$logDirectory = Join-Path $scriptRoot 'logs'
$logPath = Join-Path $logDirectory ("OneClickShutdown-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

try {
    New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop | Out-Null
} catch {
    Write-Host "Could not create log directory: $($_.Exception.Message)" -ForegroundColor Yellow
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    try {
        Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8 -ErrorAction Stop
    } catch {
        # Continue even if logging is unavailable.
    }
}

function Remove-TemporaryContents {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        Write-Log "Temporary directory not found; skipping: $Path" 'WARN'
        return
    }

    Write-Log "Cleaning eligible temporary contents in: $Path"
    $removed = 0
    $skipped = 0

    try {
        $items = Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            try {
                Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                $removed++
            } catch {
                $skipped++
                Write-Log "Skipped locked/inaccessible item: $($item.FullName) - $($_.Exception.Message)" 'WARN'
            }
        }
    } catch {
        Write-Log "Could not enumerate $Path : $($_.Exception.Message)" 'ERROR'
    }

    Write-Log "Cleanup summary for $Path : removed=$removed, skipped=$skipped"
}

Write-Host ''
Write-Host 'OneClick Shutdown - preparation' -ForegroundColor Cyan
Write-Host 'Save your work. Applications may show their own save prompts.'
Write-Log 'Run started.'

# Ask visible desktop applications to close gracefully.
try {
    $apps = @(Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.Id -ne $PID })

    Write-Log ("Found {0} visible application window(s)." -f $apps.Count)

    foreach ($app in $apps) {
        try {
            Write-Log "Requesting graceful close: $($app.ProcessName) (PID $($app.Id))"
            [void]$app.CloseMainWindow()
        } catch {
            Write-Log "Could not request close for $($app.ProcessName): $($_.Exception.Message)" 'WARN'
        }
    }

    Start-Sleep -Seconds 8

    $remaining = @(Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.Id -ne $PID })

    if ($remaining.Count -gt 0) {
        Write-Host ''
        Write-Host 'Some application windows are still open:' -ForegroundColor Yellow
        $remaining | ForEach-Object { Write-Host (" - {0}" -f $_.ProcessName) }
        Write-Host ''
        Write-Host 'They will NOT be force-closed by this utility.'
        $answer = Read-Host 'Continue cleanup anyway? Type Y to continue; anything else cancels'
        if ($answer -notmatch '^(Y|YES)$') {
            Write-Log 'User cancelled because application windows remained open.' 'WARN'
            exit 2
        }
    }
} catch {
    Write-Log "Application close stage encountered an error: $($_.Exception.Message)" 'ERROR'
}

# Clean only standard temporary directories. Locked/inaccessible items are skipped.
$userTemp = [System.IO.Path]::GetTempPath()
$windowsTemp = Join-Path $env:WINDIR 'Temp'
Remove-TemporaryContents -Path $userTemp

if ($windowsTemp.TrimEnd('\') -ine $userTemp.TrimEnd('\')) {
    Remove-TemporaryContents -Path $windowsTemp
}

Write-Host ''
Write-Host 'Cleanup stage finished.' -ForegroundColor Green
Write-Host 'Final shutdown countdown: press C at any time to cancel.'
Write-Log 'Starting 10-second shutdown countdown. Press C to cancel.'

for ($seconds = 10; $seconds -ge 1; $seconds--) {
    Write-Host ("Shutting down in {0} second(s)... (C = cancel)" -f $seconds)
    $endTime = (Get-Date).AddSeconds(1)
    while ((Get-Date) -lt $endTime) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::C) {
                Write-Host ''
                Write-Log 'Shutdown cancelled by user during countdown.' 'WARN'
                exit 2
            }
        }
        Start-Sleep -Milliseconds 100
    }
}

Write-Host ''
Write-Log 'Countdown completed; requesting Windows shutdown.'
try {
    & "$env:WINDIR\System32\shutdown.exe" /s /t 0 /c "OneClick Shutdown requested system shutdown."
    if ($LASTEXITCODE -ne 0) {
        Write-Log "shutdown.exe returned exit code $LASTEXITCODE" 'ERROR'
        exit $LASTEXITCODE
    }
} catch {
    Write-Log "Failed to request shutdown: $($_.Exception.Message)" 'ERROR'
    exit 1
}

exit 0
