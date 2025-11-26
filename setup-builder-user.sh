#!/bin/bash
#
# Setup non-root user for OpenWrt build
#

set -e

echo "========================================="
echo "Creating Build User for OpenWrt"
echo "========================================="
echo ""

# สร้าง user 'builder' ถ้ายังไม่มี
if ! id -u builder >/dev/null 2>&1; then
    echo "📝 Creating user 'builder'..."
    useradd -m -s /bin/bash builder
    echo "✅ User created!"
else
    echo "✅ User 'builder' already exists"
fi

# เพิ่ม sudo privileges
if ! grep -q "^builder" /etc/sudoers.d/builder 2>/dev/null; then
    echo "🔑 Adding sudo privileges..."
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
    chmod 0440 /etc/sudoers.d/builder
    echo "✅ Sudo privileges granted!"
fi

# Copy project files
echo "📁 Setting up workspace..."
mkdir -p /home/builder/t3-t626-pro
cp -r /workspaces/t3-t626-pro/* /home/builder/t3-t626-pro/ 2>/dev/null || true
chown -R builder:builder /home/builder/t3-t626-pro

echo ""
echo "========================================="
echo "✅ Setup Complete!"
echo "========================================="
echo ""
echo "ตอนนี้ switch ไปใช้ user 'builder' และรัน build:"
echo ""
echo "  su - builder"
echo "  cd ~/t3-t626-pro"
echo "  ./build-all.sh"
echo ""
