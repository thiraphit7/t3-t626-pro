#!/bin/bash
#
# Script: 03-config-build.sh
# Purpose: Configure OpenWrt และ build initramfs kernel สำหรับ EN7523/EN7529
# Output: bin/targets/airoha/en7523/*-initramfs-kernel.bin
#

set -e  # Exit on error

echo "========================================="
echo "OpenWrt Configure & Build"
echo "สำหรับ EN7529 / T626Pro"
echo "========================================="
echo ""

# กำหนด paths
WORK_DIR="$HOME/openwrt-en7529"
OPENWRT_DIR="$WORK_DIR/openwrt"
CONFIG_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")/config"

# ตรวจสอบว่า OpenWrt directory มีอยู่หรือไม่
if [ ! -d "$OPENWRT_DIR" ]; then
    echo "❌ Error: OpenWrt directory not found: $OPENWRT_DIR"
    echo ""
    echo "กรุณารันสคริปต์นี้ก่อน:"
    echo "  ./scripts/02-clone-openwrt.sh"
    exit 1
fi

cd "$OPENWRT_DIR"
echo "📁 Working in: $OPENWRT_DIR"
echo ""

# ถามว่าจะใช้ .config ที่มีอยู่แล้ว หรือ menuconfig ใหม่
if [ -f "$CONFIG_DIR/.config.en7523" ]; then
    echo "📋 Found existing config: $CONFIG_DIR/.config.en7523"
    read -p "Use this config? (Y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "📋 Copying config..."
        cp "$CONFIG_DIR/.config.en7523" .config
        make defconfig
        echo "✅ Config applied!"
        echo ""
    else
        echo "ℹ️  Opening menuconfig..."
        echo ""
        make menuconfig
    fi
else
    echo "ℹ️  No saved config found. Opening menuconfig..."
    echo ""
    echo "========================================="
    echo "menuconfig Instructions:"
    echo "========================================="
    echo "1. Target System → Airoha ARM"
    echo "2. Subtarget → EN7523"
    echo "3. Target Profile → Generic EN7523 EVB"
    echo "4. Target Images → เปิด 'ramdisk' (initramfs)"
    echo "5. Save and Exit"
    echo ""
    read -p "Press Enter to open menuconfig..." 
    echo ""
    
    make menuconfig
    
    # บันทึก config
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
    fi
    cp .config "$CONFIG_DIR/.config.en7523"
    echo ""
    echo "✅ Config saved to: $CONFIG_DIR/.config.en7523"
fi

echo ""
echo "========================================="
echo "Starting Build"
echo "========================================="
echo ""
echo "⚠️  การ build ครั้งแรกจะใช้เวลานาน (1-3 ชั่วโมง)"
echo "   - Build toolchain (gcc, binutils, etc.)"
echo "   - Build kernel"
echo "   - Build packages"
echo ""
read -p "Continue with build? (Y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "ℹ️  Build cancelled. You can build manually with:"
    echo "     cd $OPENWRT_DIR"
    echo "     make -j\$(nproc) V=s"
    exit 0
fi

echo ""
echo "🔨 Building with $(nproc) parallel jobs..."
echo "   (ใช้ V=s เพื่อแสดง verbose output)"
echo ""

# เริ่ม build
make -j$(nproc) V=s

BUILD_RESULT=$?

echo ""
if [ $BUILD_RESULT -eq 0 ]; then
    echo "========================================="
    echo "✅ Build Successful!"
    echo "========================================="
    echo ""
    
    # หา output files
    echo "📦 Output files:"
    echo ""
    find bin/targets/airoha/ -name "*-initramfs-kernel.bin" -exec ls -lh {} \;
    echo ""
    
    # แสดงข้อมูลสรุป
    KERNEL_FILE=$(find bin/targets/airoha/ -name "*-initramfs-kernel.bin" | head -n1)
    if [ -n "$KERNEL_FILE" ]; then
        echo "========================================="
        echo "Kernel Image Details:"
        echo "========================================="
        echo "File: $KERNEL_FILE"
        echo "Size: $(du -h "$KERNEL_FILE" | cut -f1)"
        echo ""
        echo "ขั้นตอนถัดไป:"
        echo "  1. Copy ไฟล์นี้ไปยัง TFTP server (macOS):"
        echo "     scp $KERNEL_FILE user@mac-ip:/private/tftpboot/"
        echo ""
        echo "  2. หรือใช้สคริปต์:"
        echo "     ./scripts/04-tftp-deploy.sh"
        echo ""
        echo "  3. Boot ที่ U-Boot:"
        echo "     tftpboot 0x81800000 $(basename "$KERNEL_FILE")"
        echo "     bootm 0x81800000"
        echo ""
    fi
else
    echo "========================================="
    echo "❌ Build Failed!"
    echo "========================================="
    echo ""
    echo "กรุณาตรวจสอบ error messages ด้านบน"
    echo ""
    echo "Tips:"
    echo "  - ลอง clean และ build ใหม่: make clean && make -j\$(nproc) V=s"
    echo "  - ตรวจสอบ disk space: df -h"
    echo "  - ดู build log: tail -100 build.log"
    exit 1
fi
