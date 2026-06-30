# 爸妈宝 - Health Check Watchdog v2 (Windows)
# Usage: powershell -WindowStyle Hidden -File watchdog.ps1
param(
    [int]$IntervalSeconds = 30,
    [string]$HealthUrl = "http://localhost:8000/api/v1/health",
    [int]$RetryCount = 2,
    [int]$RetryDelaySeconds = 5,
    [int]$MaxConsecutiveRestarts = 3,
    [int]$AlertCooldownMinutes = 30
)

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$BackendDir = Join-Path $ProjectRoot "backend"
$LogDir = Join-Path $BackendDir "watchdog"
$StateFile = Join-Path $LogDir "watchdog-state.json"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp [$Level] $Message"
    $logFile = Join-Path $LogDir "watchdog-$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $line
}

function Read-State {
    if (Test-Path $StateFile) {
        try {
            return Get-Content $StateFile -Raw | ConvertFrom-Json
        } catch { }
    }
    return @{ consecutiveRestarts = 0; lastAlertTime = "1970-01-01T00:00:00" }
}

function Write-State {
    param($State)
    try {
        $State | ConvertTo-Json | Set-Content $StateFile -Force
    } catch {
        Write-Log "State write failed: $_" -Level "WARN"
    }
}

function Get-Health {
    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 10 -SkipCertificateCheck
        return ($response.StatusCode -eq 200)
    } catch {
        return $false
    }
}

function Restart-Backend {
    param([int]$RestartAttempt)

    Write-Log "Restarting backend (attempt $RestartAttempt)..." -Level "WARN"
    $candidates = Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "uvicorn" }
    foreach ($p in $candidates) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2

    $venv = Join-Path $BackendDir "venv\Scripts\python.exe"
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $venv
        $psi.Arguments = "-m uvicorn app.main:app --host 0.0.0.0 --port 8000"
        $psi.WorkingDirectory = $BackendDir
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        if ($proc) {
            Write-Log "Started backend PID=$($proc.Id)" -Level "WARN"
        }
    } catch {
        Write-Log "Start failed: $_" -Level "ERROR"
    }
}

function Send-Alert {
    param([int]$AttemptCount)
    $alarmDir = Join-Path $LogDir "alerts"
    if (-not (Test-Path $alarmDir)) { New-Item -ItemType Directory -Path $alarmDir -Force | Out-Null }
    $alertFile = Join-Path $alarmDir "alert-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    "Backend crashed $AttemptCount times" | Out-File $alertFile -Encoding utf8
    Write-Log "Alert: $alertFile" -Level "ALERT"
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists("BamabaoWatchdog")) {
            [System.Diagnostics.EventLog]::CreateEventSource("BamabaoWatchdog", "Application")
        }
        Write-EventLog -LogName Application -Source BamabaoWatchdog -EventId 9001 -EntryType Error -Message "Backend crashed $AttemptCount times"
    } catch { }
}

Write-Log "========== Bamabao Watchdog v2 START =========="
Write-Log "Target: $HealthUrl Interval: ${IntervalSeconds}s"

# Startup grace period: don't trigger restart for first 3 failures
$startupFails = 0
$failCount = 0
$backoffLevel = 0
$backoffTable = @($IntervalSeconds, 60, 120, 300, 300)
$state = Read-State
Write-Log "State: consecutiveRestarts=$($state.consecutiveRestarts)"

while ($true) {
    $ok = Get-Health
    if ($ok) {
        if ($failCount -gt 0) {
            Write-Log "Service recovered after $failCount failures"
        }
        $failCount = 0
        $backoffLevel = 0
        if ($state.consecutiveRestarts -gt 0) {
            $state.consecutiveRestarts = 0
            Write-State -State $state
            Write-Log "Reset restart counter"
        }
    } else {
        $failCount++
        Write-Log "Health check failed (#$failCount)" -Level "WARN"
        if ($failCount -ge $RetryCount) {
            $state.consecutiveRestarts++
            Write-Log "Restart triggered (#$($state.consecutiveRestarts))" -Level "ERROR"
            Restart-Backend -RestartAttempt $state.consecutiveRestarts
            $failCount = 0
            $backoffLevel = [Math]::Min($backoffLevel + 1, $backoffTable.Length - 1)

            if ($state.consecutiveRestarts -ge $MaxConsecutiveRestarts) {
                $now = Get-Date
                $lastAlert = [DateTime]$state.lastAlertTime
                if (($now - $lastAlert).TotalMinutes -ge $AlertCooldownMinutes) {
                    Send-Alert -AttemptCount $state.consecutiveRestarts
                    $state.lastAlertTime = $now.ToString("o")
                }
            }
            Write-State -State $state
            $effectiveDelay = $backoffTable[$backoffLevel]
            Write-Log "Waiting ${effectiveDelay}s before retry"
            Start-Sleep -Seconds $effectiveDelay

            if (Get-Health) {
                Write-Log "Backend recovered after restart"
                $state.consecutiveRestarts = 0
                Write-State -State $state
            } else {
                Write-Log "Still down after restart" -Level "ERROR"
            }
        }
    }
    $sleepSeconds = $backoffTable[$backoffLevel]
    Start-Sleep -Seconds $sleepSeconds
}
