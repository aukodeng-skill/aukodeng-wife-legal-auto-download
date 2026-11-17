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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="$REPO_ROOT/catalog.tsv"

usage()
{
    cat <<'EOF'
用法：deploy-wife-legal-skills.sh [选项]

  --action <list|status|install|update|enable|disable>  默认 install
  --repo <名称>        指定仓库，可重复或逗号分隔
  --category <分类>    指定业务分类，可重复或逗号分隔
  --all                全部仓库（仍不含大型库）
  --include-large      放开大型库（安装与启用都生效）
  --root <目录>        技能库根目录，默认 ~/Git/ai-skills/wife-legal
  --project <目录>     目标项目根目录（enable/disable 作用位置），默认当前目录
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

# ---------- 主流程 ----------
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
        show_status
        ;;
    install|update|enable|disable)
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
            install) invoke_install ;;
            update)  invoke_update ;;
            enable)  invoke_enable ;;
            disable) invoke_disable ;;
        esac
        ;;
    *)
        echo "未知动作：$ACTION" >&2
        usage
        exit 2
        ;;
esac
