#!/bin/bash
#
# Quick build launcher - รัน build แบบ interactive
#

cd /workspaces/t3-t626-pro

echo "🚀 Starting OpenWrt build for EN7529/T626Pro..."
echo ""

# Check if running in container/root
if [ "$(id -u)" -eq 0 ]; then
    echo "✅ Running as root"
    ./build-all.sh
else
    echo "✅ Running with sudo"
    sudo ./build-all.sh
fi
