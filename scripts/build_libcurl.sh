#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

ARCH=$(detect_arch "${1:-}")
HOST_ARCH=$(detect_arch "$(uname -m)")
PARALLEL="${PARALLEL_WORKERS:-$(nproc)}"
OUTPUT_DIR="$PROJECT_DIR/output/${ARCH}/libcurl"
CURL_SRC="$PROJECT_DIR/third_party/curl"

# ── Skip check ───────────────────────────────────────────────
if [[ -f "$OUTPUT_DIR/lib/libcurl.so" ]]; then
    log_skip "libcurl ($ARCH) already built"
    exit 0
fi

log_stage "Building libcurl ($ARCH)"

# ── Check submodule ──────────────────────────────────────────
if [[ ! -d "$CURL_SRC" ]]; then
    log_err "curl source not found at $CURL_SRC"
    echo "  Run: ./scripts/update_src.sh" >&2
    exit 1
fi

# ── Build directory ──────────────────────────────────────────
BUILD_DIR="$PROJECT_DIR/output/.build/libcurl_${ARCH}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# ── Cross-compilation support ────────────────────────────────
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

# ── Configure ────────────────────────────────────────────────
cmake "$CURL_SRC" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_STATIC_LIBS=OFF \
    -DBUILD_CURL_EXE=OFF \
    -DBUILD_TESTING=OFF \
    -DCURL_DISABLE_LDAP=ON \
    -DCURL_USE_OPENSSL=OFF \
    -DCURL_USE_GNUTLS=OFF \
    -DCURL_USE_MBEDTLS=OFF \
    -DCURL_USE_WOLFSSL=OFF \
    -DCURL_USE_LIBPSL=OFF \
    -DCURL_USE_LIBIDN2=OFF \
    -DUSE_NGHTTP2=OFF \
    -DCURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    -DCURL_CA_PATH=/etc/ssl/certs \
    $cmake_extra_flags

# ── Build + install ──────────────────────────────────────────
log_stage "Compiling"
make -j"$PARALLEL"
make install

log_ok "libcurl ($ARCH) → $OUTPUT_DIR"
