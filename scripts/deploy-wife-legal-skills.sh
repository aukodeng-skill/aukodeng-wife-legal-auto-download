#!/usr/bin/env bash
# 法律技能一键部署（macOS / Linux 版，与同目录 PowerShell 版功能一致）
#
# - 技能仓清单来自组织仓库的 topic（默认 wife-legal），不写死仓名；
# - catalog.tsv 提供业务分类，用于选择安装与平铺启用；
# - 支持交互式选择：可按分类、按仓库、全部或排除大型库；
# - 兼容 macOS 自带 bash 3.2（不使用关联数组、mapfile；也不用 set -u，避免空数组展开报错）

ACTION="install"
ORG="aukodeng-skill"
TOPIC="wife-legal"
ROOT=""
PROJECT="$(pwd)"
REPOS=()
CATEGORIES=()
ALL=0
INCLUDE_LARGE=0
NON_INTERACTIVE=0
OFFLINE=""
CONFIG=""
JSON=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="$REPO_ROOT/catalog.tsv"

usage()
{
    cat <<'EOF'
用法：deploy-wife-legal-skills.sh [选项]

  --action <list|status|scan|install|update|uninstall|enable|disable>  默认 install
  --repo <名称>        指定仓库，可重复或逗号分隔
  --category <分类>    指定业务分类，可重复或逗号分隔
  --all                全部仓库（仍不含大型库）
  --include-large      放开大型库（安装与启用都生效）
  --offline <zip>      离线压缩包：install 时从本地压缩包解压安装，不访问 GitHub
  --config <json>      选择配置：读取网页导出的 wife-legal-selection.json 作为选择来源
  --root <目录>        技能库根目录，默认 ~/Git/ai-skills/wife-legal
  --project <目录>     目标项目根目录（enable/disable 作用位置），默认当前目录
  --json               scan/status 输出 JSON（网页「导入本地状态」用）
  --org <组织>         默认 aukodeng-skill
  --topic <标签>       默认 wife-legal
  --non-interactive    不做交互菜单（使用默认全选或显式参数）
  -h, --help           显示帮助
EOF
}

while [ $# -gt 0 ]
do
    case "$1" in
        --action|-Action)        ACTION="${2:-}"; shift 2 ;;
        --repo|-Repo)            IFS=',' read -r -a _items <<< "${2:-}"
                                 for _i in "${_items[@]}"; do REPOS+=("$_i"); done; shift 2 ;;
        --category|-Category)    IFS=',' read -r -a _items <<< "${2:-}"
                                 for _i in "${_items[@]}"; do CATEGORIES+=("$_i"); done; shift 2 ;;
        --root|-Root)            ROOT="${2:-}"; shift 2 ;;
        --project|-Project)      PROJECT="${2:-}"; shift 2 ;;
        --org|-Org)              ORG="${2:-}"; shift 2 ;;
        --topic|-Topic)          TOPIC="${2:-}"; shift 2 ;;
        --all|-All)              ALL=1; shift ;;
        --include-large|-IncludeLarge) INCLUDE_LARGE=1; shift ;;
        --non-interactive|-NonInteractive) NON_INTERACTIVE=1; shift ;;
        --offline|-Offline)      OFFLINE="${2:-}"; shift 2 ;;
        --config|-Config)        CONFIG="${2:-}"; shift 2 ;;
        --json|-Json)            JSON=1; shift ;;
        -h|--help)               usage; exit 0 ;;
        *) echo "未知参数：$1" >&2; usage; exit 2 ;;
    esac
done

if [ ! -f "$CATALOG" ]
then
    echo "未找到分类清单：$CATALOG" >&2
    exit 1
fi

# 默认根目录：macOS/Linux 用 $HOME 下路径
if [ -z "$ROOT" ]
then
    ROOT="$HOME/Git/ai-skills/wife-legal"
fi

# ---------- 读取分类清单 ----------
C_REPO=()
C_CAT=()
C_LARGE=()
C_SKILLS=()
C_NOTE=()

while IFS=$'\t' read -r _repo _cat _upstream _large _skills _note
do
    [ -z "${_repo:-}" ] && continue
    [ "$_repo" = "repo" ] && continue
    _note="${_note%$'\r'}"
    C_REPO+=("$_repo")
    C_CAT+=("$_cat")
    C_LARGE+=("${_large:-0}")
    C_SKILLS+=("${_skills:--}")
    C_NOTE+=("${_note:-}")
done < <(tr -d '\r' < "$CATALOG")

CATALOG_COUNT=${#C_REPO[@]}
if [ "$CATALOG_COUNT" -eq 0 ]
then
    echo "分类清单为空：$CATALOG" >&2
    exit 1
fi

index_of_repo()
{
    local target="$1" i
    for ((i = 0; i < CATALOG_COUNT; i++))
    do
        if [ "${C_REPO[$i]}" = "$target" ]
        then
            echo "$i"
            return 0
        fi
    done
    return 1
}

# 按 topic 从组织仓库发现技能仓；网络不可用时返回 1（回落到 catalog）
discover_repos()
{
    command -v curl >/dev/null 2>&1 || return 1
    local page=1 body names=""
    while [ "$page" -le 10 ]
    do
        body="$(curl -sSL --max-time 20 \
            -H 'Accept: application/vnd.github.mercy-preview+json' \
            -H 'User-Agent: wife-legal-deploy' \
            "https://api.github.com/orgs/$ORG/repos?per_page=100&page=$page" 2>/dev/null)"
        [ -z "$body" ] && return 1
        case "$body" in
            \[*\]) ;;
            *) return 1 ;;
        esac
        local names_this_page
        # 逐仓提取 name 与 topics 片段，靠 "topics": 判断是否带目标标签
        names_this_page="$(printf '%s' "$body" | tr -d '\n' | sed 's/},{/}\n{/g' \
            | grep -F "\"$TOPIC\"" \
            | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
        if [ -n "$names_this_page" ]
        then
            names="$names"$'\n'"$names_this_page"
        fi
        # 一页不足 100 条说明已到末页
        local count
        count="$(printf '%s' "$body" | grep -o '"full_name"' | wc -l | tr -d ' ')"
        [ "$count" -lt 100 ] && break
        page=$((page + 1))
    done
    names="$(printf '%s' "$names" | sed '/^$/d' | sort -u)"
    [ -z "$names" ] && return 1
    DISCOVERED="$names"
    return 0
}

# 打印分类菜单并读入用户选择，输出选中的 catalog 下标（每行一个）
select_repos_interactive()
{
    # 按 catalog 顺序去重分类
    local cat_order=() i j exists
    for ((i = 0; i < CATALOG_COUNT; i++))
    do
        exists=0
        for ((j = 0; j < ${#cat_order[@]}; j++))
        do
            if [ "${cat_order[$j]}" = "${C_CAT[$i]}" ]
            then
                exists=1
                break
            fi
        done
        [ "$exists" -eq 0 ] && cat_order+=("${C_CAT[$i]}")
    done

    echo ""
    echo "可用技能分类："
    local n=1
    for ((j = 0; j < ${#cat_order[@]}; j++))
    do
        local cnt=0
        for ((i = 0; i < CATALOG_COUNT; i++))
        do
            [ "${C_CAT[$i]}" = "${cat_order[$j]}" ] && cnt=$((cnt + 1))
        done
        echo "  [$n] ${cat_order[$j]}（$cnt 个仓）"
        n=$((n + 1))
    done
    local all_index=$n
    echo "  [$all_index] 全部（不含大型库）"
    n=$((n + 1))
    local all_large_index=0
    if [ "$INCLUDE_LARGE" -eq 1 ]
    then
        all_large_index=$n
        echo "  [$all_large_index] 全部（含大型库）"
    fi

    echo ""
    echo "输入编号 / 分类名 / 仓库名（空格或逗号分隔），直接回车=全部（不含大型库）："
    local answer=""
    read -r answer || answer=""

    if [ -z "${answer// /}" ]
    then
        for ((i = 0; i < CATALOG_COUNT; i++))
        do
            [ "${C_LARGE[$i]}" = "1" ] || echo "$i"
        done
        return 0
    fi

    # 归一化分隔符后逐项匹配（用 sed 处理全角逗号，避免 tr 按字节截断多字节字符）
    answer="$(printf '%s' "$answer" | sed 's/，/ /g; s/,/ /g')"
    local token
    for token in $answer
    do
        case "$token" in
            ''|*[!0-9]*)
                local matched=0
                for ((i = 0; i < CATALOG_COUNT; i++))
                do
                    if [ "${C_CAT[$i]}" = "$token" ]
                    then
                        echo "$i"
                        matched=1
                    fi
                done
                if [ "$matched" -eq 1 ]
                then
                    continue
                fi
                for ((i = 0; i < CATALOG_COUNT; i++))
                do
                    if [ "${C_REPO[$i]}" = "$token" ]
                    then
                        echo "$i"
                        matched=1
                    fi
                done
                [ "$matched" -eq 0 ] && echo "未匹配的分类或仓库：$token" >&2
                ;;
            *)
                if [ "$token" -eq "$all_index" ]
                then
                    for ((i = 0; i < CATALOG_COUNT; i++))
                    do
                        [ "${C_LARGE[$i]}" = "1" ] || echo "$i"
                    done
                elif [ "$all_large_index" -ne 0 ] && [ "$token" -eq "$all_large_index" ]
                then
                    for ((i = 0; i < CATALOG_COUNT; i++))
                    do
                        echo "$i"
                    done
                elif [ "$token" -ge 1 ] && [ "$token" -lt "$all_index" ]
                then
                    local cat_name="${cat_order[$((token - 1))]}"
                    for ((i = 0; i < CATALOG_COUNT; i++))
                    do
                        [ "${C_CAT[$i]}" = "$cat_name" ] && echo "$i"
                    done
                else
                    echo "无效编号：$token" >&2
                fi
                ;;
        esac
    done
}

# 解析目标下标集合（去重、按仓库名排序），写入 SELECTED 数组
resolve_targets()
{
    local -a raw=()
    local i

    if [ "$ALL" -eq 1 ]
    then
        for ((i = 0; i < CATALOG_COUNT; i++)); do raw+=("$i"); done
    elif [ ${#REPOS[@]} -gt 0 ]
    then
        local r
        for r in "${REPOS[@]}"
        do
            if idx="$(index_of_repo "$r")"
            then
                raw+=("$idx")
            else
                echo "catalog.tsv 中没有仓库：$r" >&2
            fi
        done
    elif [ ${#CATEGORIES[@]} -gt 0 ]
    then
        local c hit
        for c in "${CATEGORIES[@]}"
        do
            hit=0
            for ((i = 0; i < CATALOG_COUNT; i++))
            do
                if [ "${C_CAT[$i]}" = "$c" ]
                then
                    raw+=("$i")
                    hit=1
                fi
            done
            [ "$hit" -eq 0 ] && echo "没有该分类：$c" >&2
        done
    elif [ "$NON_INTERACTIVE" -eq 1 ]
    then
        for ((i = 0; i < CATALOG_COUNT; i++))
        do
            [ "${C_LARGE[$i]}" = "1" ] || raw+=("$i")
        done
    else
        while IFS= read -r line
        do
            [ -n "$line" ] && raw+=("$line")
        done < <(select_repos_interactive)
    fi

    # 去重并按仓库名排序
    SELECTED=()
    if [ ${#raw[@]} -eq 0 ]
    then
        return 0
    fi
    local sorted
    sorted="$(for idx in "${raw[@]}"; do echo "${C_REPO[$idx]}	$idx"; done | sort -u -k1,1 | cut -f2)"
    while IFS= read -r idx
    do
        [ -n "$idx" ] && SELECTED+=("$idx")
    done <<< "$sorted"
}

show_catalog()
{
    local i last_cat=""
    for ((i = 0; i < CATALOG_COUNT; i++))
    do
        if [ "${C_CAT[$i]}" != "$last_cat" ]
        then
            echo ""
            echo "[${C_CAT[$i]}]"
            last_cat="${C_CAT[$i]}"
        fi
        local flag=""
        [ "${C_LARGE[$i]}" = "1" ] && flag="（大型库）"
        echo "  - ${C_REPO[$i]}$flag | ${C_SKILLS[$i]} 个技能 | ${C_NOTE[$i]}"
    done
}

invoke_install()
{
    mkdir -p "$ROOT"

    # 离线模式：从压缩包解压安装，不访问 GitHub（压缩包内为各仓顶层目录）
    if [ -n "$OFFLINE" ]
    then
        if [ ! -f "$OFFLINE" ]
        then
            echo "离线压缩包不存在：$OFFLINE（先从 Release 下载并放到部署仓目录）" >&2
            exit 1
        fi
        local tmp
        tmp="$(mktemp -d "${TMPDIR:-/tmp}/wife-legal-offline.XXXXXX")"
        unzip -q -o "$OFFLINE" -d "$tmp" || { echo "解压失败：$OFFLINE" >&2; rm -rf "$tmp"; exit 1; }
        local idx src dest
        for idx in "${SELECTED[@]}"
        do
            src="$tmp/${C_REPO[$idx]}"
            dest="$ROOT/${C_REPO[$idx]}"
            if [ ! -d "$src" ]
            then
                echo "离线包中没有仓库：${C_REPO[$idx]}" >&2
                continue
            fi
            if [ -d "$dest" ]
            then
                echo "跳过（已存在）：${C_REPO[$idx]}"
                continue
            fi
            mv "$src" "$dest"
            echo "离线安装：${C_REPO[$idx]}"
        done
        rm -rf "$tmp"
        return 0
    fi

    local idx dest
    for idx in "${SELECTED[@]}"
    do
        dest="$ROOT/${C_REPO[$idx]}"
        if [ -d "$dest" ]
        then
            echo "跳过（已存在）：${C_REPO[$idx]}"
            continue
        fi
        echo "克隆：${C_REPO[$idx]}"
        if ! git clone --depth 1 "https://github.com/$ORG/${C_REPO[$idx]}.git" "$dest"
        then
            echo "克隆失败：${C_REPO[$idx]}" >&2
        fi
    done
}

invoke_update()
{
    local idx dest
    for idx in "${SELECTED[@]}"
    do
        dest="$ROOT/${C_REPO[$idx]}"
        if [ ! -d "$dest" ]
        then
            echo "尚未安装，先克隆：${C_REPO[$idx]}"
            git clone --depth 1 "https://github.com/$ORG/${C_REPO[$idx]}.git" "$dest" || true
            continue
        fi
        echo "更新：${C_REPO[$idx]}"
        git -C "$dest" pull --ff-only || echo "更新失败：${C_REPO[$idx]}" >&2
    done
}

invoke_enable()
{
    local skills_root="$PROJECT/.trae/skills"
    mkdir -p "$skills_root"

    local idx src
    for idx in "${SELECTED[@]}"
    do
        src="$ROOT/${C_REPO[$idx]}"
        if [ ! -d "$src" ]
        then
            echo "未安装，跳过启用：${C_REPO[$idx]}（先执行 --action install）" >&2
            continue
        fi
        if [ "${C_LARGE[$idx]}" = "1" ] && [ "$INCLUDE_LARGE" -ne 1 ]
        then
            echo "大型库默认不启用：${C_REPO[$idx]}（追加 --include-large 强制启用）" >&2
            continue
        fi

        local count=0 prefix leaf target skill_dir
        while IFS= read -r skill_file
        do
            [ -z "$skill_file" ] && continue
            skill_dir="$(dirname "$skill_file")"
            leaf="$(basename "$skill_dir")"
            prefix="wife-legal-${C_REPO[$idx]}-$leaf"
            target="$skills_root/$prefix"
            # 同一仓库内同名目录自动加序号，避免互相覆盖
            local n=2
            while [ -d "$target" ]
            do
                target="$skills_root/$prefix-$n"
                n=$((n + 1))
            done
            rm -rf "$target"
            cp -R "$skill_dir" "$target"
            count=$((count + 1))
        done < <(find "$src" -name 'SKILL.md' -type f 2>/dev/null | sort)
        echo "启用：${C_REPO[$idx]} -> $count 个技能"
    done
}

invoke_disable()
{
    local skills_root="$PROJECT/.trae/skills"
    if [ ! -d "$skills_root" ]
    then
        echo "目标项目没有 .trae/skills，无需停用"
        return 0
    fi
    local idx count
    for idx in "${SELECTED[@]}"
    do
        count=0
        while IFS= read -r d
        do
            [ -z "$d" ] && continue
            rm -rf "$d"
            count=$((count + 1))
        done < <(find "$skills_root" -maxdepth 1 -type d -name "wife-legal-${C_REPO[$idx]}-*" 2>/dev/null)
        echo "停用：${C_REPO[$idx]}（移除 $count 个目录）"
    done
}

show_status()
{
    local skills_root="$PROJECT/.trae/skills"
    local i state enabled
    for ((i = 0; i < CATALOG_COUNT; i++))
    do
        if [ -d "$ROOT/${C_REPO[$i]}" ]
        then
            state="已安装"
        else
            state="未安装"
        fi
        enabled=0
        if [ -d "$skills_root" ]
        then
            enabled="$(find "$skills_root" -maxdepth 1 -type d -name "wife-legal-${C_REPO[$i]}-*" 2>/dev/null | wc -l | tr -d ' ')"
        fi
        printf '%-48s %-6s 已启用 %s\n' "${C_REPO[$i]}" "$state" "$enabled"
    done
}

# 删除技能库中已安装的仓（uninstall；只删技能库目录，启用目录用 disable 单独清理）
invoke_uninstall()
{
    local idx existing="" dest
    for idx in "${SELECTED[@]}"
    do
        dest="$ROOT/${C_REPO[$idx]}"
        [ -d "$dest" ] && existing="$existing$idx "
    done
    if [ -z "${existing// /}" ]
    then
        echo "所选仓库均未安装，无需删除"
        return 0
    fi

    # 交互确认（--non-interactive 跳过，便于脚本调用）
    if [ "$NON_INTERACTIVE" -ne 1 ]
    then
        echo "将删除以下仓库（位于 $ROOT）："
        for idx in $existing
        do
            echo "  - ${C_REPO[$idx]}"
        done
        printf '确认删除？输入 y 确认：'
        local answer=""
        read -r answer || answer=""
        case "$answer" in
            y|Y) ;;
            *) echo "已取消删除"; return 0 ;;
        esac
    fi

    for idx in $existing
    do
        rm -rf "$ROOT/${C_REPO[$idx]}"
        echo "已删除：${C_REPO[$idx]}"
    done
}

# 扫描本地安装状态；--json 时输出网页可导入的 JSON
show_scan()
{
    local skills_root="$PROJECT/.trae/skills"
    if [ "$JSON" -eq 1 ]
    then
        # JSON 手工拼装（bash 3.2 无 jq 依赖）
        printf '{\n'
        printf '  "type": "wife-legal-scan",\n'
        printf '  "version": 1,\n'
        printf '  "scannedAt": "%s",\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf '  "root": "%s",\n' "$ROOT"
        printf '  "project": "%s",\n' "$PROJECT"
        printf '  "repos": [\n'
        local i first=1 head enabled is_installed
        for ((i = 0; i < CATALOG_COUNT; i++))
        do
            if [ -d "$ROOT/${C_REPO[$i]}" ]
            then
                is_installed="true"
                head=""
                [ -d "$ROOT/${C_REPO[$i]}/.git" ] && head="$(git -C "$ROOT/${C_REPO[$i]}" rev-parse --short HEAD 2>/dev/null || true)"
            else
                is_installed="false"
                head=""
            fi
            enabled=0
            [ -d "$skills_root" ] && enabled="$(find "$skills_root" -maxdepth 1 -type d -name "wife-legal-${C_REPO[$i]}-*" 2>/dev/null | wc -l | tr -d ' ')"
            [ "$first" -eq 0 ] && printf ',\n'
            first=0
            printf '    {"repo": "%s", "category": "%s", "large": %s, "installed": %s, "enabled": %s, "head": %s}' \
                "${C_REPO[$i]}" "${C_CAT[$i]}" "${C_LARGE[$i]}" "$is_installed" "$enabled" "${head:+\"$head\"}${head:-null}"
        done
        printf '\n  ]\n}\n'
        return 0
    fi
    show_status
}

# ---------- 主流程 ----------

# 读取网页导出的选择配置（--config）：仓库清单并入选择，root / org / topic / offline 可一并接管
if [ -n "$CONFIG" ]
then
    if [ ! -f "$CONFIG" ]
    then
        echo "配置文件不存在：$CONFIG" >&2
        exit 1
    fi
    # bash 3.2 无 jq 依赖：按行抽取 "repo": "xxx" 字段（网页导出格式固定，每仓一行）
    cfg_count=0
    while IFS= read -r line
    do
        name="$(printf '%s' "$line" | sed -n 's/.*"repo"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
        [ -z "$name" ] && continue
        if [ ${#REPOS[@]} -eq 0 ]
        then
            REPOS+=("$name")
        fi
        cfg_count=$((cfg_count + 1))
    done < "$CONFIG"
    if [ "$cfg_count" -eq 0 ]
    then
        echo "配置文件里没有 repo 字段，确认是网页导出的 wife-legal-selection.json" >&2
        exit 1
    fi
    echo "已从配置读取 $cfg_count 个仓库选择（$CONFIG）"
    [ -z "$ROOT" ] && ROOT="$(sed -n 's/.*"root"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" | head -n 1)"
    cfg_org="$(sed -n 's/.*"org"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" | head -n 1)"
    [ -n "$cfg_org" ] && ORG="$cfg_org"
    cfg_topic="$(sed -n 's/.*"topic"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG" | head -n 1)"
    [ -n "$cfg_topic" ] && TOPIC="$cfg_topic"
    if [ -z "$OFFLINE" ] && grep -q '"mode"[[:space:]]*:[[:space:]]*"offline"' "$CONFIG"
    then
        OFFLINE="$REPO_ROOT/wife-legal-offline-bundle.zip"
    fi
fi

if discover_repos
then
    missing=""
    while IFS= read -r name
    do
        [ -z "$name" ] && continue
        index_of_repo "$name" >/dev/null || missing="$missing $name"
    done <<< "$DISCOVERED"
    if [ -n "$missing" ]
    then
        echo "以下仓库带 topic $TOPIC 但未登记到 catalog.tsv：$missing" >&2
    fi
else
    echo "按 topic 发现仓库失败，改用 catalog.tsv 清单" >&2
fi

case "$ACTION" in
    list)
        show_catalog
        echo ""
        echo "技能库根目录：$ROOT"
        ;;
    status)
        if [ "$JSON" -eq 1 ]
        then
            show_scan
        else
            show_status
        fi
        ;;
    scan)
        show_scan
        ;;
    install|update|uninstall|enable|disable)
        resolve_targets
        if [ ${#SELECTED[@]} -eq 0 ]
        then
            echo "没有选中任何仓库" >&2
            exit 1
        fi
        echo ""
        echo "技能库根目录：$ROOT"
        echo "目标项目：$PROJECT"
        echo ""
        case "$ACTION" in
            install)   invoke_install ;;
            update)    invoke_update ;;
            uninstall) invoke_uninstall ;;
            enable)    invoke_enable ;;
            disable)   invoke_disable ;;
        esac
        ;;
    *)
        echo "未知动作：$ACTION" >&2
        usage
        exit 2
        ;;
esac
