# คู่มือ Build OpenWrt Kernel สำหรับ EN7529/T626Pro

คู่มือนี้อธิบายขั้นตอนการ build OpenWrt kernel แบบละเอียดทุกขั้นตอน

## ภาพรวม Pipeline

```
[1. Setup]  →  [2. Clone]  →  [3. Configure]  →  [4. Build]  →  [5. Test Boot]
   deps         OpenWrt        menuconfig        make          TFTP+U-Boot
```

---

## Step 1: เตรียม Build Environment

### Requirements

- **OS**: Ubuntu 22.04 LTS หรือ 24.04 LTS (แนะนำ VM/Container)
- **RAM**: อย่างน้อย 4 GB (แนะนำ 8 GB+)
- **Disk**: อย่างน้อย 30 GB ว่าง
- **CPU**: Multi-core (build จะใช้ทุก core)

### ติดตั้ง Dependencies

**วิธีที่ 1: ใช้สคริปต์อัตโนมัติ**

```bash
cd /workspaces/t3-t626-pro
./scripts/01-setup-deps.sh
```

**วิธีที่ 2: Manual Install**

```bash
sudo apt update
sudo apt install -y \
  build-essential git subversion libncurses5-dev zlib1g-dev gawk \
  flex gettext unzip file libssl-dev python3 rsync wget \
  libc6-dev libz-dev libelf-dev ccache clang bison g++ \
  gcc-multilib g++-multilib python3-distutils python3-dev \
  python3-setuptools swig time xsltproc
```

### ตรวจสอบ Installation

```bash
gcc --version      # ควรได้ >= 9.x
make --version     # ควรได้ >= 4.x
python3 --version  # ควรได้ >= 3.8
```

---

## Step 2: Clone OpenWrt Source

### ใช้สคริปต์

```bash
./scripts/02-clone-openwrt.sh
```

### Manual Clone

```bash
mkdir -p ~/openwrt-en7529
cd ~/openwrt-en7529

git clone https://git.openwrt.org/openwrt/openwrt.git
cd openwrt

./scripts/feeds update -a
./scripts/feeds install -a
```

### ตรวจสอบ Airoha Target

```bash
ls -la target/linux/airoha/
```

ถ้ามี directory `airoha` แสดงว่า EN7523/EN7529 support มีอยู่แล้ว

---

## Step 3: Configure Build

### เปิด menuconfig

```bash
cd ~/openwrt-en7529/openwrt
make menuconfig
```

### การตั้งค่าที่สำคัญ

#### 3.1 Target System

```
Target System  →  [*] Airoha ARM
```

หรือถ้าไม่มี อาจเป็น:
- `MediaTek Ralink ARM`
- `Generic ARM`

#### 3.2 Subtarget

```
Subtarget  →  [*] EN7523
```

#### 3.3 Target Profile

เลือก profile ที่ใกล้เคียงที่สุด:
```
Target Profile  →  [*] Airoha EN7523 EVB
                   หรือ
                   [*] Generic EN7523
```

#### 3.4 Target Images (สำคัญ!)

```
Target Images  →
    [*] ramdisk
        └─ Compression (gzip)  →  gzip
    [*] Build initramfs image
```

หรือใน `Global build settings`:
```
Global build settings  →
    Kernel build options  →
        [*] Compile the kernel with initramfs support
```

#### 3.5 Kernel Options (Optional - สำหรับ Debug)

```
Global build settings  →
    Kernel build options  →
        [*] Compile the kernel with debug info
        [*] Compile the kernel with symbol table information
```

#### 3.6 Serial Console (ต้องเปิด!)

```
Base system  →
    [*] busybox
        └─ Configuration  →
            Init Utilities  →
                [*] init
```

### บันทึก Config

1. กด `Save` (หรือ `S`)
2. ใช้ชื่อ default: `.config`
3. กด `Exit` จนออกจาก menuconfig

---

## Step 4: Build Kernel

### Full Build (ครั้งแรก)

```bash
cd ~/openwrt-en7529/openwrt
make -j$(nproc) V=s
```

**Parameters:**
- `-j$(nproc)`: ใช้ทุก CPU core
- `V=s`: Verbose output (เห็น error ชัดเจน)

**เวลาที่ใช้:**
- ครั้งแรก: 1-3 ชั่วโมง (ขึ้นกับ CPU/RAM)
- ครั้งถัดไป: 5-15 นาที (rebuild เฉพาะที่เปลี่ยน)

### Build เฉพาะ Kernel (Rebuild)

```bash
make target/linux/compile V=s
```

### Clean Build (ถ้ามีปัญหา)

```bash
make clean
make -j$(nproc) V=s
```

---

## Step 5: ตรวจสอบ Output Files

### หา Kernel Image

```bash
cd ~/openwrt-en7529/openwrt
find bin/targets/airoha/ -name "*-initramfs-kernel.bin"
```

**ตัวอย่าง output:**
```
bin/targets/airoha/en7523/openwrt-airoha-en7523-generic-initramfs-kernel.bin
```

### ตรวจสอบรายละเอียดไฟล์

```bash
ls -lh bin/targets/airoha/en7523/
file bin/targets/airoha/en7523/*-initramfs-kernel.bin
```

**ข้อมูลที่ควรเห็น:**
- ขนาดไฟล์: ~5-15 MB
- Type: `u-boot legacy uImage`
- Architecture: `ARM`

---

## Step 6: Deploy และ Test

### 6.1 Copy ไฟล์ไป TFTP Server

**วิธีที่ 1: ใช้สคริปต์**
```bash
./scripts/04-tftp-deploy.sh
```

**วิธีที่ 2: Manual SCP**
```bash
scp bin/targets/airoha/en7523/openwrt-airoha-en7523-*-initramfs-kernel.bin \
    user@192.168.1.10:/private/tftpboot/
```

### 6.2 Test Boot ที่ U-Boot

เชื่อมต่อ Serial Console (115200 8N1) แล้วพิมพ์:

```
ECNT> setenv ipaddr 192.168.1.20
ECNT> setenv serverip 192.168.1.10
ECNT> saveenv

ECNT> ping 192.168.1.10
ECNT> tftpboot 0x81800000 openwrt-airoha-en7523-generic-initramfs-kernel.bin
ECNT> bootm 0x81800000
```

### 6.3 สิ่งที่ควรเห็นเมื่อ Boot สำเร็จ

```
## Booting kernel from Legacy Image at 81800000 ...
   Image Name:   ARM OpenWrt Linux-6.x.x
   Created:      2025-11-26  ...
   Image Type:   ARM Linux Kernel Image (gzip compressed)
   Data Size:    xxxxx Bytes = x.x MiB
   Load Address: 80008000
   Entry Point:  80008000
   Verifying Checksum ... OK
   Uncompressing Kernel Image ... OK

Starting kernel ...

[    0.000000] Booting Linux on physical CPU 0x0
[    0.000000] Linux version 6.x.x ...
[    0.000000] CPU: ARMv8 Processor [410fd034] revision 4
[    0.000000] Machine model: Airoha EN7523 EVB
[    0.000000] Memory: 512MB ...
...
[    x.xxx] Welcome to OpenWrt!
```

---

## Troubleshooting

### Error: "No rule to make target"

**สาเหตุ:** Config ไม่ครบหรือ feeds ไม่ update

**แก้ไข:**
```bash
./scripts/feeds update -a
./scripts/feeds install -a
make defconfig
make -j$(nproc) V=s
```

### Error: Build fails ด้วย "recipe failed"

**สาเหตุ:** Compilation error ใน package ใดๆ

**แก้ไข:**
```bash
# ดู error log
tail -100 build.log

# Clean และ rebuild
make clean
make -j1 V=s  # ใช้ single thread เพื่อดู error ชัดเจน
```

### Kernel ไม่ boot (U-Boot error)

**ตรวจสอบ:**
1. ไฟล์เป็น uImage format หรือไม่: `file <kernel.bin>`
2. Address ถูกต้องหรือไม่: `0x81800000` (ต้องไม่ทับ U-Boot/RAM)
3. TFTP download สำเร็จหรือไม่ (ดูขนาดไฟล์)

### Kernel boot แต่ panic ทันที

**สาเหตุ:** DTS ไม่ตรง หรือ driver missing

**แก้ไข:**
1. ตรวจสอบ console output: `Machine model: ...`
2. ตรวจสอบ RAM detection: `Memory: xxxMB`
3. Adjust DTS (ดู `docs/` สำหรับขั้นตอน DTS customization)

---

## Next Steps

เมื่อ initramfs kernel boot สำเร็จแล้ว:

1. ✅ ตรวจสอบ hardware detection
2. ⏳ Customize DTS สำหรับ T626Pro
3. ⏳ Build production kernel + rootfs
4. ⏳ Flash ลง NAND

ดูรายละเอียดเพิ่มเติมใน:
- [`TFTP_BOOT.md`](TFTP_BOOT.md) - TFTP boot troubleshooting
- [`FLASH_GUIDE.md`](FLASH_GUIDE.md) - Flash ลง NAND

---

**Last Updated**: November 26, 2025
