
#!/bin/bash

set -Eeuo pipefail

SECONDS=0
DATE=$(date '+%Y%m%d-%H%M')

# ==========================================
# DEVICE CONFIGURATION
# ==========================================

DEVICE="${1:-agate}"
DEFCONFIG="${DEVICE}_defconfig"

OUT_DIR="out"
DIST_DIR="dist"

export ARCH=arm64
export SUBARCH=arm64
export LC_ALL=C
export KBUILD_BUILD_HOST="buildbot"
export KBUILD_BUILD_USER="exerczz1"

# ==========================================
# ARGUMENTS
# ==========================================

CLEAN_BUILD=false

for arg in "$@"; do
    case "$arg" in
        -c)
            CLEAN_BUILD=true
            ;;
        agate|chopin)
            DEVICE="$arg"
            DEFCONFIG="${DEVICE}_defconfig"
            ;;
        *)
            echo "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "Device: $DEVICE"
echo "Defconfig: $DEFCONFIG"
echo "Compiler: LLVM 18"
echo "=========================================="

# ==========================================
# CHECK COMPILER
# ==========================================

for cmd in clang-18 ld.lld-18 llvm-ar-18 \
           aarch64-linux-gnu-gcc \
           arm-linux-gnueabi-gcc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: $cmd not found!"
        exit 1
    fi
done

# ==========================================
# CHECK DEFCONFIG
# ==========================================

if [[ ! -f "arch/arm64/configs/${DEFCONFIG}" ]]; then
    echo "ERROR: ${DEFCONFIG} not found!"
    find arch/arm64/configs -maxdepth 1 \
        \( -iname '*agate*' -o -iname '*chopin*' \)
    exit 1
fi

# ==========================================
# CLEAN BUILD
# ==========================================

if [[ "$CLEAN_BUILD" == true ]]; then
    echo "Cleaning previous build..."
    rm -rf "$OUT_DIR" "$DIST_DIR"
fi

mkdir -p "$OUT_DIR" "$DIST_DIR"

# ==========================================
# GENERATE DEFCONFIG
# ==========================================

echo "Generating ${DEFCONFIG}..."

make LLVM=-18 \
    O="$OUT_DIR" \
    ARCH=arm64 \
    LLVM_IAS=1 \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    "$DEFCONFIG"

# ==========================================
# COMPILE
# ==========================================

echo "Starting compilation..."

set +e

make -j"$(nproc --all)" \
    LLVM=-18 \
    O="$OUT_DIR" \
    ARCH=arm64 \
    LLVM_IAS=1 \
    CROSS_COMPILE="aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
    HOSTLDFLAGS="-no-pie" \
    Image.gz \
    CONFIG_NO_ERROR_ON_MISMATCH=y \
    2>&1 | tee error.log

BUILD_STATUS=${PIPESTATUS[0]}

set -e

if [[ "$BUILD_STATUS" -ne 0 ]]; then
    echo "=========================================="
    echo "KERNEL BUILD FAILED"
    echo "=========================================="
    exit "$BUILD_STATUS"
fi

# ==========================================
# VERIFY IMAGE
# ==========================================

IMAGE="out/arch/arm64/boot/Image.gz"

if [[ ! -s "$IMAGE" ]]; then
    echo "ERROR: Image.gz not found!"
    exit 1
fi

cp "$IMAGE" "$DIST_DIR/Image.gz"

sha256sum "$DIST_DIR/Image.gz" \
    > "$DIST_DIR/Image.gz.sha256"

# ==========================================
# FINISH
# ==========================================

echo "=========================================="
echo "KERNEL BUILD SUCCESSFUL"
echo "Device: $DEVICE"
echo "Output: $DIST_DIR/Image.gz"
echo "=========================================="

echo "Build time: $((SECONDS / 60))m $((SECONDS % 60))s"
