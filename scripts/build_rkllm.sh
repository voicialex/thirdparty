#!/usr/bin/env bash
# Download RKLLM runtime (lib + header) from GitHub — no compilation needed.
# Only provides aarch64 (RKLLM is ARM-only hardware).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ARCH="${ARCH:-aarch64}"
OUTPUT_DIR="${SCRIPT_DIR}/../output/${ARCH}/rkllm"

# ── Version ─────────────────────────────────────────────────
RKLLM_VERSION="v1.2.3"
RKLLM_TAG="release-v1.2.3"
RKLLM_BASE="https://raw.githubusercontent.com/airockchip/rknn-llm/${RKLLM_TAG}/rkllm-runtime/Linux/librkllm_api"

if [[ "$ARCH" != "aarch64" ]]; then
    log_skip "RKLLM (${ARCH}) — only available for aarch64"
    exit 0
fi

if [[ -s "$OUTPUT_DIR/lib/librkllmrt.so" ]] && [[ -s "$OUTPUT_DIR/include/rkllm.h" ]]; then
    log_skip "RKLLM ${RKLLM_VERSION} (${ARCH}) already downloaded"
    exit 0
fi

log_stage "Downloading RKLLM runtime ${RKLLM_VERSION} (${ARCH})"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/lib" "$OUTPUT_DIR/include"

download "$RKLLM_BASE/aarch64/librkllmrt.so" "$OUTPUT_DIR/lib/librkllmrt.so" || { log_err "Download failed: librkllmrt.so"; exit 1; }
download "$RKLLM_BASE/include/rkllm.h"   "$OUTPUT_DIR/include/rkllm.h" || { log_err "Download failed: rkllm.h"; exit 1; }

log_ok "RKLLM ${RKLLM_VERSION} (${ARCH}) → $OUTPUT_DIR"
