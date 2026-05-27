#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

ARCH=$(detect_arch "${1:-}")
PARALLEL="${PARALLEL_WORKERS:-$(nproc)}"
OUTPUT_DIR="$PROJECT_DIR/output/${ARCH}/funasr"
FUNASR_SRC="$PROJECT_DIR/third_party/funasr-runtime"

# ORT is a build dependency — caller must provide path
ONNXRUNTIME_DIR="${ONNXRUNTIME_DIR:-}"
if [[ -z "$ONNXRUNTIME_DIR" ]]; then
    for candidate in \
        "$PROJECT_DIR/../buddy/prebuilt/${ARCH}/onnxruntime" \
        "$PROJECT_DIR/../buddy/prebuilt/current/onnxruntime"; do
        if [[ -d "$candidate" ]]; then
            ONNXRUNTIME_DIR="$(cd "$candidate" && pwd)"
            break
        fi
    done
fi

if [[ -z "$ONNXRUNTIME_DIR" || ! -d "$ONNXRUNTIME_DIR" ]]; then
    log_err "ONNXRUNTIME_DIR not set or not found."
    echo "  Set: export ONNXRUNTIME_DIR=/path/to/onnxruntime" >&2
    exit 1
fi

if [[ -f "$OUTPUT_DIR/bin/funasr-wss-server" ]]; then
    log_skip "FunASR ($ARCH) already built"
    exit 0
fi

log_stage "Building FunASR ($ARCH)"
log_step "Using ONNXRUNTIME_DIR=$ONNXRUNTIME_DIR"

BUILD_DIR="$PROJECT_DIR/output/.build/funasr_${ARCH}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

cmake "$FUNASR_SRC/runtime/websocket" \
    -DCMAKE_BUILD_TYPE=Release \
    -DONNXRUNTIME_DIR="$ONNXRUNTIME_DIR" \
    -DENABLE_PORTAUDIO=OFF \
    -DCMAKE_CXX_FLAGS="-fpermissive"

make -j"$PARALLEL" funasr-wss-server funasr-wss-server-2pass 2>/dev/null \
    || make -j"$PARALLEL" funasr-wss-server

mkdir -p "$OUTPUT_DIR/bin" "$OUTPUT_DIR/lib"
cp -f "$BUILD_DIR/bin/funasr-wss-server" "$OUTPUT_DIR/bin/"
cp -f "$BUILD_DIR/bin/funasr-wss-server-2pass" "$OUTPUT_DIR/bin/" 2>/dev/null || true
find "$BUILD_DIR" -name "*.so*" -type f -exec cp -n {} "$OUTPUT_DIR/lib/" \;
find "$BUILD_DIR" -name "*.so*" -type l -exec cp -nP {} "$OUTPUT_DIR/lib/" \;

log_ok "FunASR ($ARCH) → $OUTPUT_DIR"
