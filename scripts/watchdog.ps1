# ============================================================
# 爸妈宝 — Health Check Watchdog（Windows）
# 用途：定时检测后端 API 健康状态，若挂掉则自动重启
# 用法（后台运行）：
#    powershell -WindowStyle Hidden -File watchdog.ps1
# 配合任务计划程序开机启动更佳
# ============================================================

param(
    [int]$IntervalSeconds = 30,
    [string]$HealthUrl = "http://localhost:8000/api/v1/health",
    [string]$BackendDir = $PSScriptRoot,
    [int]$RetryCount = 2,
    [int]$RetryDelaySeconds = 5
)

$LogDir = Join-Path $BackendDir "watchdog"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp [$Level] $Message"
    $logFile = Join-Path $LogDir "watchdog-$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $line
    if ($Level -eq "ERROR" -or $Level -eq "WARN") {
        Write-Host $line -ForegroundColor $(if ($Level -eq "ERROR") { "Red" } else { "Yellow" })
    }
}

function Get-Health {
    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

function Restart-Backend {
    Write-Log "正在重启后端..." -Level "WARN"

    # 1) 杀掉已有 uvicorn 进程（可能残留）
    $existing = Get-Process | Where-Object { $_.ProcessName -eq "python" -and $_.CommandLine -like "*uvicorn*" }
    foreach ($p in $existing) {
        Write-Log "杀掉旧进程 PID=$($p.Id)" -Level "WARN"
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 2

    # 2) 在新窗口中启动后端
    $activateScript = Join-Path $BackendDir "venv\Scripts\Activate.ps1"
    $startCmd = "& '$activateScript'; uvicorn app.main:app --host 0.0.0.0 --port 8000"
    
    try {
        $logFile = Join-Path $BackendDir "logs\bamabao-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -WindowStyle Hidden -Command `"cd '$BackendDir'; $startCmd 2>&1 | Tee-Object -FilePath '$logFile'`""
        $psi.WorkingDirectory = $BackendDir
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $false
        $psi.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        Write-Log "已启动新后端进程 PID=$($proc.Id)" -Level "WARN"
    } catch {
        Write-Log "启动后端失败: $_" -Level "ERROR"
    }
}

# ---- 主循环 ----
Write-Log "监控狗启动，目标: $HealthUrl，间隔: ${IntervalSeconds}s"

$failCount = 0

while ($true) {
    $ok = Get-Health
    if ($ok) {
        if ($failCount -gt 0) {
            Write-Log "服务已恢复（连续 $failCount 次失败后恢复正常）" -Level "INFO"
        }
        $failCount = 0
    } else {
        $failCount++
        Write-Log "健康检查失败（连续第 ${failCount} 次）" -Level "WARN"

        if ($failCount -ge $RetryCount) {
            Write-Log "连续 $RetryCount 次失败，触发重启..." -Level "ERROR"
            Restart-Backend
            $failCount = 0

            # 等待恢复
            Start-Sleep -Seconds $RetryDelaySeconds
            if (Get-Health) {
                Write-Log "重启成功，服务正常运行" -Level "INFO"
            } else {
                Write-Log "重启后仍未恢复，下次循环将再次尝试" -Level "ERROR"
            }
        }
    }

    Start-Sleep -Seconds $IntervalSeconds
}
