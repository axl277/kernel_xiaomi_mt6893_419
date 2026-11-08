
#!/usr/bin/env bash
set -euo pipefail

# ==============================
# Kernel build configuration
# ==============================

DEVICE="${DEVICE:-agate}"
ARCH="${ARCH:-arm64}"
DEFCONFIG="${DEFCONFIG:-agate_defconfig}"
OUT_DIR="${OUT_DIR:-out}"

# Toolchain GCC
CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32:-arm-linux-gnueabi-}"

# Kernel image output
IMAGE_NAME="${IMAGE_NAME:-Image.gz-dtb}"

# ==============================
# Build kernel
# ==============================

echo "================================"
echo "Building kernel for ${DEVICE}"
echo "Kernel architecture: ${ARCH}"
echo "Defconfig: ${DEFCONFIG}"
echo "================================"

if [[ ! -f "arch/arm64/configs/${DEFCONFIG}" ]]; then
    echo "ERROR: Defconfig tidak ditemukan:"
    echo "arch/arm64/configs/${DEFCONFIG}"
    echo ""
    echo "Defconfig yang tersedia:"
    find arch/arm64/configs -maxdepth 1 -name '*agate*'
    exit 1
fi

mkdir -p "${OUT_DIR}"

# Generate defconfig
make O="${OUT_DIR}" \
    ARCH="${ARCH}" \
    "${DEFCONFIG}"

# Compile kernel
make -j"$(nproc)" O="${OUT_DIR}" \
    ARCH="${ARCH}" \
    CROSS_COMPILE="${CROSS_COMPILE}" \
    CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32}" \
    "${IMAGE_NAME}"

# Check output
if [[ ! -f "${OUT_DIR}/arch/arm64/boot/${IMAGE_NAME}" ]]; then
    echo "ERROR: Kernel image tidak ditemukan!"
    find "${OUT_DIR}/arch/arm64/boot" -maxdepth 2 -type f
    exit 1
fi

echo ""
echo "================================"
echo "BUILD SUCCESSFUL"
echo "================================"

mkdir -p dist

cp "${OUT_DIR}/arch/arm64/boot/${IMAGE_NAME}" \
   "dist/${IMAGE_NAME}"

echo "Kernel image:"
echo "dist/${IMAGE_NAME}"
