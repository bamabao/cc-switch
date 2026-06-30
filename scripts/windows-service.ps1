# ============================================================
# 爸妈宝 — 注册为 Windows 服务（开机自启）
# ============================================================
# 以管理员身份运行：
#   powershell -ExecutionPolicy Bypass -File windows-service.ps1
# ============================================================
#
# 原理：使用 NSSM (Non-Sucking Service Manager) 将 uvicorn 注册为
# Windows 服务。NSSM 会自动重启崩溃的进程。
#
# 下载 NSSM: https://nssm.cc/download
# 将 nssm.exe 放在本脚本同级目录下，或系统 PATH 中。
# ============================================================

$ServiceName = "BamabaoBackend"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$BackendDir = Join-Path $ProjectRoot "backend"
$VenvPython = Join-Path $BackendDir "venv\Scripts\python.exe"
$UvicornCmd = Join-Path $BackendDir "venv\Scripts\uvicorn.exe"
$LogDir = Join-Path $BackendDir "logs"

# 检查是否管理员
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "❌ 需要以管理员身份运行！" -ForegroundColor Red
    Write-Host "   右键 PowerShell → 以管理员身份运行" -ForegroundColor Yellow
    exit 1
}

# 检查 NSSM
$nssm = Get-Command "nssm.exe" -ErrorAction SilentlyContinue
if (-not $nssm) {
    Write-Host "❌ 未找到 nssm.exe" -ForegroundColor Red
    Write-Host "   下载地址: https://nssm.cc/download" -ForegroundColor Yellow
    Write-Host "   将 nssm.exe 放入系统 PATH 或同级目录" -ForegroundColor Yellow
    exit 1
}

# 检查是否已注册
$existing = & $nssm.Path status $ServiceName 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "⚠️ 服务 '$ServiceName' 已存在。" -ForegroundColor Yellow
    $choice = Read-Host "   要更新配置吗？(Y/N)"
    if ($choice -ne "Y") { exit }
    & $nssm.Path stop $ServiceName
    & $nssm.Path remove $ServiceName confirm
}

# 注册服务
Write-Host "🛠️ 注册 Windows 服务..." -ForegroundColor Cyan

& $nssm.Path install $ServiceName `
    $UvicornCmd `
    "app.main:app --host 0.0.0.0 --port 8000"

# 配置
& $nssm.Path set $ServiceName Application $UvicornCmd
& $nssm.Path set $ServiceName AppParameters "app.main:app --host 0.0.0.0 --port 8000"
& $nssm.Path set $ServiceName AppDirectory $BackendDir
& $nssm.Path set $ServiceName AppStdout (Join-Path $LogDir "service-out.log")
& $nssm.Path set $ServiceName AppStderr (Join-Path $LogDir "service-err.log")
& $nssm.Path set $ServiceName AppRotateFiles 1
& $nssm.Path set $ServiceName AppRotateSeconds 86400
& $nssm.Path set $ServiceName DisplayName "爸妈宝 API 服务"
& $nssm.Path set $ServiceName Description "爸妈宝老人端APP + 子女小程序后端 API 服务"
& $nssm.Path set $ServiceName Start SERVICE_AUTO_START
& $nssm.Path set $ServiceName ObjectName LocalSystem

# 启动
& $nssm.Path start $ServiceName

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 服务注册并启动成功！" -ForegroundColor Green
    Write-Host "   服务名: $ServiceName" -ForegroundColor Gray
    Write-Host "   显示名: 爸妈宝 API 服务" -ForegroundColor Gray
    Write-Host "   端口: http://localhost:8000" -ForegroundColor Gray
    Write-Host "" -ForegroundColor Gray
    Write-Host "管理命令: " -ForegroundColor DarkGray
    Write-Host "   nssm status $ServiceName" -ForegroundColor DarkGray
    Write-Host "   nssm stop $ServiceName" -ForegroundColor DarkGray
    Write-Host "   nssm restart $ServiceName" -ForegroundColor DarkGray
    Write-Host "   nssm remove $ServiceName confirm" -ForegroundColor DarkGray
} else {
    Write-Host "❌ 服务注册失败，请检查 nssm 配置。" -ForegroundColor Red
}
