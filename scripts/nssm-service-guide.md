# 爸妈宝 — NSSM 注册为 Windows 服务指南

## 背景

后端服务 `uvicorn` 默认在命令行窗口运行，若用户关闭窗口 / 重启电脑后服务即停止。
使用 **NSSM (Non-Sucking Service Manager)** 可将后端注册为 **Windows 系统服务**，实现：

- ✅ **开机自启**（无需手动登录启动）
- ✅ **进程守护**（崩溃后 NSSM 自动重启）
- ✅ **日志轮转**（日志按天切分，不撑爆磁盘）
- ✅ **无窗口运行**（不弹出命令行窗口）

---

## 准备工作

1. **下载 NSSM**  
   [https://nssm.cc/download](https://nssm.cc/download) → 下载 `nssm-2.24.zip`

2. **解压并放置**  
   将 `win64/nssm.exe` 放到以下任一位置：
   - 本项目 `scripts\` 目录（推荐）
   - `C:\Windows\System32\`
   - 系统 PATH 中的任意目录

---

## 快速安装（推荐）

### 方法一：一键脚本

以 **管理员身份** 运行 PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File "scripts\windows-service.ps1"
```

脚本会自动：
- 检测 NSSM 是否可用
- 注册名为 `BamabaoBackend` 的 Windows 服务
- 配置日志输出到 `backend\logs\`
- 设置服务为「自动启动」
- 启动服务

---

### 方法二：手动注册

```cmd
# 安装服务
nssm install BamabaoBackend

# 在弹出的 GUI 中填写：
#   Application Path: D:\projects\爸妈宝\backend\venv\Scripts\uvicorn.exe
#   Arguments:        app.main:app --host 0.0.0.0 --port 8000
#   Startup directory: D:\projects\爸妈宝\backend\
```

---

## 服务管理命令

| 操作 | 命令 |
|------|------|
| 启动服务 | `nssm start BamabaoBackend` |
| 停止服务 | `nssm stop BamabaoBackend` |
| 重启服务 | `nssm restart BamabaoBackend` |
| 查看状态 | `nssm status BamabaoBackend` |
| 编辑配置 | `nssm edit BamabaoBackend`（弹出 GUI） |
| 卸载服务 | `nssm remove BamabaoBackend confirm` |

也可使用 Windows 原生 `sc` 命令：

```cmd
sc query BamabaoBackend
sc stop BamabaoBackend
sc start BamabaoBackend
sc delete BamabaoBackend
```

---

## 日志管理

服务日志输出到 `backend\logs\`：

- `service-out.log` — 标准输出（print / logger.info 等）
- `service-err.log` — 错误输出（异常栈、ERROR 级别日志）

NSSM 配置了每日日志轮转（`AppRotateSeconds=86400`），每天 0 点自动切分，旧日志保留在原目录不删除。建议定期清理 30 天前的日志：

```cmd
:: 清理 30 天前的日志（添加到任务计划，每月执行一次）
forfiles /p "D:\projects\爸妈宝\backend\logs" /s /m *.log /d -30 /c "cmd /c del @path"
```

---

## 故障排查

### 服务无法启动

1. 检查日志文件 `backend\logs\service-err.log`
2. 确认 `venv\` 路径正确，Python 环境完整
3. 在命令行人肉测试启动：
   ```cmd
   cd D:\projects\爸妈宝\backend
   venv\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
4. 确认 8000 端口未被占用：
   ```cmd
   netstat -ano | findstr :8000
   ```

### 端口占用

如果 8000 端口被其他进程占用，修改 `windows-service.ps1` 中的端口参数，或杀掉占用进程：

```cmd
:: 查看占用 8000 端口的 PID
netstat -ano | findstr :8000

:: 根据 PID 杀掉进程（假设 PID 是 1234）
taskkill /PID 1234 /F
```
