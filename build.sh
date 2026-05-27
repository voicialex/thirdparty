#!/usr/bin/env bash
set -euo pipefail

START_TIME=$SECONDS
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

# ── Defaults ─────────────────────────────────────────────────
ARCH="$(uname -m)"
TARGETS=()
CLEAN=false
PARALLEL="${PARALLEL_WORKERS:-$(nproc)}"

# ── Usage ────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: ./build.sh [OPTIONS] [TARGETS...]

Prerequisites:
  ./scripts/update_src.sh             # Sync third-party sources first

Targets:
  onnxruntime   Download ONNX Runtime (official release)
  sherpa        Download Sherpa-ONNX (official release)
  opencv        Build OpenCV from source (third_party/opencv)
  libcurl       Build libcurl from source (third_party/curl)
  funasr        Build FunASR from source (requires onnxruntime)
  rknn          Extract RKNN runtime (aarch64 only)
  ros2          Alias for opencv (ros2_core 只依赖 OpenCV)
  (none)        All of the above

Options:
  -t, --target <arch>   Target arch: x86_64 | arm64 | aarch64 (default: host)
  -j <N>                Parallel workers (default: nproc)
  -c, --clean           Remove output/ and exit
  -h, --help            Show this help

Examples:
  ./scripts/update_src.sh              # First time: sync sources
  ./build.sh                           # Download + build all for native x86_64
  ./build.sh -t arm64                  # All for arm64 (downloads + Docker cross-compile)

  Individual targets (independent, no coupling):
  ./build.sh opencv                    # Only build OpenCV (native)
  ./build.sh libcurl                   # Only build libcurl (native)
  ./build.sh -t arm64 opencv          # Only cross-compile OpenCV for arm64
  ./build.sh -t arm64 libcurl         # Only cross-compile libcurl for arm64
  ./build.sh opencv libcurl           # Build both (native, sequential)

  Other targets:
  ./build.sh onnxruntime sherpa       # Only download runtime deps
  ./build.sh -c                       # Clean all outputs
EOF
    exit 0
}

# ── Parse args ───────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--target) ARCH="$2"; shift 2 ;;
        -j) PARALLEL="$2"; shift 2 ;;
        -c|--clean) CLEAN=true; shift ;;
        -h|--help) usage ;;
        onnxruntime|sherpa|opencv|funasr|rknn|libcurl) TARGETS+=("$1"); shift ;;
        ros2) TARGETS+=(opencv); shift ;;
        *) log_err "Unknown argument: $1"; usage ;;
    esac
done

ARCH=$(detect_arch "$ARCH")

if [[ "$CLEAN" == true ]]; then
    rm -rf "$SCRIPT_DIR/output"
    log_ok "Cleaned output/"
    exit 0
fi

# Default: all targets
if [[ ${#TARGETS[@]} -eq 0 ]]; then
    TARGETS=(onnxruntime sherpa opencv libcurl funasr rknn)
fi

# ── Dispatch ─────────────────────────────────────────────────
HOST_ARCH=$(detect_arch)
export PARALLEL_WORKERS="$PARALLEL"

if [[ "$ARCH" != "$HOST_ARCH" ]]; then
    # Cross-compile path: downloads run natively, source builds via Docker

    # Step 1: Download targets (arch-specific downloads, no Docker needed)
    for target in "${TARGETS[@]}"; do
        case "$target" in
            onnxruntime) "$SCRIPT_DIR/scripts/build_onnxruntime.sh" "$ARCH" ;;
            sherpa)      "$SCRIPT_DIR/scripts/build_sherpa.sh" "$ARCH" ;;
            rknn)        ARCH="$ARCH" "$SCRIPT_DIR/scripts/build_rknn.sh" ;;
        esac
    done

    # Step 2: Source builds via Docker (if opencv, libcurl, or funasr requested)
    NEED_DOCKER=false
    for target in "${TARGETS[@]}"; do
        [[ "$target" == "opencv" || "$target" == "libcurl" || "$target" == "funasr" ]] && NEED_DOCKER=true
    done

    if [[ "$NEED_DOCKER" == true ]]; then
        # Docker needs onnxruntime for FunASR build (if funasr requested)
        NEED_FUNASR=false
        for target in "${TARGETS[@]}"; do
            [[ "$target" == "funasr" ]] && NEED_FUNASR=true
        done

        # Ensure prebuilt directory structure exists for Docker COPY
        # (Docker COPY is unconditional even if RUN is conditional)
        mkdir -p "$SCRIPT_DIR/prebuilt/$ARCH/onnxruntime"

        if [[ "$NEED_FUNASR" == true ]]; then
            ORT_DIR="$SCRIPT_DIR/output/$ARCH/onnxruntime"
            if [[ ! -d "$ORT_DIR/lib" ]]; then
                log_err "Missing: output/$ARCH/onnxruntime/"
                echo "  Run: ./build.sh -t $ARCH onnxruntime" >&2
                exit 1
            fi

            # Copy onnxruntime into prebuilt/ for Docker context
            # (Docker cannot follow symlinks pointing outside build context)
            cp -a "$ORT_DIR/." "$SCRIPT_DIR/prebuilt/$ARCH/onnxruntime/"
        fi

        log_stage "Cross-compile for $ARCH (Docker)"

        # Build target list for Docker
        DOCKER_TARGETS=""
        for target in "${TARGETS[@]}"; do
            case "$target" in
                opencv|libcurl|funasr) DOCKER_TARGETS="$DOCKER_TARGETS $target" ;;
            esac
        done

        DOCKER_BUILDKIT=1 docker build \
            --build-arg PARALLEL_WORKERS="$PARALLEL" \
            --build-arg "BUILD_TARGETS=${DOCKER_TARGETS# }" \
            --output "type=local,dest=$SCRIPT_DIR/output/$ARCH/" \
            -f "$SCRIPT_DIR/docker/Dockerfile.arm64" \
            "$SCRIPT_DIR"

        # Cleanup temporary copy
        if [[ "$NEED_FUNASR" == true ]]; then
            rm -rf "$SCRIPT_DIR/prebuilt"
        fi

        log_ok "Cross-compile done → output/$ARCH/"
    fi
else
    # Native build path
    for target in "${TARGETS[@]}"; do
        case "$target" in
            onnxruntime) "$SCRIPT_DIR/scripts/build_onnxruntime.sh" ;;
            sherpa)      "$SCRIPT_DIR/scripts/build_sherpa.sh" ;;
            opencv)      "$SCRIPT_DIR/scripts/build_opencv.sh" ;;
            libcurl)     "$SCRIPT_DIR/scripts/build_libcurl.sh" ;;
            funasr)
                # FunASR needs onnxruntime — auto-detect from output/
                if [[ -z "${ONNXRUNTIME_DIR:-}" ]]; then
                    export ONNXRUNTIME_DIR="$SCRIPT_DIR/output/$ARCH/onnxruntime"
                fi
                "$SCRIPT_DIR/scripts/build_funasr.sh"
                ;;
            rknn) ARCH="$ARCH" "$SCRIPT_DIR/scripts/build_rknn.sh" ;;
        esac
    done
fi

# ── Package tarball ──────────────────────────────────────
OUTPUT_DIR="$SCRIPT_DIR/output/$ARCH"
if [[ -d "$OUTPUT_DIR" ]]; then
    TARBALL="$SCRIPT_DIR/output/$ARCH/thirdparty-${ARCH}.tar.gz"
    echo "[INFO] 打包 thirdparty-${ARCH}.tar.gz..."
    tar czf "$SCRIPT_DIR/output/.tmp-tarball.tar.gz" -C "$OUTPUT_DIR" --exclude="thirdparty-${ARCH}.tar.gz" .
    mv "$SCRIPT_DIR/output/.tmp-tarball.tar.gz" "$TARBALL"
    ELAPSED=$(( SECONDS - START_TIME ))
    echo "[OK] 产物: ${TARBALL} ($(du -sh "$TARBALL" | cut -f1))"
    echo "[OK] 总耗时: $((ELAPSED/60))分$((ELAPSED%60))秒"
fi
