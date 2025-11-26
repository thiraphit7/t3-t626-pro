# คู่มือ Flash Kernel/RootFS ลง NAND

คู่มือนี้อธิบายการ flash kernel และ rootfs ลง NAND flash อย่างถาวร

⚠️ **คำเตือน:** การ flash ผิดพลาดอาจทำให้บอร์ด brick! ต้องแน่ใจว่า:
- Kernel boot ผ่าน TFTP ได้แล้ว
- Hardware detection ถูกต้อง (RAM, NAND, Serial)
- มี backup ของ firmware เดิม

---

## ภาพรวม Process

```
1. Boot initramfs kernel (TFTP)
2. ตรวจสอบ NAND partitions
3. Backup firmware เดิม
4. Erase target partitions
5. Write kernel image
6. Write rootfs image
7. Update bootcmd/bootargs
8. Reboot และทดสอบ
```

---

## Part 1: เตรียมความพร้อม

### 1.1 Boot initramfs kernel ผ่าน TFTP

ตาม [`TFTP_BOOT.md`](TFTP_BOOT.md):

```
ECNT> tftpboot 0x81800000 openwrt-en7529-t626pro-initramfs-kernel.bin
ECNT> bootm 0x81800000
```

รอจนระบบ boot เสร็จ → ได้ OpenWrt shell

### 1.2 ตรวจสอบ NAND Flash

```bash
# ดู MTD partitions
cat /proc/mtd

# ควรเห็นประมาณนี้:
# dev:    size   erasesize  name
# mtd0: 00080000 00020000 "u-boot"
# mtd1: 00040000 00020000 "u-boot-env"
# mtd2: 00800000 00020000 "kernel"
# mtd3: 07700000 00020000 "rootfs"
# mtd4: 00040000 00020000 "config"
```

**หมายเหตุ:**
- Partition layout อาจแตกต่างกันตามบอร์ด
- **อย่า erase mtd0 (u-boot)** = brick!
- **อย่า erase mtd1 (u-boot-env)** จนกว่าจำเป็น

### 1.3 ตรวจสอบ Network

```bash
# ถ้า boot initramfs มา network ควรทำงานอยู่แล้ว
ifconfig eth0

# ถ้าไม่มี IP ให้ตั้งเอง:
ifconfig eth0 192.168.1.20 netmask 255.255.255.0 up
route add default gw 192.168.1.1

# Test connection
ping 192.168.1.10
```

---

## Part 2: Backup Firmware เดิม

⚠️ **สำคัญมาก:** Backup ก่อน flash!

### 2.1 Backup via Network

```bash
# จาก OpenWrt shell (บนบอร์ด)
dd if=/dev/mtd0 | ssh user@192.168.1.10 "cat > backup-uboot.bin"
dd if=/dev/mtd1 | ssh user@192.168.1.10 "cat > backup-uboot-env.bin"
dd if=/dev/mtd2 | ssh user@192.168.1.10 "cat > backup-kernel.bin"
dd if=/dev/mtd3 | ssh user@192.168.1.10 "cat > backup-rootfs.bin"

# หรือใช้ wget/curl ถ้ามี HTTP server บนเครื่องปลายทาง
```

### 2.2 Backup ทั้ง Flash

```bash
# Backup flash ทั้งหมด (แนะนำ!)
cat /dev/mtd0 > /tmp/full-backup.bin

# Transfer ออกไป
scp /tmp/full-backup.bin user@192.168.1.10:~/
```

---

## Part 3: เตรียม Image Files

### 3.1 Build Production Kernel + RootFS

บนเครื่อง build (Ubuntu):

```bash
cd ~/openwrt-en7529/openwrt
make menuconfig
```

**ปรับ config:**
```
Target Images  →
    [ ] ramdisk                    # ปิด initramfs!
    [*] squashfs                   # เปิด squashfs rootfs
    Root filesystem partition size → 64 (MB)
```

Build:
```bash
make -j$(nproc) V=s
```

**Output files:**
```
bin/targets/airoha/en7523/
├── openwrt-airoha-en7523-generic-kernel.bin      # Kernel only
├── openwrt-airoha-en7523-generic-rootfs.squashfs # RootFS only
└── openwrt-airoha-en7523-generic-sysupgrade.bin  # Full image (ถ้ามี)
```

### 3.2 Transfer Files ไปบอร์ด

**ผ่าน TFTP:**
```bash
# วางไฟล์ใน /private/tftpboot/
cp bin/targets/airoha/en7523/openwrt-*-kernel.bin /private/tftpboot/
cp bin/targets/airoha/en7523/openwrt-*-rootfs.squashfs /private/tftpboot/
```

**ดึงจากบอร์ด:**
```bash
# บน OpenWrt (board)
cd /tmp
tftp -g -r openwrt-airoha-en7523-generic-kernel.bin 192.168.1.10
tftp -g -r openwrt-airoha-en7523-generic-rootfs.squashfs 192.168.1.10

# ตรวจสอบไฟล์
ls -lh /tmp/*.bin /tmp/*.squashfs
```

---

## Part 4: Flash ลง NAND

### 4.1 ตรวจสอบ Partition Offsets

```bash
cat /proc/mtd
```

**ตัวอย่าง:**
```
mtd2: 00800000 00020000 "kernel"    → offset 0x000C0000
mtd3: 07700000 00020000 "rootfs"    → offset 0x008C0000
```

### 4.2 Flash Kernel

```bash
# Erase kernel partition
mtd erase kernel

# Write kernel
mtd write /tmp/openwrt-airoha-en7523-generic-kernel.bin kernel

# Verify (optional)
md5sum /tmp/openwrt-airoha-en7523-generic-kernel.bin
nanddump -f /tmp/verify-kernel.bin /dev/mtd2
md5sum /tmp/verify-kernel.bin
```

### 4.3 Flash RootFS

```bash
# Erase rootfs partition
mtd erase rootfs

# Write rootfs
mtd write /tmp/openwrt-airoha-en7523-generic-rootfs.squashfs rootfs

# Verify
md5sum /tmp/openwrt-airoha-en7523-generic-rootfs.squashfs
nanddump -f /tmp/verify-rootfs.bin /dev/mtd3
md5sum /tmp/verify-rootfs.bin
```

---

## Part 5: ตั้งค่า U-Boot

### 5.1 Reboot เข้า U-Boot

```bash
reboot
# กดปุ่มใดก็ได้ที่ U-Boot prompt
```

### 5.2 ตั้งค่า bootargs

```
ECNT> setenv bootargs 'console=ttyS0,115200 root=/dev/mtdblock3 rootfstype=squashfs'
```

**Parameters:**
- `console=ttyS0,115200`: Serial console
- `root=/dev/mtdblock3`: RootFS partition (mtd3)
- `rootfstype=squashfs`: Filesystem type

### 5.3 ตั้งค่า bootcmd

```
ECNT> setenv bootcmd 'nboot 0x81800000 0 0x000C0000; bootm 0x81800000'
```

**อธิบาย:**
- `nboot 0x81800000 0 0x000C0000`: อ่าน kernel จาก NAND offset 0xC0000 → RAM 0x81800000
- `bootm 0x81800000`: Boot kernel จาก RAM

**หรือใช้ kernel partition name:**
```
ECNT> setenv bootcmd 'nboot kernel; bootm ${loadaddr}'
```

### 5.4 บันทึกและ Reboot

```
ECNT> saveenv
Saving Environment to Flash...
ECNT> reset
```

---

## Part 6: Troubleshooting

### ❌ Kernel panic: "No init found"

**สาเหตุ:** `root=` ผิด หรือ rootfs เสีย

**แก้ไข:**
```
# ตรวจสอบ mtd number
cat /proc/mtd
# rootfs อยู่ mtd3 → root=/dev/mtdblock3

# แก้ใน U-Boot:
setenv bootargs 'console=ttyS0,115200 root=/dev/mtdblock3 rootfstype=squashfs'
saveenv
```

### ❌ "VFS: Cannot open root device"

**สาเหตุ:** Kernel ไม่มี MTD driver หรือ squashfs support

**แก้ไข:** Rebuild kernel ด้วย config:
```
Device Drivers  →
    Memory Technology Device (MTD) support  →
        [*] MTD partitioning support
        [*] Command line partition table parsing
        NAND  →
            [*] NAND Device Support
            [*] Airoha NAND controller

File systems  →
    [*] Miscellaneous filesystems  →
        [*] SquashFS
```

### ❌ Flash write error

**สาเหตุ:** Bad blocks หรือ partition ไม่พอ

**แก้ไข:**
```bash
# ตรวจสอบ bad blocks
nand dump /dev/mtd2

# ถ้าไฟล์ใหญ่เกินไป → ลด rootfs size
make menuconfig
# Target Images → Root filesystem partition size → ลดลง
```

### ❌ Board brick (boot ไม่ขึ้น)

**Recovery:**
1. เข้า U-Boot ผ่าน Serial
2. Flash kernel/rootfs ใหม่ผ่าน TFTP:
```
ECNT> tftpboot 0x81800000 backup-kernel.bin
ECNT> nand erase 0x000C0000 0x800000
ECNT> nand write 0x81800000 0x000C0000 ${filesize}
```

---

## Part 7: Alternative Method - U-Boot Direct Flash

ถ้าไม่มี initramfs kernel, flash ได้โดยตรงจาก U-Boot:

### 7.1 Load Kernel via TFTP

```
ECNT> setenv ipaddr 192.168.1.20
ECNT> setenv serverip 192.168.1.10
ECNT> tftpboot 0x81800000 openwrt-kernel.bin
```

### 7.2 Erase และ Write

```
ECNT> nand erase 0x000C0000 0x800000
Erasing at 0x8c0000 -- 100% complete.
OK

ECNT> nand write 0x81800000 0x000C0000 ${filesize}
Writing data at 0x8c0000 -- 100% complete.
OK
```

### 7.3 ทำซ้ำกับ RootFS

```
ECNT> tftpboot 0x82000000 openwrt-rootfs.squashfs
ECNT> nand erase 0x008C0000 0x7700000
ECNT> nand write 0x82000000 0x008C0000 ${filesize}
```

---

## Best Practices

1. ✅ **Backup ก่อนเสมอ**
2. ✅ **Test ด้วย initramfs ก่อน flash**
3. ✅ **Verify checksums หลัง write**
4. ✅ **เก็บ backup ไว้หลายที่**
5. ❌ **อย่า flash u-boot จนกว่าจำเป็นจริงๆ**

---

## Quick Reference

### Flash via Linux (initramfs)
```bash
mtd erase kernel
mtd write /tmp/kernel.bin kernel
mtd erase rootfs
mtd write /tmp/rootfs.squashfs rootfs
```

### Flash via U-Boot
```
nand erase 0x000C0000 0x800000
nand write 0x81800000 0x000C0000 ${filesize}
```

### U-Boot bootargs
```
setenv bootargs 'console=ttyS0,115200 root=/dev/mtdblock3 rootfstype=squashfs'
setenv bootcmd 'nboot 0x81800000 0 0x000C0000; bootm 0x81800000'
saveenv
```

---

**Last Updated**: November 26, 2025
