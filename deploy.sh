#!/usr/bin/env bash
# 法律技能一键部署入口（自动识别平台）
#
# - macOS / Linux：转调 scripts/deploy-wife-legal-skills.sh
# - Windows（Git Bash / MSYS2 / Cygwin）：转调 scripts/deploy-wife-legal-skills.ps1
# - 其他平台：直接报错退出

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

case "$OS" in
    Darwin|Linux)
        exec bash "$SCRIPT_DIR/scripts/deploy-wife-legal-skills.sh" "$@"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        # 统一 --xxx 与 -Xxx 两种写法，便于在三个平台用同一套命令
        ps_args=()
        while [ $# -gt 0 ]
        do
            case "$1" in
                --action)          ps_args+=("-Action" "${2:-}"); shift 2 ;;
                --repo)            ps_args+=("-Repo" "${2:-}"); shift 2 ;;
                --category)        ps_args+=("-Category" "${2:-}"); shift 2 ;;
                --root)            ps_args+=("-Root" "${2:-}"); shift 2 ;;
                --project)         ps_args+=("-Project" "${2:-}"); shift 2 ;;
                --org)             ps_args+=("-Org" "${2:-}"); shift 2 ;;
                --topic)           ps_args+=("-Topic" "${2:-}"); shift 2 ;;
                --all)             ps_args+=("-All"); shift ;;
                --include-large)   ps_args+=("-IncludeLarge"); shift ;;
                --non-interactive) ps_args+=("-NonInteractive"); shift ;;
                -h|--help)         ps_args+=("-Help"); shift ;;
                *)                 ps_args+=("$1"); shift ;;
            esac
        done

        if command -v pwsh >/dev/null 2>&1
        then
            exec pwsh -NoProfile -ExecutionPolicy Bypass -File \
                "$SCRIPT_DIR/scripts/deploy-wife-legal-skills.ps1" "${ps_args[@]}"
        elif command -v powershell.exe >/dev/null 2>&1
        then
            exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File \
                "$SCRIPT_DIR/scripts/deploy-wife-legal-skills.ps1" "${ps_args[@]}"
        else
            echo "未找到 PowerShell（pwsh 或 powershell.exe），无法在 Windows 上运行" >&2
            exit 1
        fi
        ;;
    *)
        echo "不支持的平台：$OS（支持 macOS、Linux、Windows）" >&2
        exit 1
        ;;
esac
