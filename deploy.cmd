@echo off
rem 法律技能一键部署入口（Windows 双击或 cmd 调用）
rem 实际逻辑在 scripts\deploy-wife-legal-skills.ps1，本文件只负责找到 PowerShell 并转调
rem 用法示例：
rem   deploy.cmd -Action list
rem   deploy.cmd -Action install -Category 合同与商事
setlocal
set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%scripts\deploy-wife-legal-skills.ps1"

where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
    goto :done
)

where powershell.exe >nul 2>nul
if %ERRORLEVEL%==0 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
    goto :done
)

echo 未找到 PowerShell，无法运行部署脚本。
echo 请安装 PowerShell 7（pwsh）或使用 Windows 自带的 Windows PowerShell。
exit /b 1

:done
endlocal
