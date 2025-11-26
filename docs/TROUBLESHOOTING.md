# Troubleshooting Guide - OpenWrt สำหรับ EN7529/T626Pro

คู่มือแก้ไขปัญหาทั่วไปที่พบระหว่าง build และ boot

---

## Build Time Issues

### ❌ Error: "No rule to make target..."

**สาเหตุ:**
- Feeds ไม่ได้ update/install
- Package dependency ขาดหาย

**แก้ไข:**
```bash
cd ~/openwrt-en7529/openwrt
./scripts/feeds clean
./scripts/feeds update -a
./scripts/feeds install -a
make defconfig
make -j$(nproc) V=s
```

---

### ❌ Compilation Error: package build failed

**สาเหตุ:**
- Source code ของ package มีปัญหา
- Dependency ขาด

**แก้ไข:**
```bash
# ดู error log
cat build.log | grep -i error

# Clean package ที่มีปัญหา
make package/<package-name>/clean

# Build อีกครั้งด้วย single thread เพื่อดู error ชัด
make package/<package-name>/compile V=s -j1

# หรือข้าม package นั้นโดยปิดใน menuconfig
make menuconfig
# → ไป Packages → หา package นั้นแล้วปิด
```

---

### ❌ Build หยุดที่ "Building kernel modules"

**สาเหตุ:**
- Kernel config ไม่ตรงกับ .config
- Module dependency ผิด

**แก้ไข:**
```bash
# Clean kernel
make target/linux/clean

# Rebuild kernel only
make target/linux/compile V=s
```

---

### ❌ Out of disk space

**แก้ไข:**
```bash
# ลบ build artifacts เก่า
make clean

# หรือลบทั้งหมด (รวม downloads)
make dirclean

# ตรวจสอบเนื้อที่
df -h
du -sh ~/openwrt-en7529/
```

---

## TFTP Boot Issues

### ❌ "Timeout" เมื่อ tftpboot

**สาเหตุ:**
- Network ไม่เชื่อม
- TFTP server ไม่ทำงาน
- Firewall block

**Debug:**
```bash
# บน U-Boot
ECNT> printenv ipaddr serverip
ECNT> ping ${serverip}

# ถ้า ping ไม่ผ่าน:
ECNT> setenv ipaddr 192.168.1.20
ECNT> setenv serverip 192.168.1.10
ECNT> saveenv
ECNT> ping ${serverip}

# บน macOS - ตรวจสอบ TFTP service
sudo launchctl list | grep tftp
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist

# Test TFTP manually
tftp localhost
tftp> get <filename>
```

---

### ❌ "File not found" เมื่อ tftpboot

**แก้ไข:**
```bash
# ตรวจสอบไฟล์ใน TFTP root
ls -la /private/tftpboot/

# ตรวจสอบชื่อไฟล์ (case sensitive!)
ECNT> setenv tftpfile openwrt-exact-filename.bin

# ตรวจสอบ permissions
sudo chmod 644 /private/tftpboot/*.bin
```

---

### ❌ "Bad Magic Number" เมื่อ bootm

**สาเหตุ:**
- ไฟล์ไม่ใช่ uImage format
- Download ไม่สมบูรณ์

**แก้ไข:**
```bash
# ตรวจสอบ file type
file openwrt-*.bin
# ต้องเห็น: "u-boot legacy uImage, ARM OpenWrt Linux-..."

# ถ้าไม่ใช่ → rebuild kernel แบบถูกต้อง
# หรือ download ใหม่
```

---

### ❌ Kernel boots แต่ panic ทันที

**Kernel log ที่อาจเห็น:**
```
[    0.000000] Kernel panic - not syncing: VFS: Unable to mount root fs
```

**สาเหตุ:**
- initramfs rootfs เสีย
- Kernel config ไม่มี required drivers

**แก้ไข:**
```bash
# Rebuild kernel โดยเปิด initramfs
make menuconfig
# → Target Images → เปิด "ramdisk"
make target/linux/compile V=s
```

---

## Flash/NAND Issues

### ❌ "NAND not detected"

**Kernel log:**
```
[    x.xxx] No NAND device found
```

**สาเหตุ:**
- DTS ไม่มี SPI-NAND node
- Driver ไม่ถูก compile

**แก้ไข:**
```bash
# ตรวจสอบ DTS มี spi_nand node
cat target/linux/airoha/dts/t3-t626pro.dts | grep -A10 spi_nand

# ตรวจสอบ kernel config
grep CONFIG_MTD_SPI_NAND .config
# ต้องได้: CONFIG_MTD_SPI_NAND=y
```

---

### ❌ mtd write failed: "Input/output error"

**สาเหตุ:**
- Bad blocks บน NAND
- Partition ไม่ตรง

**แก้ไข:**
```bash
# ดู bad blocks
nand dump /dev/mtd2

# ลอง erase ก่อน write
mtd erase <partition>
mtd write <file> <partition>

# หรือใช้ U-Boot
nand scrub <offset> <size>  # อันตราย! ลบทุกอย่าง
```

---

### ❌ Boot จาก NAND แล้ว "No init found"

**Kernel log:**
```
[    x.xxx] Kernel panic - not syncing: No init found.
```

**สาเหตุ:**
- `root=` ผิด
- RootFS ไม่ถูก mount

**แก้ไข:**
```bash
# ที่ U-Boot
ECNT> printenv bootargs

# ต้องมี:
# root=/dev/mtdblock3 rootfstype=squashfs

# ถ้าไม่มีหรือผิด:
ECNT> setenv bootargs 'console=ttyS0,115200 root=/dev/mtdblock3 rootfstype=squashfs'
ECNT> saveenv
ECNT> reset
```

---

## Network/Ethernet Issues

### ❌ Ethernet ports ไม่ทำงาน

**Debug:**
```bash
# ดู network interfaces
ip link show

# ถ้าไม่เห็น eth0:
dmesg | grep -i eth
dmesg | grep -i mac

# ตรวจสอบ driver load
lsmod | grep -i eth
```

**แก้ไข:**
- ตรวจสอบ DTS มี ethernet node
- Rebuild kernel ด้วย driver ที่ถูกต้อง

---

### ❌ LAN ports ใช้งานไม่ได้

**สาเหตุ:**
- Switch ไม่ถูก config
- VLAN settings ผิด

**Debug:**
```bash
# ดู switch config
swconfig list
swconfig dev switch0 show

# ดู bridge/VLAN
brctl show
```

---

## Serial Console Issues

### ❌ ไม่เห็น output ที่ serial console

**ตรวจสอบ:**
1. Baud rate ถูกต้อง: 115200 8N1
2. TX/RX สาย cross ถูกต้อง
3. Ground connected

**Debug:**
```bash
# บน Linux/macOS
ls /dev/tty.*
screen /dev/tty.usbserial-* 115200

# ถ้ายัง blank:
# - ลองกด Enter หลายๆ ครั้ง
# - Power cycle board
# - ตรวจสอบสาย USB-Serial
```

---

## DTS Issues

### ❌ LED ไม่ทำงาน

**Debug:**
```bash
# ดู GPIO
cat /sys/kernel/debug/gpio

# Test LED manual
echo 10 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio10/direction
echo 1 > /sys/class/gpio/gpio10/value  # ON
```

**แก้ไข DTS:**
```dts
led_status: status {
    gpios = <&gpio0 10 GPIO_ACTIVE_LOW>;  # ลอง LOW/HIGH
};
```

---

### ❌ Button ไม่ทำงาน

**Debug:**
```bash
# Monitor input events
evtest

# หรือดู /proc/interrupts
cat /proc/interrupts | grep gpio

# กด button → ดูว่ามี interrupt increment หรือไม่
```

---

## Recovery

### 🚨 Board Brick (boot ไม่ขึ้น)

**Recovery via TFTP:**
```
1. เข้า U-Boot (serial console)
2. ตั้งค่า network
3. Load backup firmware via TFTP
4. Flash กลับ

ECNT> setenv ipaddr 192.168.1.20
ECNT> setenv serverip 192.168.1.10
ECNT> tftpboot 0x81800000 backup-kernel.bin
ECNT> nand erase 0x000C0000 0x800000
ECNT> nand write 0x81800000 0x000C0000 ${filesize}
```

---

### 🚨 U-Boot env พัง

```
ECNT> env default -a
ECNT> setenv bootcmd 'nboot 0x81800000 0 0x000C0000; bootm 0x81800000'
ECNT> setenv bootargs 'console=ttyS0,115200 root=/dev/mtdblock3 rootfstype=squashfs'
ECNT> saveenv
```

---

## Getting Help

ถ้าแก้ไม่ได้ ให้เก็บข้อมูลนี้:

```bash
# Kernel version
uname -a

# Boot log
dmesg > boot.log

# MTD info
cat /proc/mtd > mtd.txt

# Network info
ip addr > network.txt
ip route >> network.txt

# Hardware info
cat /proc/cpuinfo > cpu.txt
cat /proc/meminfo > mem.txt
```

แล้วไปถาม:
- OpenWrt Forum: https://forum.openwrt.org/
- OpenWrt Wiki: https://openwrt.org/
- Airoha EN7523 specific threads

---

**Last Updated**: November 26, 2025
