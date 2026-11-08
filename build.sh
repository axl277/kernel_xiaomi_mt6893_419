
#!/usr/bin/env bash

set -Eeuo pipefail

# ==========================================
# MT6893 Kernel 4.19 Build Script
# Target: agate
# Toolchain: Proton Clang 15
# ==========================================

SECONDS=0

DEVICE="${1:-agate}"
DEFCONFIG="${DEVICE}_defconfig"

KERNEL_DIR="$(pwd)"
OUT_DIR="${KERNEL_DIR}/out"
DIST_DIR="${KERNEL_DIR}/dist"

TC_DIR="${HOME}/toolchains/proton-clang"

ARCH=arm64
IMAGE=Image.gz

export ARCH
export SUBARCH=arm64
export KBUILD_BUILD_USER="GitHub"
export KBUILD_BUILD_HOST="Actions"

# ==========================================
# Parse arguments
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
            echo "Usage: ./build.sh [agate|chopin] [-c]"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "Device       : ${DEVICE}"
echo "Architecture : ${ARCH}"
echo "Defconfig    : ${DEFCONFIG}"
echo "Toolchain    : Proton Clang 15"
echo "=========================================="

# ==========================================
# Check dependencies
# ==========================================

for cmd in git make zip python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Missing dependency: $cmd"
        exit 1
    fi
done

# ==========================================
# Check defconfig
# ==========================================

CONFIG_PATH="arch/arm64/configs/${DEFCONFIG}"

if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "ERROR: Defconfig not found: ${CONFIG_PATH}"
    echo ""
    echo "Available agate/chopin configs:"
    find arch/arm64/configs -maxdepth 1 \
        \( -iname '*agate*' -o -iname '*chopin*' \) \
        -print
    exit 1
fi

# ==========================================
# Setup Proton Clang
# ==========================================

if [[ ! -x "${TC_DIR}/bin/clang" ]]; then
    echo "Downloading Proton Clang 15..."

    mkdir -p "${HOME}/toolchains"

    if [[ -d "$TC_DIR" ]]; then
        rm -rf "$TC_DIR"
    fi

    git clone --depth=1 \
        -b clang-15 \
        https://gitlab.com/LeCmnGend/proton-clang.git \
        "$TC_DIR"
fi

export PATH="${TC_DIR}/bin:${PATH}"

if ! command -v clang >/dev/null 2>&1; then
    echo "ERROR: Clang not found!"
    exit 1
fi

echo "Compiler version:"
clang --version | head -n 1

# ==========================================
# Check GCC cross compiler
# ==========================================

for cmd in aarch64-linux-gnu-gcc arm-linux-gnueabi-gcc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Missing cross compiler: $cmd"
        exit 1
    fi
done

# ==========================================
# Clean build
# ==========================================

if [[ "$CLEAN_BUILD" == true ]]; then
    echo "Cleaning previous build..."
    rm -rf "$OUT_DIR" "$DIST_DIR"
fi

mkdir -p "$OUT_DIR" "$DIST_DIR"

# ==========================================
# Generate defconfig
# ==========================================

echo "Generating ${DEFCONFIG}..."

make -C "$KERNEL_DIR" \
    O="$OUT_DIR" \
    ARCH="$ARCH" \
    "$DEFCONFIG"

# ==========================================
# Compile kernel
# ==========================================

echo "Starting kernel compilation..."

make -C "$KERNEL_DIR" \
    -j"$(nproc --all)" \
    O="$OUT_DIR" \
    ARCH="$ARCH" \
    CC=clang \
    LLVM=1 \
    LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    Image.gz

# ==========================================
# Verify output
# ==========================================

KERNEL_IMAGE="${OUT_DIR}/arch/arm64/boot/${IMAGE}"

if [[ ! -s "$KERNEL_IMAGE" ]]; then
    echo "ERROR: Kernel image not found!"
    find "${OUT_DIR}/arch/arm64/boot" -maxdepth 2 -type f
    exit 1
fi

# ==========================================
# Copy output
# ==========================================

cp "$KERNEL_IMAGE" "${DIST_DIR}/Image.gz"

sha256sum "${DIST_DIR}/Image.gz" \
    > "${DIST_DIR}/Image.gz.sha256"

echo ""
echo "=========================================="
echo "BUILD SUCCESSFUL"
echo "=========================================="
echo "Device: ${DEVICE}"
echo "Kernel: ${DIST_DIR}/Image.gz"
echo "SHA256:"
cat "${DIST_DIR}/Image.gz.sha256"
echo ""
echo "Build time: $((SECONDS / 60))m $((SECONDS % 60))s"
echo "=========================================="
