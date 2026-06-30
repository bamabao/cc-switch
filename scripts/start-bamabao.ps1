# 爸妈宝开机自启（计划任务触发）
$venv = "C:\Users\74897\.openclaw\general-manager-agent\projects\爸妈宝\backend\venv\Scripts\python.exe"
$wb = "C:\Users\74897\.openclaw\general-manager-agent\projects\爸妈宝\backend"

# 等网络/系统就绪
Start-Sleep -Seconds 10

# 启动后端
Start-Process -NoNewWindow -FilePath $venv -ArgumentList "-m uvicorn app.main:app --host 0.0.0.0 --port 8000" -WorkingDirectory $wb

# 等后端就绪
Start-Sleep -Seconds 5

# 启动看门狗
$watchdog = "C:\Users\74897\.openclaw\general-manager-agent\projects\爸妈宝\scripts\watchdog.ps1"
Start-Process -NoNewWindow -FilePath powershell -ArgumentList "-NoProfile -WindowStyle Hidden -File "$watchdog""

Write-Host "爸妈宝启动完成"
