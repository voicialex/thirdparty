#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

ARCH=$(detect_arch "${1:-}")
OUTPUT_DIR="$PROJECT_DIR/output/${ARCH}/onnxruntime"

# ── Versions ─────────────────────────────────────────────────
ONNXRT_VERSION="1.21.0"

# Arch mapping for download URL
case "$ARCH" in
    x86_64)  ARCH_ORT="x64" ;;
    aarch64) ARCH_ORT="aarch64" ;;
esac

ONNXRT_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ONNXRT_VERSION}/onnxruntime-linux-${ARCH_ORT}-${ONNXRT_VERSION}.tgz"

# ── Skip check ───────────────────────────────────────────────
if [[ -f "$OUTPUT_DIR/lib/libonnxruntime.so" ]]; then
    log_skip "ONNX Runtime v${ONNXRT_VERSION} ($ARCH)"
    exit 0
fi

log_stage "Downloading ONNX Runtime v${ONNXRT_VERSION} ($ARCH)"

# ── Download + extract ───────────────────────────────────────
TMP_DIR="$PROJECT_DIR/output/.tmp"
mkdir -p "$TMP_DIR"
TMP_FILE="$TMP_DIR/onnxruntime-${ARCH}.tgz"

download "$ONNXRT_URL" "$TMP_FILE" || { log_err "Download failed"; exit 1; }

mkdir -p "$OUTPUT_DIR"
tar xzf "$TMP_FILE" -C "$TMP_DIR"
# Move contents (strip top-level dir)
mv "$TMP_DIR/onnxruntime-linux-${ARCH_ORT}-${ONNXRT_VERSION}"/* "$OUTPUT_DIR/"
rm -rf "$TMP_FILE" "$TMP_DIR/onnxruntime-linux-${ARCH_ORT}-${ONNXRT_VERSION}"

log_ok "ONNX Runtime v${ONNXRT_VERSION} ($ARCH) → $OUTPUT_DIR"
