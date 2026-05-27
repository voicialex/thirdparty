#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

ARCH=$(detect_arch "${1:-}")
HOST_ARCH=$(detect_arch "$(uname -m)")
PARALLEL="${PARALLEL_WORKERS:-$(nproc)}"
OUTPUT_DIR="$PROJECT_DIR/output/${ARCH}/opencv"
OPENCV_SRC="$PROJECT_DIR/third_party/opencv"

if [[ -f "$OUTPUT_DIR/lib/libopencv_core.so" ]]; then
    log_skip "OpenCV ($ARCH) already built"
    exit 0
fi

log_stage "Building OpenCV ($ARCH)"

BUILD_DIR="$PROJECT_DIR/output/.build/opencv_${ARCH}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# Cross-compilation support
cmake_extra_flags=""
if [[ "$ARCH" != "$HOST_ARCH" ]]; then
    log_step "Cross-compiling for $ARCH on $HOST_ARCH host"
    if [[ "$ARCH" == "aarch64" ]]; then
        cmake_extra_flags="-DCMAKE_TOOLCHAIN_FILE=$PROJECT_DIR/docker/toolchain-aarch64.cmake"
    else
        log_err "Cross-compilation to $ARCH not supported"
        exit 1
    fi
fi

cmake "$OPENCV_SRC" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
    -DBUILD_LIST=core,imgproc,imgcodecs,objdetect \
    -DBUILD_SHARED_LIBS=ON \
    -DWITH_GDAL=OFF -DWITH_GDCM=OFF -DWITH_FFMPEG=OFF \
    -DWITH_GSTREAMER=OFF -DWITH_V4L=OFF -DWITH_GTK=OFF \
    -DWITH_QT=OFF -DWITH_OPENCL=OFF -DWITH_CUDA=OFF \
    -DWITH_IPP=OFF -DWITH_LAPACK=OFF -DWITH_WEBP=OFF \
    -DWITH_OPENJPEG=ON -DWITH_PNG=ON -DWITH_JPEG=ON \
    -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF -DBUILD_DOCS=OFF \
    -DBUILD_opencv_python3=OFF \
    -DBUILD_ZLIB=ON -DBUILD_PNG=ON -DBUILD_OPENJPEG=ON -DBUILD_JPEG=ON \
    -DBUILD_TIFF=ON -DBUILD_OPENEXR=ON \
    $cmake_extra_flags

make -j"$PARALLEL"
make install

log_ok "OpenCV ($ARCH) → $OUTPUT_DIR"
