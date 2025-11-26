# Quick Start Guide - OpenWrt สำหรับ EN7529/T626Pro

เริ่มต้นใช้งาน OpenWrt บน T3 T626Pro ใน 5 ขั้นตอน

---

## ขั้นตอนที่ 1: เตรียมเครื่อง Build

**ต้องการ:**
- Ubuntu 22.04/24.04 (VM หรือ bare metal)
- 30 GB disk space ว่าง
- 4 GB RAM ขึ้นไป
- Internet connection

**ติดตั้ง:**
```bash
cd /workspaces/t3-t626-pro
./scripts/01-setup-deps.sh
```

**เวลา:** ~5-10 นาที

---

## ขั้นตอนที่ 2: Clone OpenWrt Source

```bash
./scripts/02-clone-openwrt.sh
```

**เวลา:** ~10-30 นาที (ขึ้นกับความเร็ว internet)

---

## ขั้นตอนที่ 3: Configure และ Build

### Auto Config:
```bash
./scripts/03-config-build.sh
```

### Manual Config:
```bash
cd ~/openwrt-en7529/openwrt
make menuconfig
```

**ตั้งค่า:**
1. Target System → **Airoha ARM**
2. Subtarget → **EN7523**
3. Target Profile → **Generic EN7523 EVB**
4. Target Images → เปิด **ramdisk** (initramfs)

**Build:**
```bash
make -j$(nproc) V=s
```

**เวลา:** ~1-3 ชั่วโมง (build ครั้งแรก)

---

## ขั้นตอนที่ 4: ตั้งค่า TFTP Server (macOS)

```bash
# เปิด TFTP service
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist

# Copy kernel image
scp ~/openwrt-en7529/openwrt/bin/targets/airoha/en7523/*-initramfs-kernel.bin \
    user@mac-ip:/private/tftpboot/openwrt-t626pro.bin
```

หรือใช้สคริปต์:
```bash
./scripts/04-tftp-deploy.sh
```

---

## ขั้นตอนที่ 5: Boot ผ่าน TFTP

### เชื่อมต่อ Serial Console

```bash
# macOS/Linux
screen /dev/tty.usbserial-* 115200
```

### Boot Kernel

```
ECNT> setenv ipaddr 192.168.1.20
ECNT> setenv serverip 192.168.1.10
ECNT> saveenv

ECNT> ping 192.168.1.10
ECNT> tftpboot 0x81800000 openwrt-t626pro.bin
ECNT> bootm 0x81800000
```

**เวลา:** ~30 วินาที

---

## ผลลัพธ์

ถ้าสำเร็จจะเห็น:

```
Starting kernel ...

[    0.000000] Booting Linux on physical CPU 0x0
[    0.000000] Linux version 6.x.x ...
[    0.000000] Machine model: Airoha EN7523 EVB
[    0.000000] Memory: 512MB ...
...
[   xx.xxx] Welcome to OpenWrt!
```

---

## ขั้นตอนถัดไป

✅ Kernel boot สำเร็จแล้ว!

**ต่อไป:**
1. ตรวจสอบ hardware detection (RAM, NAND, Ethernet)
2. เก็บข้อมูลฮาร์ดแวร์จริง → [`docs/HARDWARE.md`](docs/HARDWARE.md)
3. ปรับแต่ง Device Tree → [`dts/README.md`](dts/README.md)
4. Build production kernel + rootfs
5. Flash ลง NAND → [`docs/FLASH_GUIDE.md`](docs/FLASH_GUIDE.md)

---

## Troubleshooting

ถ้ามีปัญหา ดูที่: [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)

**ปัญหาทั่วไพบ:**
- TFTP timeout → ตรวจสอบ network/firewall
- Bad magic number → ไฟล์ไม่ใช่ uImage
- Kernel panic → DTS หรือ config ไม่ถูกต้อง

---

## คำสั่งที่ใช้บ่อย

```bash
# Rebuild kernel (หลังแก้ DTS)
cd ~/openwrt-en7529/openwrt
make target/linux/compile V=s

# Deploy ไป TFTP
./scripts/04-tftp-deploy.sh

# U-Boot: Quick boot
tftpboot 0x81800000 openwrt-t626pro.bin && bootm 0x81800000
```

---

**มีปัญหา?** อ่าน [BUILD_GUIDE.md](docs/BUILD_GUIDE.md) หรือ [TFTP_BOOT.md](docs/TFTP_BOOT.md)

**Last Updated**: November 26, 2025
