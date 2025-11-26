# Hardware Information - T3 T626Pro

รวบรวมข้อมูลฮาร์ดแวร์ของ T3 T626Pro สำหรับใช้ปรับแต่ง DTS

---

## SoC Specifications

**Airoha EN7529**
- Family: EN7523/EN7529 (MediaTek/Airoha)
- CPU: ARM Cortex-A53 Dual-Core @ 1.3 GHz
- Architecture: ARMv8 64-bit
- ISA: AArch64

---

## Memory

**RAM:**
- Type: DDR3
- Size: 512 MB (0x20000000)
- Base Address: 0x80000000
- End Address: 0x9FFFFFFF

---

## Flash Storage

**NAND Flash:**
- Type: SPI-NAND
- Size: TBD (ต้องตรวจสอบจากบอร์ดจริง)
- Interface: SPI
- Controller: Airoha EN7523 SNAND Controller

**Partition Layout (Preliminary):**
```
mtd0: u-boot       @ 0x00000000  Size: 512 KB   (0x00080000)
mtd1: u-boot-env   @ 0x00080000  Size: 256 KB   (0x00040000)
mtd2: kernel       @ 0x000C0000  Size: 8 MB     (0x00800000)
mtd3: rootfs       @ 0x008C0000  Size: 119 MB   (0x07700000)
mtd4: config       @ 0x07FC0000  Size: 256 KB   (0x00040000)
```

*หมายเหตุ: ต้องยืนยันจาก `mtdparts` ใน U-Boot*

---

## Network/Ethernet

**Built-in Switch:**
- Type: EN7529 Integrated Switch
- Ports: 5x Gigabit Ethernet (1 WAN + 4 LAN)
- PHY: Internal

**Port Mapping (TBD):**
```
Port 0: WAN  (ต้อง verify)
Port 1: LAN1
Port 2: LAN2
Port 3: LAN3
Port 4: LAN4
```

---

## Serial Console

**UART0:**
- Interface: NS16550A compatible
- Register Base: 0x1FBF0000
- IRQ: 18
- Clock: 40 MHz
- Settings: 115200 8N1

**Pinout (TBD):**
```
Pin 1: GND
Pin 2: TX  (output from board)
Pin 3: RX  (input to board)
Pin 4: VCC (optional, don't connect to USB-Serial)
```

---

## GPIO

**GPIO Controller:**
- Base Address: 0x1FBF0200
- GPIOs: 32 pins (TBD - ต้อง verify)

**Known Mappings (ต้อง verify จากฮาร์ดแวร์):**

| GPIO | Function | Active | Notes |
|------|----------|--------|-------|
| 8    | WPS Button | LOW | TBD |
| 9    | Reset Button | LOW | TBD |
| 10   | Status LED | LOW | Green |
| 11   | WAN LED | LOW | Green |
| 12   | LAN LED | LOW | Green |

---

## LEDs

**LED Configuration (TBD - ต้อง verify):**

| LED Name | Color | GPIO | Active | Function |
|----------|-------|------|--------|----------|
| Status   | Green | 10   | LOW    | System status |
| WAN      | Green | 11   | LOW    | WAN link |
| LAN      | Green | 12   | LOW    | LAN link |
| Power    | ?     | ?    | ?      | Power indicator |

---

## Buttons

**Button Configuration (TBD):**

| Button | GPIO | Active | Function |
|--------|------|--------|----------|
| Reset  | 9    | LOW    | Factory reset |
| WPS    | 8    | LOW    | WPS pairing |

---

## USB (If present)

- USB 2.0: TBD
- USB 3.0: TBD

*หมายเหตุ: ต้องตรวจสอบว่าบอร์ดมี USB port หรือไม่*

---

## Power

- Input Voltage: 12V DC (TBD)
- Current: TBD

---

## PCB/Board Info

- Model: T3 T626Pro
- Manufacturer: T3
- FCC ID: TBD
- Revision: TBD

---

## How to Gather Hardware Info

### 1. Boot initramfs kernel

```bash
# After booting OpenWrt:
```

### 2. CPU Info
```bash
cat /proc/cpuinfo
```

### 3. Memory Info
```bash
cat /proc/meminfo
free -m
```

### 4. MTD/Flash Info
```bash
cat /proc/mtd
```

### 5. Network Info
```bash
ip link show
dmesg | grep -i eth
swconfig list
```

### 6. GPIO Info
```bash
cat /sys/kernel/debug/gpio
ls /sys/class/gpio/
```

### 7. Hardware Addresses
```bash
dmesg | grep -E "0x[0-9a-f]{8}"
cat /proc/iomem
```

### 8. Device Tree Info
```bash
ls /sys/firmware/devicetree/base/
cat /sys/firmware/devicetree/base/model
cat /sys/firmware/devicetree/base/compatible
```

---

## Todo: Information to Collect

เมื่อ boot initramfs kernel ครั้งแรก ให้เก็บข้อมูลนี้:

- [ ] Full `dmesg` output
- [ ] `/proc/mtd` content
- [ ] Flash chip model/size
- [ ] Ethernet port mapping
- [ ] GPIO assignments (LEDs/Buttons)
- [ ] USB ports (if any)
- [ ] Bootloader version
- [ ] Original firmware partition layout

---

## References

- [EN7523 Datasheet](TBD)
- [OpenWrt EN7523 Wiki](https://openwrt.org/toh/hwdata/airoha/airoha_en7523)
- [Kernel Device Tree Bindings](https://www.kernel.org/doc/Documentation/devicetree/bindings/)

---

**Last Updated**: November 26, 2025
**Status**: 🚧 Template - Need to fill with actual hardware data
