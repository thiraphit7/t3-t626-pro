#!/bin/bash
#
# Script: 01-setup-deps.sh
# Purpose: ติดตั้ง dependencies ทั้งหมดสำหรับ OpenWrt build environment
# Target OS: Ubuntu 22.04 / 24.04
#

set -e  # Exit on error

echo "========================================="
echo "OpenWrt Build Dependencies Setup"
echo "สำหรับ EN7529 / T626Pro"
echo "========================================="
echo ""

# ตรวจสอบ OS
if [ -f /etc/lsb-release ]; then
    source /etc/lsb-release
    echo "✅ Detected: $DISTRIB_DESCRIPTION"
elif [ -f /etc/os-release ]; then
    source /etc/os-release
    echo "✅ Detected: $PRETTY_NAME"
else
    echo "✅ Detected: Linux (Dev Container)"
fi
echo ""

# ตรวจสอบสิทธิ์ sudo/root
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        echo "❌ Error: ต้องรันด้วย root หรือมี sudo"
        exit 1
    fi
else
    SUDO=""
fi

# อัปเดต package list
echo "📦 Updating package list..."
$SUDO apt update

echo ""
echo "📦 Installing build dependencies..."
echo "   (อาจใช้เวลาสักครู่...)"
echo ""

# ติดตั้ง dependencies ตาม OpenWrt official requirements
$SUDO apt install -y \
    build-essential \
    clang \
    flex \
    bison \
    g++ \
    gawk \
    gcc-multilib \
    g++-multilib \
    gettext \
    git \
    libncurses-dev \
    libssl-dev \
    rsync \
    unzip \
    zlib1g-dev \
    file \
    wget \
    python3 \
    python3-dev \
    python3-setuptools \
    subversion \
    swig \
    time \
    xsltproc \
    ccache \
    libc6-dev \
    libelf-dev

echo ""
echo "✅ Dependencies installed successfully!"
echo ""

# แสดงข้อมูล compiler versions
echo "========================================="
echo "Installed Tool Versions:"
echo "========================================="
echo "GCC:     $(gcc --version | head -n1)"
echo "Make:    $(make --version | head -n1)"
echo "Python:  $(python3 --version)"
echo "Git:     $(git --version)"
echo ""

# แนะนำขั้นตอนถัดไป
echo "========================================="
echo "✅ Setup Complete!"
echo "========================================="
echo ""
echo "ขั้นตอนถัดไป:"
echo "  1. รันสคริปต์ดึง OpenWrt source:"
echo "     ./scripts/02-clone-openwrt.sh"
echo ""
echo "  2. Configure และ build:"
echo "     ./scripts/03-config-build.sh"
echo ""
