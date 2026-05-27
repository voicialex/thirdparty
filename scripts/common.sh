#!/usr/bin/env bash
# Shared utility functions for build scripts

log_stage() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

log_step()  { echo "  [..] $1"; }
log_ok()    { echo "  [ok] $1"; }
log_skip()  { echo "  [--] $1 (skipped)"; }
log_err()   { echo "  [!!] $1" >&2; }

detect_arch() {
    local arch="${1:-$(uname -m)}"
    case "$arch" in
        x86_64|amd64|x86) echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        *) log_err "Unsupported arch: $arch"; exit 1 ;;
    esac
}

download() {
    local url="$1" dest="$2"
    log_step "Downloading: $(basename "$dest")"
    wget --quiet --timeout=0 --tries=3 --continue --show-progress --progress=bar:force \
        -O "$dest" "$url" || return 1
    if [[ ! -s "$dest" ]]; then
        rm -f "$dest"
        return 1
    fi
}
