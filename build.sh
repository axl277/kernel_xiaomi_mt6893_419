#!/bin/bash

DEVICE="agate"
DEFCONFIG="${DEVICE}_defconfig"
KERNEL_DIR=$(pwd)
OUT_DIR="${KERNEL_DIR}/out"
JOBS=$(nproc)
ANYKERNEL_REPO="https://github.com/axl277/AnyKernel3"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

if command -v ccache >/dev/null 2>&1; then
    export USE_CCACHE=1
    export CCACHE_EXEC=$(which ccache)
fi

export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
export CC=aarch64-linux-gnu-gcc

sed -i 's/-Werror//g' Makefile 2>/dev/null || true

rm -rf ${OUT_DIR}
mkdir -p ${OUT_DIR}

make O=${OUT_DIR} ARCH=${ARCH} ${DEFCONFIG}
make O=${OUT_DIR} ARCH=${ARCH} -j${JOBS}

IMAGE_FILE=""
if [ -f "${OUT_DIR}/arch/arm64/boot/Image.gz-dtb" ]; then
    IMAGE_FILE="${OUT_DIR}/arch/arm64/boot/Image.gz-dtb"
elif [ -f "${OUT_DIR}/arch/arm64/boot/Image.gz" ]; then
    IMAGE_FILE="${OUT_DIR}/arch/arm64/boot/Image.gz"
elif [ -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
    IMAGE_FILE="${OUT_DIR}/arch/arm64/boot/Image"
fi

if [ -n "$IMAGE_FILE" ]; then
    git clone --depth=1 ${ANYKERNEL_REPO} AnyKernel3
    cd AnyKernel3
    rm -rf .git .github README.md
    sed -i 's/device.name1=/device.name1=agate/g' anykernel.sh
    sed -i 's|block=.*;|block=auto;|g' anykernel.sh
    sed -i 's|is_slot_device=.*;|is_slot_device=auto;|g' anykernel.sh
    cp "$IMAGE_FILE" .
    ZIP_NAME="${DEVICE}-kernel-${BRANCH}-$(date +%Y%m%d).zip"
    zip -r9 "../${ZIP_NAME}" * -x README.md
    echo "${ZIP_NAME}"
else
    exit 1
fi