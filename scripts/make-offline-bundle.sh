#!/usr/bin/env bash
# 手动生成离线压缩包（本机有网时兜底用；线上以 GitHub Actions 生成的 Release 为准）
# 用法：在部署仓根目录执行
#   ./scripts/make-offline-bundle.sh [输出zip路径]
# 产物：各技能仓顶层目录 + catalog.tsv + index.html 打成一个 zip，
#       与 Release 里的 wife-legal-offline-bundle.zip 结构一致。

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="$REPO_ROOT/catalog.tsv"
ORG="aukodeng-skill"
OUT="${1:-$REPO_ROOT/wife-legal-offline-bundle.zip}"

if [ ! -f "$CATALOG" ]; then
    echo "未找到分类清单：$CATALOG" >&2
    exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/wife-legal-bundle.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

cp "$CATALOG" "$WORK/"
[ -f "$REPO_ROOT/index.html" ] && cp "$REPO_ROOT/index.html" "$WORK/"

tail -n +2 "$CATALOG" | cut -f1 | while read -r repo; do
    [ -z "$repo" ] && continue
    echo "克隆：$repo"
    git clone --depth 1 "https://github.com/$ORG/${repo}.git" "$WORK/$repo"
    rm -rf "$WORK/$repo/.git"
done

rm -f "$OUT"
(cd "$WORK" && zip -q -r -X "$OUT" .)
echo "完成：$OUT"
ls -lh "$OUT"
