@echo off
chcp 65001 >nul
title 爸妈宝 — 系统睡眠问题修复工具
cd /d "%~dp0"

echo ============================================
echo   爸妈宝 — 系统睡眠/休眠问题一键修复
echo ============================================
echo.
echo [1/3] 正在请求管理员权限...

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠ 未以管理员身份运行，请右键本文件选择「以管理员身份运行」
    echo.
    pause
    exit /b 1
)
echo   ✅ 管理员权限已获取

echo.
echo [2/3] 设置电源策略（防止系统睡眠/休眠）...
powercfg /change standby-timeout-ac 0 >nul 2>&1
if %errorlevel% equ 0 ( echo   ✅ 接通电源：永不睡眠 ) else ( echo   ❌ 设置失败 )
powercfg /change hibernate-timeout-ac 0 >nul 2>&1
if %errorlevel% equ 0 ( echo   ✅ 接通电源：永不休眠 ) else ( echo   ❌ 设置失败 )
powercfg /change monitor-timeout-ac 0 >nul 2>&1
if %errorlevel% equ 0 ( echo   ✅ 接通电源：显示器永不关闭 ) else ( echo   ❌ 显示器设置失败 )
powercfg /h off >nul 2>&1
if %errorlevel% equ 0 ( echo   ✅ 已关闭休眠功能并释放磁盘空间 ) else ( echo   ❌ 休眠文件操作失败 )

echo.
echo [3/3] 验证当前电源设置...
echo.
powercfg /query 2>nul | findstr /i /c:"睡眠" /c:"休眠" /c:"关闭显示器"
echo.
echo ============================================
echo   ✅ 修复完成！系统不再自动睡眠/休眠
echo.
echo   🔄 如需恢复默认设置，请运行：
echo      powercfg /restoredefaultschemes
echo.
echo   ⚡ 如果需要手动调整，请在 Windows 设置中搜索「电源与睡眠」
echo ============================================
echo.
pause
