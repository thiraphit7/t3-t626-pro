# Device Tree Customization Guide

คู่มือการปรับแต่ง Device Tree Source (DTS) สำหรับ T3 T626Pro

---

## ภาพรวม

Device Tree (DT) คือไฟล์ที่บอก Linux kernel เกี่ยวกับฮาร์ดแวร์บนบอร์ด:
- CPU cores และ clock speed
- RAM size และ address
- Flash partitions
- GPIO pins (LEDs, buttons)
- Ethernet ports
- Serial console
- อื่นๆ

---

## การใช้งาน DTS Template

### 1. Copy Template ไปยัง OpenWrt Source

```bash
# ตัวอย่างสำหรับ EN7523 target
cp /workspaces/t3-t626-pro/dts/t3-t626pro.dts \
   ~/openwrt-en7529/openwrt/target/linux/airoha/dts/
```

### 2. แก้ไข Makefile ให้ Build DTS นี้

```bash
cd ~/openwrt-en7529/openwrt/target/linux/airoha/image/
vi Makefile
```

เพิ่ม device profile:

```makefile
define Device/t3_t626pro
  DEVICE_VENDOR := T3
  DEVICE_MODEL := T626Pro
  DEVICE_DTS := t3-t626pro
  DEVICE_PACKAGES := kmod-mt7915e
endef
TARGET_DEVICES += t3_t626pro
```

### 3. Rebuild Kernel

```bash
cd ~/openwrt-en7529/openwrt
make target/linux/compile V=s
```

---

## ส่วนสำคัญที่ต้องปรับแต่ง

### 1. Memory Size

ตรวจสอบ RAM จริงบน T626Pro:

```dts
memory@80000000 {
    device_type = "memory";
    reg = <0x80000000 0x20000000>; /* 512 MB */
    /*
     * 0x20000000 = 512 MB
     * 0x10000000 = 256 MB
     * 0x40000000 = 1 GB
     */
};
```

### 2. NAND Flash Partitions

ตรวจสอบ partition layout จาก U-Boot:

```
ECNT> mtdparts
```

แล้วปรับใน DTS:

```dts
partitions {
    compatible = "fixed-partitions";
    #address-cells = <1>;
    #size-cells = <1>;

    /* ปรับ offset และ size ให้ตรงกับ mtdparts */
    partition@0 {
        label = "u-boot";
        reg = <0x00000000 0x00080000>; /* 512 KB */
        read-only;
    };
    
    /* ... partitions อื่นๆ */
};
```

### 3. LEDs

ดูจาก hardware schematic หรือ test GPIO:

```dts
leds {
    compatible = "gpio-leds";

    led_status: status {
        label = "t626pro:green:status";
        gpios = <&gpio0 10 GPIO_ACTIVE_LOW>;
        /*              ^^  ^^ GPIO number
         *              |   Active low/high
         *              GPIO controller
         */
        default-state = "on";
    };
};
```

**Test LED GPIO:**
```bash
# บน OpenWrt shell
echo 10 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio10/direction
echo 1 > /sys/class/gpio/gpio10/value    # ON
echo 0 > /sys/class/gpio/gpio10/value    # OFF
```

### 4. Buttons

```dts
keys {
    compatible = "gpio-keys";

    reset {
        label = "reset";
        gpios = <&gpio0 9 GPIO_ACTIVE_LOW>;
        linux,code = <KEY_RESTART>;
    };
};
```

**Test Button GPIO:**
```bash
# Monitor GPIO
cat /sys/kernel/debug/gpio
# กด button → ดูว่า GPIO pin ไหนเปลี่ยน
```

### 5. Ethernet Switch

EN7529 มี built-in switch - ต้อง config ports:

```dts
eth0: ethernet@1fb00000 {
    compatible = "airoha,en7523-eth";
    /* ... */
    
    mdio {
        #address-cells = <1>;
        #size-cells = <0>;
        
        /* LAN ports */
        phy0: ethernet-phy@0 {
            reg = <0>;
        };
        
        /* ... เพิ่ม phy1-4 */
    };
};
```

---

## Workflow การปรับแต่ง DTS

```
1. Boot initramfs kernel (ใช้ DTS generic)
     ↓
2. ตรวจสอบ hardware detection
   - dmesg | grep -i nand
   - cat /proc/mtd
   - ls /sys/class/net/
   - cat /sys/kernel/debug/gpio
     ↓
3. บันทึกข้อมูล (RAM, MTD, GPIO)
     ↓
4. แก้ไข DTS
     ↓
5. Rebuild kernel
     ↓
6. Test boot ใหม่
     ↓
7. Verify hardware detection ถูกต้องหมด
     ↓
8. Flash ลง NAND
```

---

## Debug DTS Issues

### Kernel Boot แต่ Hardware ไม่ถูก Detect

```bash
# ดู kernel logs
dmesg | less

# ตรวจสอบ device tree ที่ kernel ใช้จริง
ls /sys/firmware/devicetree/base/

# ดู model name
cat /sys/firmware/devicetree/base/model
# ควรเห็น: "T3 T626Pro"
```

### NAND ไม่ถูก Detect

```bash
dmesg | grep -i nand
# ควรเห็น:
# [    x.xxx] spi-nand spi0.0: ...
# [    x.xxx] Creating X MTD partitions on "..."
```

ถ้าไม่เห็น → ตรวจสอบ:
- Compatible string ถูกต้องหรือไม่
- Register address ตรงกับ SoC หรือไม่

### GPIO ไม่ทำงาน

```bash
# ดู GPIO chips
cat /sys/kernel/debug/gpio

# ลอง export manual
echo 10 > /sys/class/gpio/export
```

---

## Reference DTS Examples

ดู DTS ของบอร์ดอื่นๆ ที่ใช้ EN7523:

```bash
cd ~/openwrt-en7529/openwrt/target/linux/airoha/dts/
ls -la *.dts

# ตัวอย่าง:
# - en7523-evb.dts
# - tplink_eap615-wall-v1.dts
```

---

## Tools สำหรับ DTS

### Compile DTS เป็น DTB

```bash
# ใช้ dtc (Device Tree Compiler)
dtc -I dts -O dtb -o t3-t626pro.dtb t3-t626pro.dts
```

### Decompile DTB กลับเป็น DTS

```bash
dtc -I dtb -O dts -o extracted.dts /boot/dtb-file.dtb
```

### แสดง Device Tree ที่ Kernel ใช้

```bash
# บน running kernel
cat /sys/firmware/devicetree/base/compatible
```

---

## Next Steps

1. ✅ สร้าง basic DTS จาก template
2. ⏳ Boot initramfs + ตรวจสอบ hardware
3. ⏳ Fine-tune DTS partitions, GPIOs
4. ⏳ Test LED, buttons, ethernet
5. ⏳ Rebuild production kernel
6. ⏳ Flash และ verify ทุกอย่างทำงาน

---

**Last Updated**: November 26, 2025
