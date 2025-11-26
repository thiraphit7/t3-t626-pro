#!/bin/bash
#
# Script: 04-tftp-deploy.sh
# Purpose: Deploy kernel image ไปยัง TFTP server (macOS)
# Requires: SSH access to macOS TFTP server
#

set -e  # Exit on error

echo "========================================="
echo "TFTP Deploy Script"
echo "สำหรับ EN7529 / T626Pro"
echo "========================================="
echo ""

# กำหนด paths
WORK_DIR="$HOME/openwrt-en7529"
OPENWRT_DIR="$WORK_DIR/openwrt"

# ตรวจสอบว่า kernel file มีอยู่หรือไม่
if [ ! -d "$OPENWRT_DIR" ]; then
    echo "❌ Error: OpenWrt directory not found: $OPENWRT_DIR"
    exit 1
fi

cd "$OPENWRT_DIR"

KERNEL_FILE=$(find bin/targets/airoha/ -name "*-initramfs-kernel.bin" | head -n1)

if [ -z "$KERNEL_FILE" ]; then
    echo "❌ Error: No kernel image found!"
    echo ""
    echo "กรุณา build kernel ก่อน:"
    echo "  ./scripts/03-config-build.sh"
    exit 1
fi

echo "📦 Found kernel image:"
echo "   File: $KERNEL_FILE"
echo "   Size: $(du -h "$KERNEL_FILE" | cut -f1)"
echo ""

# ถาม TFTP server details
echo "========================================="
echo "TFTP Server Configuration"
echo "========================================="
echo ""

read -p "TFTP Server IP/Hostname (e.g., 192.168.1.10): " TFTP_HOST
read -p "SSH Username (e.g., user): " TFTP_USER
read -p "TFTP Root Path (default: /private/tftpboot): " TFTP_PATH
TFTP_PATH=${TFTP_PATH:-/private/tftpboot}

# ถามชื่อไฟล์ที่จะใช้
ORIGINAL_NAME=$(basename "$KERNEL_FILE")
echo ""
echo "Original filename: $ORIGINAL_NAME"
read -p "Rename to (Enter to keep original): " NEW_NAME
NEW_NAME=${NEW_NAME:-$ORIGINAL_NAME}

echo ""
echo "========================================="
echo "Deploy Summary"
echo "========================================="
echo "Source:      $KERNEL_FILE"
echo "Destination: $TFTP_USER@$TFTP_HOST:$TFTP_PATH/$NEW_NAME"
echo ""
read -p "Continue? (Y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "ℹ️  Deploy cancelled."
    exit 0
fi

echo ""
echo "📤 Copying file via SCP..."
echo ""

scp "$KERNEL_FILE" "$TFTP_USER@$TFTP_HOST:$TFTP_PATH/$NEW_NAME"

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "✅ Deploy Successful!"
    echo "========================================="
    echo ""
    echo "ไฟล์พร้อมใช้งานที่ TFTP server แล้ว!"
    echo ""
    echo "========================================="
    echo "U-Boot Commands:"
    echo "========================================="
    echo ""
    echo "# ตั้งค่า network (ครั้งเดียว)"
    echo "setenv ipaddr 192.168.1.20"
    echo "setenv serverip $TFTP_HOST"
    echo "saveenv"
    echo ""
    echo "# Test connection"
    echo "ping $TFTP_HOST"
    echo ""
    echo "# Load and boot kernel"
    echo "tftpboot 0x81800000 $NEW_NAME"
    echo "bootm 0x81800000"
    echo ""
else
    echo ""
    echo "❌ Deploy failed!"
    echo ""
    echo "Troubleshooting:"
    echo "  - ตรวจสอบ SSH connection: ssh $TFTP_USER@$TFTP_HOST"
    echo "  - ตรวจสอบ TFTP service บน macOS: sudo launchctl list | grep tftp"
    echo "  - ตรวจสอบ permissions: ls -la $TFTP_PATH"
    exit 1
fi
