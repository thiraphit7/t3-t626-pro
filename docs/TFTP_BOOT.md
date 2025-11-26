# คู่มือ TFTP Boot สำหรับ EN7529/T626Pro

คู่มือนี้อธิบายการ boot kernel ผ่าน TFTP + U-Boot แบบละเอียด

---

## ภาพรวม

```
[macOS TFTP Server]  <--ethernet-->  [T626Pro U-Boot]
   192.168.1.10                        192.168.1.20
   
   kernel.bin  -------TFTP------->  Load to RAM 0x81800000
                                    bootm 0x81800000
                                    → Linux boots!
```

**ข้อดี:**
- ✅ ไม่แตะ NAND flash (ปลอดภัย)
- ✅ Iterate/debug ได้เร็ว
- ✅ Test kernel ก่อน flash จริง

**ข้อเสีย:**
- ❌ Boot ช้ากว่า (TFTP transfer)
- ❌ ต้อง TFTP server online ตลอด
- ❌ Reset แล้วหาย (RAM-only)

---

## Part 1: ตั้งค่า TFTP Server (macOS)

### 1.1 เปิด TFTP Service

```bash
# ตรวจสอบสถานะ
sudo launchctl list | grep tftp

# เปิด TFTP server
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist
```

### 1.2 ตั้งค่า Firewall

System Settings → Network → Firewall:
- อนุญาต incoming connection บน port 69 (TFTP)

หรือใช้ Terminal:

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/libexec/tftpd
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /usr/libexec/tftpd
```

### 1.3 เตรียม TFTP Root Directory

```bash
# TFTP root บน macOS
cd /private/tftpboot

# ตรวจสอบ permissions
sudo chmod 755 /private/tftpboot
sudo chown -R $(whoami):staff /private/tftpboot
```

### 1.4 Copy Kernel Image

```bash
# จาก build machine (ถ้าแยกเครื่อง)
scp ~/openwrt-en7529/openwrt/bin/targets/airoha/en7523/*-initramfs-kernel.bin \
    user@mac-ip:/private/tftpboot/

# หรือ local copy
cp <kernel-file> /private/tftpboot/openwrt-en7529-t626pro.bin
```

### 1.5 Test TFTP Server

```bash
# จากเครื่องอื่นใน LAN
tftp 192.168.1.10
tftp> get openwrt-en7529-t626pro.bin
tftp> quit

# ถ้าได้ไฟล์ = TFTP ใช้งานได้!
```

---

## Part 2: ตั้งค่า Network บน T626Pro

### 2.1 เชื่อมต่อ Serial Console

**อุปกรณ์:**
- USB-to-Serial adapter (CP2102, PL2303, etc.)
- Terminal app: `screen`, `minicom`, `putty`

**Settings:**
```
Baud Rate: 115200
Data Bits: 8
Parity:    None
Stop Bits: 1
Flow Ctrl: None
```

**เชื่อมต่อ:**
```bash
# macOS/Linux
screen /dev/tty.usbserial-* 115200

# หรือ
minicom -D /dev/tty.usbserial-* -b 115200
```

### 2.2 เข้า U-Boot Prompt

Power on board → กดปุ่มใดก็ได้ใน 3 วินาที

ควรเห็น:
```
U-Boot 2022.xx (EN7523)
...
Hit any key to stop autoboot:  3... 2... 1...
ECNT>
```

### 2.3 ตั้งค่า IP Address

```
ECNT> setenv ipaddr 192.168.1.20
ECNT> setenv netmask 255.255.255.0
ECNT> setenv serverip 192.168.1.10
ECNT> setenv gatewayip 192.168.1.1
ECNT> saveenv
Saving Environment to Flash...
```

**หมายเหตุ:**
- `ipaddr`: IP ของ T626Pro board
- `serverip`: IP ของ macOS TFTP server
- ต้องอยู่ subnet เดียวกัน!

### 2.4 Test Network Connection

```
ECNT> ping 192.168.1.10
Using eth0
host 192.168.1.10 is alive
```

**ถ้า ping ไม่ผ่าน:**
- ตรวจสอบสาย Ethernet
- ตรวจสอบ Switch/Router
- ปิด firewall บน macOS ชั่วคราว
- ลอง `setenv ethaddr` (ถ้า MAC address ไม่ถูก)

---

## Part 3: TFTP Boot Kernel

### 3.1 Load Kernel to RAM

```
ECNT> tftpboot 0x81800000 openwrt-en7529-t626pro.bin
```

**ควรเห็น:**
```
Using eth0
TFTP from server 192.168.1.10; our IP address is 192.168.1.20
Filename 'openwrt-en7529-t626pro.bin'.
Load address: 0x81800000
Loading: #################################################################
         #################################################################
         ##############################
         x.x MiB/s
done
Bytes transferred = xxxxxxx (xxxxxx hex)
```

### 3.2 Verify Image

```
ECNT> iminfo 0x81800000

Image at 0x81800000:
   Image Name:   ARM OpenWrt Linux-6.x.x
   Created:      2025-11-26  10:30:45 UTC
   Image Type:   ARM Linux Kernel Image (gzip compressed)
   Data Size:    xxxxxxx Bytes = x.x MiB
   Load Address: 80008000
   Entry Point:  80008000
   Verifying Checksum ... OK
```

### 3.3 Boot Kernel

```
ECNT> bootm 0x81800000
## Booting kernel from Legacy Image at 81800000 ...
   Image Name:   ARM OpenWrt Linux-6.x.x
   ...
   Uncompressing Kernel Image ... OK

Starting kernel ...

[    0.000000] Booting Linux on physical CPU 0x0
[    0.000000] Linux version 6.x.x ...
[    0.000000] Machine model: Airoha EN7523 EVB
[    0.000000] Memory: 512MB ...
```

---

## Part 4: สร้าง Boot Script (Auto TFTP Boot)

### 4.1 สร้าง bootcmd

```
ECNT> setenv tftpfile openwrt-en7529-t626pro.bin
ECNT> setenv loadaddr 0x81800000
ECNT> setenv bootcmd_tftp 'tftpboot ${loadaddr} ${tftpfile}; bootm ${loadaddr}'
ECNT> saveenv
```

### 4.2 ใช้งาน

```
ECNT> run bootcmd_tftp
```

หรือตั้งเป็น default boot:

```
ECNT> setenv bootcmd 'run bootcmd_tftp'
ECNT> saveenv
```

⚠️ **คำเตือน:** อย่าตั้ง `bootcmd` ถาวร จนกว่า kernel จะ boot ได้แน่นอน!

---

## Troubleshooting

### ❌ TFTP Error: "Timeout"

**สาเหตุ:**
- Network ไม่เชื่อมต่อ
- TFTP server ไม่ทำงาน
- Firewall block

**แก้ไข:**
```bash
# บน macOS - ตรวจสอบ TFTP service
sudo launchctl list | grep tftp

# Re-enable TFTP
sudo launchctl unload /System/Library/LaunchDaemons/tftp.plist
sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist

# Test จาก macOS
tftp localhost
tftp> get openwrt-en7529-t626pro.bin
```

### ❌ TFTP Error: "File not found"

**สาเหตุ:**
- ไฟล์ไม่อยู่ใน `/private/tftpboot`
- ชื่อไฟล์ผิด (case-sensitive!)

**แก้ไข:**
```bash
# ตรวจสอบไฟล์
ls -la /private/tftpboot/

# ตรวจสอบ permissions
chmod 644 /private/tftpboot/*.bin
```

### ❌ bootm Error: "Bad Magic Number"

**สาเหตุ:**
- ไฟล์ไม่ใช่ uImage format
- ไฟล์เสียหาย (download ไม่สมบูรณ์)

**แก้ไข:**
```bash
# ตรวจสอบไฟล์
file openwrt-*.bin
# ต้องเป็น: "u-boot legacy uImage"

# ถ้าไม่ใช่ = build ผิด หรือ download เสีย
# → Re-download หรือ re-build
```

### ❌ Kernel Panic ทันทีหลัง boot

**สาเหตุ:**
- DTS ไม่ตรงฮาร์ดแวร์
- initramfs rootfs เสีย
- Kernel config ผิด

**แก้ไข:**
1. อ่าน panic message (บรรทัดสุดท้ายก่อน hang)
2. ตรวจสอบ `Machine model:` ตรงกับบอร์ดหรือไม่
3. Rebuild kernel ด้วย config ที่ถูกต้อง

---

## Memory Map สำหรับ EN7529

| Address | Purpose | Notes |
|---------|---------|-------|
| `0x80000000` | RAM Start | System RAM base |
| `0x80000000 - 0x80100000` | U-Boot | ห้ามใช้ |
| `0x81000000 - 0x81800000` | U-Boot workspace | ห้ามใช้ |
| `0x81800000` | **TFTP Load Address** | **ใช้ที่นี่!** |
| `0x82000000` | Safe for large files | Alternative |
| `0x9FFFFFFF` | RAM End (512MB) | |

---

## Best Practices

1. ✅ **ใช้ fixed IP**: อย่าใช้ DHCP (U-Boot อาจไม่รองรับ)
2. ✅ **ชื่อไฟล์สั้น**: หลีกเลี่ยงชื่อยาว/มีอักขระพิเศษ
3. ✅ **Test ทีละขั้น**: ping → tftpboot → iminfo → bootm
4. ✅ **Backup bootcmd เดิม**: `printenv bootcmd` ก่อนเปลี่ยน
5. ❌ **อย่าตั้ง autoboot**: จนกว่า kernel stable 100%

---

## Quick Reference Commands

```bash
# ตั้งค่า network
setenv ipaddr 192.168.1.20
setenv serverip 192.168.1.10
saveenv

# Test connection
ping 192.168.1.10

# Load & boot
tftpboot 0x81800000 openwrt-en7529-t626pro.bin
bootm 0x81800000

# ดูค่าที่ตั้งไว้
printenv

# Reset ค่าเป็น default (อันตราย!)
# env default -a
```

---

**Next**: หลัง boot สำเร็จ → [`FLASH_GUIDE.md`](FLASH_GUIDE.md)

**Last Updated**: November 26, 2025
