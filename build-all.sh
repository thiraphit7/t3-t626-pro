#!/bin/bash
#
# Script: build-all.sh
# Purpose: Build OpenWrt kernel ทั้งหมดในคำสั่งเดียว
# สำหรับ EN7529 / T626Pro
#

set -e  # Exit on error

# ตรวจสอบว่าไม่ใช่ root user
if [ "$(id -u)" -eq 0 ]; then
    echo "❌ Error: OpenWrt ห้าม build ด้วย root user!"
    echo ""
    echo "กรุณาสร้าง user ใหม่หรือใช้ user ธรรมดา:"
    echo "  useradd -m -s /bin/bash builder"
    echo "  su - builder"
    echo "  cd /workspaces/t3-t626-pro"
    echo "  ./build-all.sh"
    echo ""
    echo "หรือถ้าต้องการบังคับ (ไม่แนะนำ):"
    echo "  export FORCE_UNSAFE_CONFIGURE=1"
    echo "  ./build-all.sh"
    exit 1
fi

WORK_DIR="$HOME/openwrt-en7529"
OPENWRT_DIR="$WORK_DIR/openwrt"

echo "========================================="
echo "OpenWrt Full Build Pipeline"
echo "สำหรับ EN7529 / T626Pro"
echo "========================================="
echo ""

# ========================================
# Step 1: Install Dependencies
# ========================================
echo "📦 Step 1/4: Installing dependencies..."
echo ""

# ใช้ sudo สำหรับ apt (แม้จะไม่ใช่ root)
if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    echo "⚠️  Warning: sudo not found, trying direct apt..."
    SUDO=""
fi

$SUDO apt update -qq 2>/dev/null || echo "⚠️  apt update skipped"
$SUDO apt install -y \
    build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
    gettext git libncurses-dev libssl-dev rsync unzip zlib1g-dev file \
    wget python3 python3-dev python3-setuptools subversion swig time \
    xsltproc ccache libc6-dev libelf-dev 2>/dev/null || echo "⚠️  Some packages may already be installed"

echo ""
echo "✅ Dependencies installed!"
echo ""

# ========================================
# Step 2: Clone OpenWrt
# ========================================
echo "📥 Step 2/4: Cloning OpenWrt source..."
echo ""

if [ -d "$OPENWRT_DIR" ]; then
    echo "⚠️  OpenWrt directory exists. Skipping clone."
    echo "   Using: $OPENWRT_DIR"
else
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    echo "   Cloning from: https://git.openwrt.org/openwrt/openwrt.git"
    git clone https://git.openwrt.org/openwrt/openwrt.git
    
    echo ""
    echo "✅ Clone complete!"
fi

cd "$OPENWRT_DIR"
echo ""

# ========================================
# Step 3: Update Feeds
# ========================================
echo "📦 Step 3/4: Updating and installing feeds..."
echo ""

./scripts/feeds update -a
./scripts/feeds install -a

echo ""
echo "✅ Feeds ready!"
echo ""

# ========================================
# Step 4: Configure and Build
# ========================================
echo "🔧 Step 4/4: Configuring and building..."
echo ""

# ใช้ config ที่มีอยู่ หรือสร้างใหม่
if [ -f "/workspaces/t3-t626-pro/config/.config.en7523" ]; then
    echo "📋 Using existing config..."
    cp /workspaces/t3-t626-pro/config/.config.en7523 .config
    make defconfig
else
    echo "📋 Creating minimal config for EN7523..."
    
    # สร้าง minimal config
    cat > .config << 'EOF'
CONFIG_TARGET_airoha=y
CONFIG_TARGET_airoha_en7523=y
CONFIG_TARGET_airoha_en7523_DEVICE_airoha_en7523-evb=y
CONFIG_TARGET_ROOTFS_INITRAMFS=y
CONFIG_TARGET_INITRAMFS_COMPRESSION_GZIP=y
CONFIG_DEVEL=y
CONFIG_CCACHE=y
EOF
    
    make defconfig
    
    # บันทึก config
    mkdir -p /workspaces/t3-t626-pro/config
    cp .config /workspaces/t3-t626-pro/config/.config.en7523
fi

echo ""
echo "🔨 Building kernel (this will take 1-3 hours)..."
echo "   Using $(nproc) CPU cores"
echo "   Started at: $(date)"
echo ""

# Build
make -j$(nproc) V=s

BUILD_RESULT=$?
echo ""

if [ $BUILD_RESULT -eq 0 ]; then
    echo "========================================="
    echo "✅ BUILD SUCCESSFUL!"
    echo "========================================="
    echo ""
    echo "Completed at: $(date)"
    echo ""
    
    # หา output files
    echo "📦 Output files:"
    echo ""
    find bin/targets/airoha/ -name "*.bin" -exec ls -lh {} \;
    echo ""
    
    KERNEL_FILE=$(find bin/targets/airoha/ -name "*-initramfs-kernel.bin" | head -n1)
    if [ -n "$KERNEL_FILE" ]; then
        echo "========================================="
        echo "Kernel Image Ready:"
        echo "========================================="
        echo "File: $KERNEL_FILE"
        echo "Size: $(du -h "$KERNEL_FILE" | cut -f1)"
        echo ""
        echo "Next steps:"
        echo "  1. Copy to TFTP server:"
        echo "     scp $KERNEL_FILE user@tftp-server:/private/tftpboot/"
        echo ""
        echo "  2. Boot at U-Boot:"
        echo "     tftpboot 0x81800000 $(basename "$KERNEL_FILE")"
        echo "     bootm 0x81800000"
        echo ""
    fi
else
    echo "========================================="
    echo "❌ BUILD FAILED"
    echo "========================================="
    echo ""
    echo "Please check error messages above."
    exit 1
fi
