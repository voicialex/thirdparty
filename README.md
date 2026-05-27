# Thirdparty

Cross-platform build of third-party libraries for the buddy robot ecosystem.

## Quick Start

```bash
# 1. Build
./build.sh           # Native x86_64
./build.sh -t arm64  # Cross-compile arm64 (requires Docker)

# 2. Build specific targets only
./build.sh opencv libcurl rknn          # x86_64, selected targets
./build.sh -t arm64 opencv libcurl      # arm64, selected targets
```

## Available Targets

| Target       | x86_64 | arm64 | Description                          |
|-------------|--------|-------|--------------------------------------|
| onnxruntime | ✓      | ✓     | ONNX Runtime inference engine        |
| sherpa-onnx | ✓      | ✓     | Sherpa-ONNX ASR/TTS runtime          |
| opencv      | ✓      | ✓     | OpenCV 4.13 (core/imgproc/dnn/video) |
| libcurl     | ✓      | ✓     | libcurl 8.5 (HTTP only, no SSL)      |
| funasr      | ✓      | ✓     | FunASR websocket server              |
| rknn        | ✗      | ✓     | RKNN NPU runtime (ARM64 only)        |

## Prerequisites

- **Native build:** cmake, gcc, make, `libssl-dev` (for Fast-DDS in ros2_core)
- **FunASR:** ONNX Runtime prebuilt (`./build.sh` downloads automatically)
- **arm64 cross-compile:** Docker with BuildKit, `ros2-core/humble:dev` image

## Usage with buddy

```bash
# Extract tarball to buddy's prebuilt directory
mkdir -p ../buddy/prebuilt/aarch64
tar xzf output/aarch64/thirdparty-aarch64.tar.gz -C ../buddy/prebuilt/aarch64/

mkdir -p ../buddy/prebuilt/x86_64
tar xzf output/x86_64/thirdparty-x86_64.tar.gz -C ../buddy/prebuilt/x86_64/
```

## Uploading to GitHub Release

```bash
VERSION="v$(date +%Y.%m.%d)" && gh release create "$VERSION" --repo voicialex/thirdparty --title "thirdparty $VERSION" --notes "Prebuilt third-party libraries for buddy robot (x86_64 + arm64)" output/x86_64/thirdparty-x86_64.tar.gz output/aarch64/thirdparty-aarch64.tar.gz && gh release view "$VERSION" --repo voicialex/thirdparty
```
