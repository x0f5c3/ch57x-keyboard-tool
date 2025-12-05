# CH57x Macro Keyboard MCU Firmware Research

## Table of Contents

- [Overview](#overview)
- [How ch57x-keyboard-tool Works](#how-ch57x-keyboard-tool-works)
  - [USB Communication Protocol](#usb-communication-protocol)
  - [Message Format](#message-format)
  - [Key Binding Protocol](#key-binding-protocol)
- [CH57x MCU Architecture](#ch57x-mcu-architecture)
  - [Hardware Specifications](#hardware-specifications)
  - [Memory Layout](#memory-layout)
  - [Bootloader](#bootloader)
- [Accessing the Underlying MCU](#accessing-the-underlying-mcu)
  - [Current Access Level](#current-access-level)
  - [Bootloader/ISP Mode Access](#bootloaderisp-mode-access)
  - [Hardware Modifications](#hardware-modifications)
- [Custom Firmware Options](#custom-firmware-options)
  - [RMK Firmware Analysis](#rmk-firmware-analysis)
  - [QMK/ZMK Compatibility](#qmkzmk-compatibility)
  - [Custom Firmware Development](#custom-firmware-development)
- [Technical Limitations](#technical-limitations)
- [Recommendations](#recommendations)
- [References](#references)

---

## Overview

This document provides research findings on how the `ch57x-keyboard-tool` interacts with CH57x-based macro keyboards and explores possibilities for accessing the underlying MCU to reprogram it with alternative firmware like RMK (Rust Mechanical Keyboard firmware).

**Key Finding**: The current tool operates at the **application layer** of the keyboard's firmware, not at the MCU flashing level. It communicates with the existing factory firmware to update key mappings stored in flash/EEPROM, but does **not** replace the core firmware itself.

---

## How ch57x-keyboard-tool Works

### USB Communication Protocol

The tool communicates with the keyboard using USB HID (Human Interface Device) interrupt transfers:

1. **Device Discovery**:
   - Scans for USB devices with Vendor ID `0x1189` (Trisat Industrial Co., Ltd.)
   - Supports Product IDs: `0x8840`, `0x8842`, `0x8890`, `0x8850`
   
2. **Interface Detection**:
   - Locates the HID interface (class code `0x03`)
   - Finds interrupt endpoints for communication
   - Preferred endpoints: `0x04` for 884x devices, `0x02` for 8890 devices

3. **Protocol Initialization**:
   ```
   Send 64 zero bytes to initialize communication
   ```

### Message Format

All messages are 64 bytes, padded with zeros:

```
[Header][Command][Payload...][Padding...]
└──────────────────────────────────────┘
                64 bytes
```

**Common header**: `0x03` prefix for most commands

### Key Binding Protocol

#### For k884x keyboards (0x8840, 0x8842, 0x8850):

```
Bind key message:
03 FE [key_id] [layer+1] [macro_type] 00 00 00 00 00 [payload...]

Key finish sequence:
03 AA AA 00 00 00 00 00 00
03 FD FE FF 00 00 00 00 00
03 AA AA 00 00 00 00 00 00
```

**Macro types**:
- `0x01` = Keyboard macro
- `0x02` = Media key
- `0x03` = Mouse action

#### For k8890 keyboards (0x8890):

```
Bind start:
03 FE [layer+1] 01 01 00 00 00 00

Bind key:
03 [key_id] [(layer+1)<<4|type] [length] [index] [modifiers] [code] 00 00

Bind finish:
03 AA AA 00 00 00 00 00 00
```

---

## CH57x MCU Architecture

### Hardware Specifications

The CH57x family (CH571, CH573, CH579) from WCH (Nanjing Qinheng Microelectronics) includes:

| Feature | CH579 | CH573 | CH571 |
|---------|-------|-------|-------|
| Core | ARM Cortex-M0 @ 40MHz | RISC-V | RISC-V |
| Flash | 250KB CodeFlash | ~160-256KB | ~256KB |
| SRAM | 32KB | ~18KB | ~18KB |
| Bootloader | 4KB factory | 4KB factory | 4KB factory |
| USB | Full-speed (12Mbps) | Full-speed | Full-speed |
| Bluetooth | BLE 4.2 | BLE 5.0 | BLE 5.0 |

### Memory Layout

```
┌──────────────────────┬─────────────────────────────┐
│    Address Range     │         Purpose             │
├──────────────────────┼─────────────────────────────┤
│ 0x0000_0000 - 0x0FFF │ Factory Bootloader (4KB)    │
│ 0x0000_1000 - xxxxx  │ Application Firmware        │
│ (Upper flash)        │ User Config/Keymap Data     │
│ (DataFlash 2KB)      │ Persistent Settings         │
├──────────────────────┼─────────────────────────────┤
│ 0x2000_0000+         │ SRAM                        │
└──────────────────────┴─────────────────────────────┘
```

### Bootloader

The CH57x chips have a **factory-programmed ISP bootloader** that allows firmware updates via:

1. **USB**: Device appears as `WinChipHead` when in bootloader mode
2. **UART**: Serial programming interface

**Entering ISP/Bootloader Mode**:
- Hold specific GPIO pin low (typically PB22 on CH579/CH573) during power-up
- Some keyboards may have a hidden button/pad for this
- ISP mode is active for ~5 seconds after power-on/reset

---

## Accessing the Underlying MCU

### Current Access Level

The `ch57x-keyboard-tool` provides **configuration-level access only**:

```
┌─────────────────────────────────────────────────────────────┐
│                    Access Hierarchy                          │
├─────────────────────────────────────────────────────────────┤
│ Level 4: User Configuration (YAML mappings) ◀── THIS TOOL  │
│ Level 3: USB HID Protocol (key bindings)    ◀── THIS TOOL  │
│ Level 2: Application Firmware (factory ROM)                 │
│ Level 1: Bootloader (factory ISP)                           │
│ Level 0: Hardware (MCU silicon)                             │
└─────────────────────────────────────────────────────────────┘
```

**What the tool CAN do**:
- Update key/macro mappings stored in configuration flash
- Control LED modes
- Read keyboard parameters

**What the tool CANNOT do**:
- Access bootloader mode
- Flash new firmware
- Read/write arbitrary flash memory
- Modify the core keyboard firmware

### Bootloader/ISP Mode Access

To access the MCU for firmware replacement, you need to:

1. **Identify ISP Entry Method**:
   - Look for physical buttons/pads on PCB labeled "BOOT", "DL", "ISP"
   - Measure GPIO pins to find boot mode pin (often PB22)
   - Try holding specific key during USB plug-in

2. **Use ISP Tools**:
   - **WCHISPTool** (Windows): Official WCH programming tool
   - **wchisp** (Rust): https://github.com/ch32-rs/wchisp
   - **chprog** (Python): `pip install chprog`
   - **isp55e0**: https://github.com/frank-zago/isp55e0

3. **USB Device Recognition**:
   ```bash
   # In normal mode:
   lsusb
   # Bus xxx Device xxx ID 1189:8890 ...
   
   # In ISP/bootloader mode:
   lsusb
   # Bus xxx Device xxx ID 4348:55e0 WinChipHead
   ```

### Hardware Modifications

For keyboards without accessible ISP buttons:

1. **Identify ISP Pin**: 
   - Open keyboard, locate MCU chip
   - Find PB22 or designated boot pin from datasheet
   - May need to trace from test pads

2. **Create ISP Connection**:
   ```
   Method A: Temporary jumper
   - Short ISP pin to GND during power-up
   
   Method B: Add switch
   - Solder small button between ISP pin and GND
   
   Method C: Serial programming
   - Connect UART TX/RX to chip's UART pins
   - Use serial bootloader protocol
   ```

---

## Custom Firmware Options

### RMK Firmware Analysis

[RMK](https://github.com/HaoboGu/rmk) is a Rust keyboard firmware supporting:
- STM32 (F0, F1, F3, F4, L4, H7)
- nRF52 series
- RP2040 (Raspberry Pi Pico)
- ESP32

**CH57x Compatibility Assessment**:

| Requirement | CH57x Status | Notes |
|-------------|--------------|-------|
| Rust HAL | ❌ No official HAL | Would need community development |
| Embassy support | ❌ Not available | Embassy powers RMK's async runtime |
| USB stack | ⚠️ Partial | CH57x USB different from embassy-usb |
| BLE stack | ⚠️ Complex | Proprietary BLE stack required |

**Conclusion**: RMK is **not compatible** with CH57x without significant porting work.

### QMK/ZMK Compatibility

| Firmware | Language | CH57x Support |
|----------|----------|---------------|
| QMK | C | ❌ No CH57x port |
| ZMK | Zephyr C | ❌ No CH57x board |
| KMK | Python | ❌ Requires CircuitPython |

**None of the major open-source keyboard firmwares support CH57x chips natively.**

### Custom Firmware Development

To create custom firmware for CH57x keyboards:

1. **Development Environment**:
   ```
   # For ARM Cortex-M0 variants (CH579):
   - ARM GCC toolchain
   - WCH EVT (Evaluation package)
   
   # For RISC-V variants (CH573/CH571):
   - MounRiver Studio (WCH's IDE)
   - riscv-gcc
   ```

2. **Required Components**:
   - USB HID device stack
   - Key matrix scanning
   - Debounce logic
   - Layer management
   - LED control
   - (Optional) BLE stack

3. **Reference Resources**:
   - WCH EVT examples: https://www.wch.cn/downloads/CH573EVT_ZIP.html
   - Community CH57x Rust: https://github.com/ch32-rs (limited)

---

## Technical Limitations

### Why Direct Firmware Replacement is Difficult

1. **Proprietary Protocol**: 
   - The USB communication uses a proprietary protocol for configuration only
   - No documented firmware update protocol exposed

2. **Bootloader Protection**:
   - Factory bootloader may be protected
   - Flash write protection in normal operation

3. **No HAL Support**:
   - Unlike RP2040 or STM32, CH57x lacks community HAL libraries
   - Makes Rust firmware development impractical

4. **BLE Complexity**:
   - Wireless variants require BLE stack
   - WCH's BLE stack is closed-source binary blob

5. **Hardware Access**:
   - No standard ISP header on most keyboards
   - Requires PCB modification for bootloader access

### What This Tool Reveals

The USB protocol implementation in this tool shows:

```rust
// Key binding uses high-level commands
// Not raw flash programming
pub fn bind_key(&self, layer: u8, key: Key, expansion: &Macro) -> Result<()>

// LED control similarly abstracted
pub fn set_led(&mut self, args: &[String]) -> Result<()>
```

The keyboard's factory firmware **interprets these commands** and stores configurations internally. We don't have direct memory access.

---

## Recommendations

### For Maximum Customization Within Current Limits

1. **Use this tool** for key mapping - it provides extensive customization:
   - Multi-key sequences (up to 5-18 keys depending on model)
   - Mouse actions (click, drag, move, scroll)
   - Media keys
   - Modifier combinations
   - 3 layer support

2. **Combine with automation tools**:
   - Assign unusual key combinations (e.g., F13-F24)
   - Use AutoHotkey (Windows) or Hammerspoon (macOS) for complex actions

### For Full Firmware Control

If you need **complete firmware control**, consider:

1. **Alternative Hardware** (recommended):
   - RP2040-based pads (Raspberry Pi Pico, KB2040)
   - Pro Micro compatible boards (ATmega32U4)
   - Nice!Nano (nRF52840) for wireless
   
   These support QMK/ZMK/RMK out of the box.

2. **CH57x Custom Development** (advanced):
   - Access bootloader via ISP pin
   - Develop firmware using WCH EVT
   - Replace factory firmware entirely
   - **Risk**: May brick device if done incorrectly

3. **Hybrid Approach**:
   - Keep CH57x keyboard for daily use with this tool
   - Build a second keyboard for experimentation

---

## References

### Official Resources
- [WCH CH573 Datasheet](https://www.wch-ic.com/downloads/CH573DS1_PDF.html)
- [WCH CH579 Datasheet](https://www.wch-ic.com/downloads/CH579DS1_PDF.html)
- [WCH EVT Packages](https://www.wch.cn/downloads/category/33.html)
- [WCHISPTool](http://www.wch.cn/downloads/WCHISPTool_Setup_exe.html)

### Community Tools
- [wchisp (Rust)](https://github.com/ch32-rs/wchisp) - Cross-platform ISP programmer
- [isp55e0](https://github.com/frank-zago/isp55e0) - Linux ISP flasher
- [chprog](https://pypi.org/project/chprog/) - Python programming tool

### Keyboard Firmware Projects
- [RMK](https://github.com/HaoboGu/rmk) - Rust keyboard firmware
- [QMK](https://qmk.fm/) - Popular keyboard firmware
- [ZMK](https://zmk.dev/) - Zephyr-based keyboard firmware

### Related Projects
- [ch57x-keyboard-tool](https://github.com/kriomant/ch57x-keyboard-tool) - This project
- [ch57x-keyboard-mapper](https://github.com/achushu/CH57x-keyboard-mapper) - Alternative mapper
- [ch57x-macro-keyboard-tool](https://github.com/dfaker/ch57x-macro-keyboard-tool) - Python version

---

## Appendix: USB Protocol Details

### Captured Command Structures

#### k884x Key Binding
```
Offset: 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D ...
Header: 03 FE [K] [L] [T] 00 00 00 00 00 [len] [mods] [code] ...

K = Key ID (1-24 for buttons, 16+ for knobs)
L = Layer + 1 (1-3 for layers 0-2)
T = Type (1=keyboard, 2=media, 3=mouse)
```

#### k884x LED Control
```
03 FE B0 [L] 08 00 05 01 00 [mode] 00 34

L = Layer + 1
mode = (color << 4) | effect
  effect: 0=off, 1=backlight, 2=shock, 3=shock2, 4=press, 5=white
  color: 0=white, 1=red, 2=orange, 3=yellow, 4=green, 5=cyan, 6=blue, 7=purple
```

#### k8890 Key Binding
```
Start:  03 FE [L] 01 01 00 00 00 00
Bind:   03 [K] [L<<4|T] [len] [idx] [mods] [code] 00 00
Finish: 03 AA AA 00 00 00 00 00 00
```

---

*Document Version: 1.0*
*Last Updated: December 2024*
