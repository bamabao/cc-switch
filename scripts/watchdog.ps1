# ============================================================
# 爸妈宝 — Health Check Watchdog v2（Windows 增强版）
# 用途：定时检测后端 API 健康状态，若挂掉则自动重启
# 新增特性：
#   - 连续重启 3 次仍失败 → 静默报警（写报警文件 + 事件日志）
#   - 重启间隔指数退避（30s → 60s → 120s → 300s）
#   - 更健壮的进程查找与清理
#   - 状态文件持久化（避免因 watchdog 自身重启丢失计数器）
# 用法（后台运行）：
#    powershell -WindowStyle Hidden -File watchdog.ps1
# 配合任务计划程序（或 NSSM）开机启动更佳
# ============================================================

param(
    [int]$IntervalSeconds = 30,
    [string]$HealthUrl = "http://localhost:8000/api/v1/health",
    [string]$BackendDir = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [int]$RetryCount = 2,
    [int]$RetryDelaySeconds = 5,
    [int]$MaxConsecutiveRestarts = 3,    # 连续重启 N 次触发报警
    [int]$AlertCooldownMinutes = 30      # 报警后 N 分钟内不再重复报警
)

# 目录配置
$ProjectRoot = Split-Path -Parent $BackendDir   # scripts/ 的父级 = 项目根
$BackendDir = Join-Path $ProjectRoot "backend"
$LogDir = Join-Path $BackendDir "watchdog"
$StateFile = Join-Path $LogDir "watchdog-state.json"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# ─── 日志函数 ──────────────────────────────────────────
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp [$Level] $Message"
    $logFile = Join-Path $LogDir "watchdog-$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $line
    if ($Level -eq "ERROR") {
        Write-Host $line -ForegroundColor Red
    } elseif ($Level -eq "WARN") {
        Write-Host $line -ForegroundColor Yellow
    } elseif ($Level -eq "ALERT") {
        Write-Host $line -ForegroundColor Magenta
    }
}

# ─── 状态持久化 ────────────────────────────────────────
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
        Write-Log "写入状态文件失败: $_" -Level "WARN"
    }
}

# ─── 健康检查 ──────────────────────────────────────────
function Get-Health {
    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 10 -SkipCertificateCheck
        if ($response.StatusCode -eq 200) {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# ─── 重启后端 ──────────────────────────────────────────
function Restart-Backend {
    param([int]$RestartAttempt)

    Write-Log "正在重启后端（第 ${RestartAttempt} 次连续重启）..." -Level "WARN"

    # 1) 找到 uvicorn 相关 Python 进程并杀干净
    $candidates = Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" 2>$null
    if (-not $candidates) {
        $candidates = Get-Process python -ErrorAction SilentlyContinue
    }

    $killed = 0
    foreach ($p in $candidates) {
        $cmdLine = ""
        try {
            if ($p.GetType().Name -eq "__ComObject") {
                $cmdLine = $p.CommandLine
            } else {
                $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($p.Id)").CommandLine
            }
        } catch { }

        if ($cmdLine -match "uvicorn" -or $cmdLine -match "app\.main") {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
            $killed++
        }
    }
    if ($killed -gt 0) {
        Write-Log "已清理 $killed 个旧后端进程" -Level "WARN"
    }

    Start-Sleep -Seconds 2

    # 2) 启动新后端
    $activateScript = Join-Path $BackendDir "venv\Scripts\Activate.ps1"
    $logFile = Join-Path $BackendDir "logs\bamabao-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $logDirParent = Split-Path $logFile -Parent
    if (-not (Test-Path $logDirParent)) {
        New-Item -ItemType Directory -Path $logDirParent -Force | Out-Null
    }

    # 用 Start-Process 更稳定
    try {
        $startCmd = "& '$activateScript'; uvicorn app.main:app --host 0.0.0.0 --port 8000"
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -WindowStyle Hidden -Command `"cd '$BackendDir'; $startCmd 2>&1 | Tee-Object -FilePath '$logFile'`""
        $psi.WorkingDirectory = $BackendDir
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $false
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        if ($proc -and $proc.Id) {
            Write-Log "已启动新后端进程 PID=$($proc.Id)" -Level "WARN"
        } else {
            Write-Log "启动后端：进程句柄无效" -Level "ERROR"
        }
    } catch {
        Write-Log "启动后端失败: $_" -Level "ERROR"
    }
}

# ─── 发送报警 ──────────────────────────────────────────
function Send-Alert {
    param([int]$AttemptCount)

    $alertFile = Join-Path $LogDir "alert-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $alertBody = @{
        timestamp  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        level      = "CRITICAL"
        message    = "后端连续重启 $AttemptCount 次仍未恢复，请人工介入检查"
        health_url = $HealthUrl
        backdir    = $BackendDir
        logs_dir   = (Join-Path $BackendDir "logs")
    }

    # 1) 写报警文件（给外部监控系统触发）
    $alertBody | ConvertTo-Json | Set-Content $alertFile -Force
    Write-Log "报警文件已写入: $alertFile" -Level "ALERT"

    # 2) 写 Windows 事件日志（在「事件查看器 → Windows 日志 → 应用程序」中可见）
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists("BamabaoWatchdog")) {
            [System.Diagnostics.EventLog]::CreateEventSource("BamabaoWatchdog", "Application")
        }
        Write-EventLog -LogName Application -Source BamabaoWatchdog -EventId 9001 -EntryType Error -Message $alertBody.message
        Write-Log "已写入 Windows 事件日志" -Level "ALERT"
    } catch {
        Write-Log "写入事件日志失败（非管理员时正常）: $_" -Level "WARN"
    }

    # 3) 写入系统托盘通知（仅对当前登录用户可见）
    try {
        $notification = New-Object System.Windows.Forms.NotifyIcon
        $notification.Icon = [System.Drawing.SystemIcons]::Warning
        $notification.BalloonTipTitle = "爸妈宝 — 后端服务报警"
        $notification.BalloonTipText = "后端连续重启 $AttemptCount 次仍未恢复，请检查服务器状态"
        $notification.Visible = $true
        $notification.ShowBalloonTip(10000)
        Start-Sleep -Seconds 1
        $notification.Dispose()
    } catch {
        Write-Log "系统托盘通知失败（无 UI 环境正常）: $_" -Level "WARN"
    }
}

# ─── 主循环 ────────────────────────────────────────────
Write-Log "======= 爸妈宝 Watchdog v2 启动 ======="
Write-Log "目标: $HealthUrl"
Write-Log "检查间隔: ${IntervalSeconds}s"
Write-Log "连续重启上限: $MaxConsecutiveRestarts 次"
Write-Log "报警冷却: ${AlertCooldownMinutes}min"
Write-Log "状态文件: $StateFile"

$failCount = 0
$state = Read-State
Write-Log "读取状态: 连续重启次数=$($state.consecutiveRestarts)" -Level "INFO"

# 指数退避参数
$backoffLevel = 0
$backoffTable = @($IntervalSeconds, 60, 120, 300, 300)

while ($true) {
    $ok = Get-Health

    if ($ok) {
        if ($failCount -gt 0) {
            Write-Log "服务已恢复（连续 ${failCount} 次失败后恢复正常）"
        }
        $failCount = 0
        $backoffLevel = 0

        # 连续重启计数归零（服务已正常运行超过一个周期）
        if ($state.consecutiveRestarts -gt 0) {
            $state.consecutiveRestarts = 0
            Write-State $state
            Write-Log "连续重启计数器已归零（服务正常运行中）" -Level "INFO"
        }
    } else {
        $failCount++
        Write-Log "健康检查失败（连续第 ${failCount} 次）" -Level "WARN"

        if ($failCount -ge $RetryCount) {
            $state.consecutiveRestarts++
            Write-Log "连续 $($state.consecutiveRestarts) 次重启触发，准备重启..." -Level "ERROR"

            Restart-Backend -RestartAttempt $state.consecutiveRestarts
            $failCount = 0
            $backoffLevel = [Math]::Min($backoffLevel + 1, $backoffTable.Length - 1)

            # 检查是否达到报警阈值
            if ($state.consecutiveRestarts -ge $MaxConsecutiveRestarts) {
                $now = Get-Date
                $lastAlert = [DateTime]$state.lastAlertTime
                if (($now - $lastAlert).TotalMinutes -ge $AlertCooldownMinutes) {
                    Write-Log "连续重启 $($state.consecutiveRestarts) 次，触发报警！" -Level "ALERT"
                    Send-Alert -AttemptCount $state.consecutiveRestarts
                    $state.lastAlertTime = $now.ToString("o")
                } else {
                    Write-Log "报警静默中（距上次报警不到 ${AlertCooldownMinutes}min）" -Level "INFO"
                }
            }

            # 写入状态
            Write-State $state

            # 等待恢复
            $effectiveDelay = $backoffTable[$backoffLevel]
            Write-Log "等待 ${effectiveDelay}s 后重试" -Level "INFO"
            Start-Sleep -Seconds $effectiveDelay

            if (Get-Health) {
                Write-Log "✅ 重启成功，服务已恢复" -Level "INFO"
                $state.consecutiveRestarts = 0
                Write-State $state
            } else {
                Write-Log "重启后仍未恢复" -Level "ERROR"
            }
        }
    }

    # 使用指数退避间隔
    $sleepSeconds = $backoffTable[$backoffLevel]
    Start-Sleep -Seconds $sleepSeconds
}
