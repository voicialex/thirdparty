#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

# Parse flags
GPU=false
POSITIONAL=()
for arg in "${@}"; do
    case "$arg" in
        --gpu) GPU=true ;;
        *) POSITIONAL+=("$arg") ;;
    esac
done

ARCH=$(detect_arch "${POSITIONAL[0]:-}")

# ── Versions ─────────────────────────────────────────────────
ONNXRT_VERSION="1.24.4"

if [[ "$GPU" == true ]]; then
    # GPU variant: x86_64 only (no aarch64 GPU builds)
    if [[ "$ARCH" != "x86_64" ]]; then
        log_skip "ONNX Runtime GPU — x86_64 only"
        exit 0
    fi
    OUTPUT_DIR="$PROJECT_DIR/output/${ARCH}/onnxruntime-gpu"
    ONNXRT_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ONNXRT_VERSION}/onnxruntime-linux-x64-gpu-${ONNXRT_VERSION}.tgz"
    TMP_DIR_NAME="onnxruntime-linux-x64-gpu-${ONNXRT_VERSION}"
    LABEL="ONNX Runtime GPU v${ONNXRT_VERSION}"
else
    case "$ARCH" in
        x86_64)  ARCH_ORT="x64" ;;
        aarch64) ARCH_ORT="aarch64" ;;
    esac
    OUTPUT_DIR="$PROJECT_DIR/output/${ARCH}/onnxruntime"
    ONNXRT_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ONNXRT_VERSION}/onnxruntime-linux-${ARCH_ORT}-${ONNXRT_VERSION}.tgz"
    TMP_DIR_NAME="onnxruntime-linux-${ARCH_ORT}-${ONNXRT_VERSION}"
    LABEL="ONNX Runtime v${ONNXRT_VERSION}"
fi

# ── Skip check ───────────────────────────────────────────────
ort_version_installed() {
    [ -f "$1/lib/libonnxruntime.so.${ONNXRT_VERSION}" ]
}

if ort_version_installed "$OUTPUT_DIR"; then
    log_skip "$LABEL ($ARCH)"
    exit 0
fi

# Remove incompatible version if present
if [[ -d "$OUTPUT_DIR" ]]; then
    log_step "Replacing incompatible $LABEL ($ARCH) ..."
    rm -rf "$OUTPUT_DIR"
fi

log_stage "Downloading $LABEL ($ARCH)"

# ── Download + extract ───────────────────────────────────────
TMP_DIR="$PROJECT_DIR/output/.tmp"
mkdir -p "$TMP_DIR"
TMP_FILE="$TMP_DIR/onnxruntime$([ "$GPU" == true ] && echo '-gpu')-${ARCH}.tgz"

download "$ONNXRT_URL" "$TMP_FILE" || { log_err "Download failed"; exit 1; }

mkdir -p "$OUTPUT_DIR"
tar xzf "$TMP_FILE" -C "$TMP_DIR"
mv "$TMP_DIR/${TMP_DIR_NAME}"/* "$OUTPUT_DIR/"
rm -rf "$TMP_FILE" "$TMP_DIR/${TMP_DIR_NAME}"

log_ok "$LABEL ($ARCH) → $OUTPUT_DIR"
