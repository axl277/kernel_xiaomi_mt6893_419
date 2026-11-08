#!/bin/bash

function compile() 
{
    source ~/.bashrc && source ~/.profile 2>/dev/null || true
    export LC_ALL=C && export USE_CCACHE=1
    ccache -M 100G
    export ARCH=arm64
    export KBUILD_BUILD_HOST=buildbot
    export KBUILD_BUILD_USER="exerczz1"
    export DEVICE="Agate"

    # Periksa dan clone KernelSU jika folder/link kosong atau belum ada Kconfig
    if [ ! -f "drivers/kernelsu/Kconfig" ]; then
        echo "KernelSU belum terunduh, mengunduh KernelSU..."
        rm -rf drivers/kernelsu
        curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main
    fi

    mkdir -p out

    make LLVM=-18 O=out ARCH=arm64 LLVM_IAS=1 CROSS_COMPILE="aarch64-linux-gnu-" agate_defconfig
    make -j$(nproc --all) LLVM=-18 O=out ARCH=arm64 LLVM_IAS=1 \
        CROSS_COMPILE="aarch64-linux-gnu-" \
        CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
        HOSTLDFLAGS="-no-pie" \
        Image.gz CONFIG_NO_ERROR_ON_MISMATCH=y 2>&1 | tee error.log
}

function zupload()
{
    if [ ! -f "out/arch/arm64/boot/Image.gz" ]; then
        echo "Error: Image.gz tidak ditemukan, kompilasi gagal."
        exit 1
    fi

    if ! [ -d "AnyKernel" ]; then
        git clone --depth=1 https://github.com/exrcz1337/AnyKernel3 AnyKernel
    fi
    cp out/arch/arm64/boot/Image.gz AnyKernel/
    cd AnyKernel
    zip -r9 4.19.325-RemiKernel-$DEVICE.zip * -x .git .github README.md "*.zip"
    cd ..
}

compile
zupload
