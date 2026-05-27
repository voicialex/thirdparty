#!/usr/bin/env bash
# Extract RKNN runtime (lib + headers) from submodule — no compilation needed.
# Only provides aarch64 (RKNN is ARM-only hardware).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ARCH="${ARCH:-aarch64}"
OUTPUT_DIR="${SCRIPT_DIR}/../output/${ARCH}/rknn"
RKNN_SRC="${SCRIPT_DIR}/../third_party/rknn-toolkit2/rknpu2/runtime/Linux/librknn_api"

if [[ "$ARCH" != "aarch64" ]]; then
    log_skip "RKNN (${ARCH}) — only available for aarch64"
    exit 0
fi

if [[ -f "$OUTPUT_DIR/lib/librknnrt.so" ]]; then
    log_skip "RKNN (${ARCH}) already extracted"
    exit 0
fi

log_stage "Extracting RKNN runtime (${ARCH})"

if [[ ! -d "$RKNN_SRC/aarch64" ]]; then
    log_err "RKNN source not found at: $RKNN_SRC"
    echo "  Run: ./scripts/update_src.sh"
    exit 1
fi

mkdir -p "$OUTPUT_DIR/lib" "$OUTPUT_DIR/include"
cp -f "$RKNN_SRC/aarch64/librknnrt.so" "$OUTPUT_DIR/lib/"
cp -f "$RKNN_SRC/include/"*.h "$OUTPUT_DIR/include/"

log_ok "RKNN (${ARCH}) → $OUTPUT_DIR"
