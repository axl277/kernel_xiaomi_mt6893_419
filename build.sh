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

    # Process argument flags
    INCLUDE_KSU=false
    for arg in "$@"; do
        case $arg in
            -ksu) INCLUDE_KSU=true ;;
        esac
    done

    # KernelSU Integration Logic
    if [ "$INCLUDE_KSU" = true ] || [ -n "$KSU_URL" ]; then
        echo "KSU setup URL detected or requested. Integrating KernelSU..."
        if curl -LSs "$KSU_SCRIPT" | bash; then
            echo "KernelSU successfully integrated."
            ZIP_SUFFIX="KSU-"
        else
            echo "Failed to fetch or execute KSU setup script. Proceeding without KSU..."
            ZIP_SUFFIX=""
        fi
    else
        echo "No KSU URL provided and -ksu flag not set. Skipping KernelSU integration..."
        ZIP_SUFFIX=""
    fi

    mkdir -p out

    make LLVM=1 O=out ARCH=arm64 LLVM_IAS=1 CROSS_COMPILE="aarch64-linux-gnu-" chopin_defconfig
    
    make -j$(nproc --all) LLVM=1 O=out ARCH=arm64 LLVM_IAS=1 \
        CROSS_COMPILE="aarch64-linux-gnu-" \
        CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
        HOSTLDFLAGS="-no-pie" \
        Image.gz CONFIG_NO_ERROR_ON_MISMATCH=y 2>&1 | tee error.log
}

function zupload()
{
    if ! [ -d "AnyKernel" ]; then
        git clone --depth=1 https://github.com/axl277/AnyKernel3 AnyKernel
    fi
    cp out/arch/arm64/boot/Image.gz AnyKernel/
    cd AnyKernel
    zip -r9 4.19-CloverseKernel-${ZIP_SUFFIX}${DEVICE}.zip * -x .git .github README.md "*.zip"
    cd ..
}

compile "$@"
zupload
