#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

ARCH=$(detect_arch "${1:-}")
OUTPUT_DIR="$PROJECT_DIR/output/${ARCH}/sherpa-onnx"

# ── Versions ─────────────────────────────────────────────────
SHERPA_VERSION="1.13.1"

# Arch mapping + package variant
case "$ARCH" in
    x86_64)
        ARCH_SHERPA="x64"
        SHERPA_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/v${SHERPA_VERSION}/sherpa-onnx-v${SHERPA_VERSION}-linux-${ARCH_SHERPA}-shared.tar.bz2"
        SHERPA_EXTRACT_DIR="sherpa-onnx-v${SHERPA_VERSION}-linux-${ARCH_SHERPA}-shared"
        ;;
    aarch64)
        ARCH_SHERPA="aarch64"
        SHERPA_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/v${SHERPA_VERSION}/sherpa-onnx-v${SHERPA_VERSION}-linux-${ARCH_SHERPA}-shared-cpu.tar.bz2"
        SHERPA_EXTRACT_DIR="sherpa-onnx-v${SHERPA_VERSION}-linux-${ARCH_SHERPA}-shared-cpu"
        ;;
esac

# ── Skip check ───────────────────────────────────────────────
if [[ -f "$OUTPUT_DIR/lib/libsherpa-onnx-c-api.so" ]]; then
    log_skip "Sherpa-ONNX v${SHERPA_VERSION} ($ARCH)"
    exit 0
fi

log_stage "Downloading Sherpa-ONNX v${SHERPA_VERSION} ($ARCH)"

# ── Download + extract ───────────────────────────────────────
TMP_DIR="$PROJECT_DIR/output/.tmp"
mkdir -p "$TMP_DIR"
TMP_FILE="$TMP_DIR/sherpa-onnx-${ARCH}.tar.bz2"

download "$SHERPA_URL" "$TMP_FILE" || { log_err "Download failed"; exit 1; }

tar xjf "$TMP_FILE" -C "$TMP_DIR"
mv "$TMP_DIR/${SHERPA_EXTRACT_DIR}" "$OUTPUT_DIR"
rm -f "$TMP_FILE"

# arm64 package lacks headers — copy from x86 if available
if [[ ! -d "$OUTPUT_DIR/include" ]]; then
    local_x86="$PROJECT_DIR/output/x86_64/sherpa-onnx/include"
    if [[ -d "$local_x86" ]]; then
        cp -r "$local_x86" "$OUTPUT_DIR/include"
        log_step "Copied headers from x86 package"
    else
        log_step "Warning: no include/ dir (build x86 first for headers)"
    fi
fi

log_ok "Sherpa-ONNX v${SHERPA_VERSION} ($ARCH) → $OUTPUT_DIR"
