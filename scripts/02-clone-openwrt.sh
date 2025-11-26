#!/bin/bash
#
# Script: 02-clone-openwrt.sh
# Purpose: Clone OpenWrt source และเตรียม feeds
# Output: ~/openwrt-en7529/openwrt/
#

set -e  # Exit on error

echo "========================================="
echo "OpenWrt Source Clone & Setup"
echo "สำหรับ EN7529 / T626Pro"
echo "========================================="
echo ""

# กำหนด working directory
WORK_DIR="$HOME/openwrt-en7529"
OPENWRT_DIR="$WORK_DIR/openwrt"

# สร้าง working directory
if [ ! -d "$WORK_DIR" ]; then
    echo "📁 Creating working directory: $WORK_DIR"
    mkdir -p "$WORK_DIR"
else
    echo "📁 Working directory exists: $WORK_DIR"
fi

cd "$WORK_DIR"
echo ""

# Clone OpenWrt repository
if [ -d "$OPENWRT_DIR" ]; then
    echo "⚠️  OpenWrt directory already exists: $OPENWRT_DIR"
    read -p "Do you want to remove and re-clone? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Removing old directory..."
        rm -rf "$OPENWRT_DIR"
    else
        echo "ℹ️  Skipping clone, using existing directory"
        cd "$OPENWRT_DIR"
        echo "📍 Current branch: $(git branch --show-current)"
        echo ""
        echo "Pulling latest changes..."
        git pull
        echo ""
        echo "Skipping to feeds update..."
        ./scripts/feeds update -a
        ./scripts/feeds install -a
        echo ""
        echo "✅ Feeds updated successfully!"
        exit 0
    fi
fi

echo "📥 Cloning OpenWrt repository (main branch)..."
echo "   Repository: https://git.openwrt.org/openwrt/openwrt.git"
echo "   (อาจใช้เวลาสักครู่...)"
echo ""

git clone https://git.openwrt.org/openwrt/openwrt.git
cd openwrt

echo ""
echo "✅ Clone complete!"
echo "📍 Current branch: $(git branch --show-current)"
echo "📍 Latest commit: $(git log -1 --oneline)"
echo ""

# Update และติดตั้ง feeds
echo "========================================="
echo "Updating Feeds"
echo "========================================="
echo ""

echo "📦 Updating feeds list..."
./scripts/feeds update -a

echo ""
echo "📦 Installing feeds packages..."
./scripts/feeds install -a

echo ""
echo "✅ Feeds setup complete!"
echo ""

# แสดง target ที่มี
echo "========================================="
echo "Available Airoha Targets:"
echo "========================================="
echo ""
if [ -d "target/linux/airoha" ]; then
    echo "✅ target/linux/airoha/ found!"
    ls -la target/linux/airoha/
else
    echo "⚠️  Warning: target/linux/airoha/ not found"
    echo "   (อาจต้องใช้ target อื่น หรือ apply patches)"
fi
echo ""

# สรุปผล
echo "========================================="
echo "✅ Setup Complete!"
echo "========================================="
echo ""
echo "OpenWrt source พร้อมใช้งานที่:"
echo "  $OPENWRT_DIR"
echo ""
echo "ขั้นตอนถัดไป:"
echo "  1. เข้าไปที่ OpenWrt directory:"
echo "     cd $OPENWRT_DIR"
echo ""
echo "  2. รัน menuconfig:"
echo "     make menuconfig"
echo ""
echo "  3. หรือใช้สคริปต์อัตโนมัติ:"
echo "     $HOME/t3-t626-pro/scripts/03-config-build.sh"
echo ""
