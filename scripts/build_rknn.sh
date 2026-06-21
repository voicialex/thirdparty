#!/usr/bin/env bash
# Download RKNN runtime (lib + headers) from GitHub — no compilation needed.
# Only provides aarch64 (RKNN is ARM-only hardware).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ARCH="${ARCH:-aarch64}"
OUTPUT_DIR="${SCRIPT_DIR}/../output/${ARCH}/rknn"

# ── Version ─────────────────────────────────────────────────
RKNN_VERSION="v2.3.2"
RKNN_BASE="https://raw.githubusercontent.com/airockchip/rknn-toolkit2/${RKNN_VERSION}/rknpu2/runtime/Linux/librknn_api"

if [[ "$ARCH" != "aarch64" ]]; then
    log_skip "RKNN (${ARCH}) — only available for aarch64"
    exit 0
fi

if [[ -f "$OUTPUT_DIR/lib/librknnrt.so" ]]; then
    log_skip "RKNN ${RKNN_VERSION} (${ARCH}) already downloaded"
    exit 0
fi

log_stage "Downloading RKNN runtime ${RKNN_VERSION} (${ARCH})"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/lib" "$OUTPUT_DIR/include"

download "$RKNN_BASE/aarch64/librknnrt.so" "$OUTPUT_DIR/lib/librknnrt.so"
download "$RKNN_BASE/include/rknn_api.h"   "$OUTPUT_DIR/include/rknn_api.h"
download "$RKNN_BASE/include/rknn_custom_op.h"  "$OUTPUT_DIR/include/rknn_custom_op.h"
download "$RKNN_BASE/include/rknn_matmul_api.h" "$OUTPUT_DIR/include/rknn_matmul_api.h"

log_ok "RKNN ${RKNN_VERSION} (${ARCH}) → $OUTPUT_DIR"
