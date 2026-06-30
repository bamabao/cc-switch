# ============================================================
# 爸妈宝 — 后端启动脚本（Windows）
# ============================================================
# 用法：
#   直接双击运行，或：
#   powershell -ExecutionPolicy Bypass -File start-backend.ps1
# ============================================================

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir = Join-Path $ProjectRoot "backend"
$VenvDir = Join-Path $BackendDir "venv"
$LogDir = Join-Path $BackendDir "logs"

# 确保日志目录存在
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# 检查端口占用
$portInUse = netstat -ano | Select-String ":8000" | Where-Object { $_ -match "LISTENING" }
if ($portInUse) {
    Write-Host "⚠️ 端口 8000 已被占用，可能已有实例在运行。" -ForegroundColor Yellow
    Write-Host "   如需重启，先运行: netstat -ano | findstr :8000 然后 taskkill /PID <PID> /F" -ForegroundColor Yellow
    $choice = Read-Host "   要继续吗？(Y/N)"
    if ($choice -ne "Y") { exit }
}

# 进入后端目录
Push-Location $BackendDir

try {
    # 激活虚拟环境
    $ActivateScript = Join-Path $VenvDir "Scripts\Activate.ps1"
    if (Test-Path $ActivateScript) {
        & $ActivateScript
    } else {
        Write-Host "⚠️ 虚拟环境未找到，检查路径: $ActivateScript" -ForegroundColor Yellow
    }

    # 验证依赖
    Write-Host "🔍 检查依赖..." -ForegroundColor Cyan
    $missingModules = @()
    $modules = @("fastapi", "uvicorn", "sqlalchemy", "jose", "passlib")
    foreach ($mod in $modules) {
        try {
            python -c "import $mod" 2>$null
        } catch {
            $missingModules += $mod
        }
    }
    if ($missingModules.Count -gt 0) {
        Write-Host "⚠️ 缺少模块: $($missingModules -join ', ')" -ForegroundColor Yellow
        Write-Host "   运行: pip install -r requirements.txt" -ForegroundColor Yellow
    }

    # 启动 API 服务
    $logFile = Join-Path $LogDir "bamabao-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    Write-Host "🚀 启动爸妈宝 API 服务..." -ForegroundColor Green
    Write-Host "   日志: $logFile" -ForegroundColor Gray
    Write-Host "   端口: http://localhost:8000" -ForegroundColor Gray
    Write-Host "   API 文档: http://localhost:8000/docs" -ForegroundColor Gray
    Write-Host "" -ForegroundColor Gray
    Write-Host "按 Ctrl+C 停止服务" -ForegroundColor DarkGray

    # 启动服务
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload 2>&1 | Tee-Object -FilePath $logFile

} finally {
    Pop-Location
}
