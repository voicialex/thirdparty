#!/usr/bin/env bash
# update_src.sh — 以 repos/thirdparty.repos 为唯一真相源，同步第三方源码
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SRC_DIR="$REPO_ROOT/third_party"
REPOS_FILE="$REPO_ROOT/repos/thirdparty.repos"

usage() {
    cat <<EOF
用法: ./scripts/update_src.sh [OPTIONS]

从 repos/thirdparty.repos 同步源码到 third_party/。
同步后删除 .git，源码作为普通文件纳入主仓库管理。

选项:
  -c, --clean   删除 third_party/ 并重新克隆
  -h, --help    显示此帮助

示例:
  ./scripts/update_src.sh          # 同步/更新源码
  ./scripts/update_src.sh --clean  # 完全重建
EOF
}

CLEAN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--clean) CLEAN=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "错误: 未知参数 $1"; usage; exit 1 ;;
    esac
done

ensure_vcstool() {
    command -v vcs &>/dev/null || pip3 install vcstool
}

get_wanted_repos() {
    grep -E '^ {2}[a-zA-Z0-9_./-]+:$' "$REPOS_FILE" | sed 's/^  //;s/:$//'
}

remove_stale_repos() {
    local wanted="$1"
    [ -d "$SRC_DIR" ] || return 0

    for dir in "$SRC_DIR"/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        if ! echo "$wanted" | grep -qx "$name"; then
            echo "[INFO] 移除不在 .repos 中的仓库: $name"
            rm -rf "$dir"
        fi
    done
}

import_repos() {
    echo "[INFO] 同步源码..."
    vcs import --skip-existing "$SRC_DIR" < "$REPOS_FILE"
}

postprocess_src() {
    find "$SRC_DIR" -name .git -type d -prune -exec rm -rf {} + 2>/dev/null || true
}

# ─── main ───

[ -f "$REPOS_FILE" ] || { echo "错误: $REPOS_FILE 不存在"; exit 1; }

if [[ "$CLEAN" == true ]]; then
    echo "[CLEAN] 删除 $SRC_DIR"
    rm -rf "$SRC_DIR"
fi

mkdir -p "$SRC_DIR"
ensure_vcstool

WANTED=$(get_wanted_repos)
remove_stale_repos "$WANTED"
import_repos
postprocess_src

# 验证
missing=0
while IFS= read -r name; do
    if [ ! -d "$SRC_DIR/$name" ]; then
        echo "[ERROR] 缺失: third_party/$name"
        missing=1
    fi
done <<< "$WANTED"
[ "$missing" -eq 0 ] || exit 1

COUNT=$(echo "$WANTED" | grep -c . || true)
echo "[OK] 已同步 $COUNT 个仓库到 third_party/"
echo "请 git add third_party/ && git commit"
