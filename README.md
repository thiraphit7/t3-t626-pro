# OpenWrt Build Pipeline สำหรับ EN7529 / T3 T626Pro

Project นี้รวบรวมทุกอย่างที่จำเป็นสำหรับการ build OpenWrt kernel สำหรับ Airoha EN7529 (T3 T626Pro board)

## Hardware Specifications

- **SoC**: Airoha EN7529 (EN7523/EN7529 family)
- **Board**: T3 T626Pro
- **RAM**: 512 MB
- **Flash**: NAND (ต้องระบุรายละเอียดเพิ่มเติม)
- **Architecture**: ARM (Cortex-A53 Dual-Core @ 1.3 GHz)

## เป้าหมายของ Project

1. ✅ Setup OpenWrt build environment บน Ubuntu 22.04/24.04
2. ✅ Build initramfs kernel สำหรับ EN7523/EN7529 target
3. ⏳ Boot kernel ผ่าน TFTP + U-Boot (RAM-only, ไม่ยุ่ง flash)
4. ⏳ ปรับแต่ง Device Tree (DTS) สำหรับฮาร์ดแวร์ T626Pro
5. ⏳ Build production kernel + rootfs
6. ⏳ Flash kernel + rootfs ลง NAND อย่างถาวร

## โครงสร้าง Directory

```
t3-t626-pro/
├── README.md                 # เอกสารหลัก (ไฟล์นี้)
├── docs/                     # เอกสารต่างๆ
│   ├── BUILD_GUIDE.md       # คู่มือ build แบบละเอียด
│   ├── TFTP_BOOT.md         # คู่มือ boot ผ่าน TFTP
│   └── FLASH_GUIDE.md       # คู่มือ flash ลง NAND
├── scripts/                  # สคริปต์อัตโนมัติ
│   ├── 01-setup-deps.sh     # ติดตั้ง dependencies
│   ├── 02-clone-openwrt.sh  # ดึง OpenWrt source
│   ├── y/home/codespace/openwrt-en752903-config-build.sh   # Configure และ build
│   └── 04-tftp-deploy.sh    # Deploy ไฟล์ไป TFTP server
├── config/                   # Configuration files
│   ├── .config.en7523       # OpenWrt .config สำหรับ EN7523
│   └── diffconfig           # Minimal config diff
├── dts/                      # Device Tree Source files
│   └── t3-t626pro.dts       # DTS template สำหรับ T626Pro
└── uboot-commands/           # U-Boot command sequences
    ├── tftp-boot.txt        # คำสั่งสำหรับ TFTP boot
    └── flash-write.txt      # คำสั่งสำหรับ flash write

```

## Quick Start

### 1. เตรียมสภาพแวดล้อม (Ubuntu 22.04/24.04)

```bash
cd /workspaces/t3-t626-pro
./scripts/01-setup-deps.sh
```

### 2. ดึง OpenWrt Source

```bash
./scripts/02-clone-openwrt.sh
```

### 3. Configure และ Build

```bash
./scripts/03-config-build.sh
```

หรือ manual:

```bash
cd ~/openwrt-en7529/openwrt
make menuconfig
# เลือก: Target System → Airoha ARM
#         Subtarget → EN7523
#         Target Profile → Generic EN7523 / EVB
#         Global build settings → เปิด initramfs
make -j$(nproc) V=s
```

### 4. Test Boot ผ่าน TFTP

ดูรายละเอียดใน: [`docs/TFTP_BOOT.md`](docs/TFTP_BOOT.md)

```bash
# Deploy ไฟล์ไป TFTP server (macOS)
./scripts/04-tftp-deploy.sh

# ที่ U-Boot prompt:
tftpboot 0x81800000 openwrt-airoha-en7523-t626pro-initramfs-kernel.bin
bootm 0x81800000
```

## Output Files

หลัง build เสร็จ ไฟล์จะอยู่ที่:

```
~/openwrt-en7529/openwrt/bin/targets/airoha/en7523/
└── openwrt-airoha-en7523-<profile>-initramfs-kernel.bin
```

ไฟล์นี้คือ **kernel + initramfs rootfs** สำหรับ boot ผ่าน RAM (ไม่แตะ NAND)

## Memory Layout (EN7529)

| Address Range | Size | Purpose |
|--------------|------|---------|
| `0x80000000 - 0x9FFFFFFF` | 512 MB | System RAM |
| `0x81800000` | - | **Safe load address สำหรับ TFTP** |
| `0x000C0000` | ~8 MB | Kernel partition (NAND) |
| `0x008C0000` | ~remaining | RootFS partition (NAND) |

## ขั้นตอนถัดไป

เมื่อ initramfs kernel boot สำเร็จ:

1. ✅ ตรวจสอบ hardware detection (RAM, NAND, Switch, Serial)
2. ⏳ ปรับแต่ง DTS ให้ตรงกับฮาร์ดแวร์ T626Pro ทุกอย่าง
3. ⏳ Build non-initramfs kernel + separate squashfs/UBI rootfs
4. ⏳ Flash ลง NAND อย่างถาวร
5. ⏳ ตั้งค่า bootcmd/bootargs ให้ boot จาก NAND

## เอกสารเพิ่มเติม

- [BUILD_GUIDE.md](docs/BUILD_GUIDE.md) - คู่มือ build แบบละเอียดทุกขั้นตอน
- [TFTP_BOOT.md](docs/TFTP_BOOT.md) - วิธี boot ผ่าน TFTP + troubleshooting
- [FLASH_GUIDE.md](docs/FLASH_GUIDE.md) - วิธี flash kernel/rootfs ลง NAND

## Reference Links

- [OpenWrt EN7523 Support](https://openwrt.org/toh/hwdata/airoha/airoha_en7523)
- [Airoha EN7523 Patch Series](https://patchwork.ozlabs.org/project/openwrt/patch/20220926132910.3690-1-nbd@nbd.name/)
- [OpenWrt Build System](https://openwrt.org/docs/guide-developer/toolchain/use-buildsystem)

## License

Documentation และ scripts ใน project นี้: MIT License
OpenWrt source code: GPL v2

---

**Status**: 🚧 In Development
**Last Updated**: November 26, 2025
