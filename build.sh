#!/bin/bash

function compile() 
{
    export LC_ALL=C
    export USE_CCACHE=1
    ccache -M 100G
    export ARCH=arm64
    export KBUILD_BUILD_HOST=buildbot
    export KBUILD_BUILD_USER=""
    export DEVICE="chopin"

    mkdir -p out

    make LLVM=1 O=out ARCH=arm64 LLVM_IAS=1 CROSS_COMPILE="aarch64-linux-gnu-" chopin_defconfig || exit 1
    
    make -j$(nproc --all) LLVM=1 O=out ARCH=arm64 LLVM_IAS=1 \
        CROSS_COMPILE="aarch64-linux-gnu-" \
        CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
        HOSTLDFLAGS="-no-pie" \
        Image.gz dtbo.img 2>&1 | tee error.log
}

function zupload()
{
    if [ ! -f "out/arch/arm64/boot/Image.gz" ]; then
        exit 1
    fi

    if ! [ -d "AnyKernel" ]; then
        git clone --depth=1 https://github.com/axl277/AnyKernel3 AnyKernel
    fi
    
    cp out/arch/arm64/boot/Image.gz AnyKernel/
    [ -f "out/arch/arm64/boot/dtbo.img" ] && cp out/arch/arm64/boot/dtbo.img AnyKernel/
    
    cd AnyKernel
    zip -r9 4.19-CloverseKernel-${DEVICE}.zip * -x .git .github README.md "*.zip"
    cd ..
}

compile "$@"
zupload
