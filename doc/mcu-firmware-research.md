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
- [MCU Swap Options](#mcu-swap-options)
  - [Feasibility Assessment](#feasibility-assessment)
  - [Recommended RP2040-Based Replacement Controllers](#recommended-rp2040-based-replacement-controllers)
  - [Step-by-Step MCU Swap Process](#step-by-step-mcu-swap-process)
  - [Handling Existing Features](#handling-existing-features)
  - [Preserving Hot-Swap Sockets](#preserving-hot-swap-sockets)
  - [Reference Projects](#reference-projects)
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

4. **MCU Swap** (hardware modification):
   - Keep the existing key switch sockets and case
   - Replace the CH57x MCU with an RP2040-based board
   - See [MCU Swap Options](#mcu-swap-options) section below

---

## MCU Swap Options

If you want to keep your existing keyboard's switches, case, and layout but gain full firmware control, you can perform an MCU swap. This involves removing or bypassing the CH57x chip and wiring the key matrix to a new microcontroller.

### Feasibility Assessment

| Factor | Assessment | Notes |
|--------|------------|-------|
| Difficulty | Moderate-Advanced | Requires PCB tracing, soldering skills |
| Reversibility | Low | Original MCU may be damaged or removed |
| Cost | $5-$15 | Cost of replacement MCU board |
| Time | 2-4 hours | Depending on keyboard complexity |
| Success Rate | High | If matrix is properly traced |

### Recommended RP2040-Based Replacement Controllers

#### Compact Options (Best for Small Macropads)

| Board | Size | GPIO Pins | Features | Price |
|-------|------|-----------|----------|-------|
| **Seeed XIAO RP2040** | 20x17.5mm | 11 | Tiny, USB-C, onboard RGB | ~$5 |
| **Waveshare RP2040-Zero** | 23x18mm | 20 | Reset button, USB-C | ~$4 |
| **Raspberry Pi Pico** | 51x21mm | 26 | Most GPIO, cheap | ~$4 |

#### Pro Micro Footprint (For Larger Builds)

| Board | Footprint | Features | Firmware Support |
|-------|-----------|----------|------------------|
| **Adafruit KB2040** | Pro Micro | USB-C, STEMMA QT | QMK, ZMK, RMK |
| **SparkFun Pro Micro RP2040** | Pro Micro | USB-C | QMK, ZMK |
| **Boardsource Blok** | Pro Micro | RGB LED, USB-C | QMK, ZMK |
| **Elite-Pi** | Pro Micro | USB-C | QMK, ZMK |

### Step-by-Step MCU Swap Process

#### Step 1: Trace the Key Matrix

Before any hardware changes, you must understand how keys are wired:

1. **Open the keyboard** and identify the PCB
2. **Locate the CH57x chip** (usually marked CH573 or similar)
3. **Trace connections** from each key switch to the MCU
   - Use multimeter in continuity mode
   - Create a diagram mapping rows and columns

**Typical CH57x Matrix Layouts:**

```
3x4 Keyboard (12 keys + 2 knobs):
┌─────┬─────┬─────┬─────┐
│ K1  │ K2  │ K3  │ K4  │  Row 0
├─────┼─────┼─────┼─────┤
│ K5  │ K6  │ K7  │ K8  │  Row 1
├─────┼─────┼─────┼─────┤
│ K9  │ K10 │ K11 │ K12 │  Row 2
└─────┴─────┴─────┴─────┘
 Col0  Col1  Col2  Col3

Requires: 3 row pins + 4 column pins = 7 GPIO
```

```
3x3 Keyboard (9 keys + 2 knobs):
┌─────┬─────┬─────┐
│ K1  │ K2  │ K3  │  Row 0
├─────┼─────┼─────┤
│ K4  │ K5  │ K6  │  Row 1
├─────┼─────┼─────┤
│ K7  │ K8  │ K9  │  Row 2
└─────┴─────┴─────┘
 Col0  Col1  Col2

Requires: 3 row pins + 3 column pins = 6 GPIO
```

#### Step 2: Document Pin Mapping

Create a mapping table:

```
CH57x Pin | Function    | New RP2040 Pin
----------|-------------|---------------
PA0       | Row 0       | GP0
PA1       | Row 1       | GP1
PA2       | Row 2       | GP2
PB0       | Col 0       | GP3
PB1       | Col 1       | GP4
PB2       | Col 2       | GP5
PB3       | Col 3       | GP6
PC0       | Encoder A   | GP7
PC1       | Encoder B   | GP8
PC2       | Encoder SW  | GP9
```

#### Step 3: Hardware Modification Options

**Option A: Direct Wire (Recommended for beginners)**

1. Leave CH57x in place but cut its traces
2. Solder wires from matrix pads to RP2040 GPIO
3. Power RP2040 from USB independently

**Option B: Replace CH57x (Clean but advanced)**

1. Desolder/remove CH57x chip with hot air
2. Identify power/ground pads
3. Wire RP2040 to existing matrix traces
4. May require trace cutting and jumper wires

**Option C: Piggyback (Non-destructive)**

1. Disable CH57x by cutting its USB data lines
2. Tap into matrix with parallel connections
3. Both MCUs can remain, but only RP2040 active

#### Step 4: Wiring Diagram Example

For a 3x4 matrix with 2 rotary encoders using XIAO RP2040:

```
XIAO RP2040          Key Matrix
┌────────────┐       ┌─────────────────┐
│ GP0 (D0)   ├───────┤ Row 0           │
│ GP1 (D1)   ├───────┤ Row 1           │
│ GP2 (D2)   ├───────┤ Row 2           │
│ GP3 (D3)   ├───────┤ Col 0           │
│ GP4 (D4)   ├───────┤ Col 1           │
│ GP5 (D5)   ├───────┤ Col 2           │
│ GP6 (D6)   ├───────┤ Col 3           │
│ GP7 (D7)   ├───────┤ Encoder 1 A     │
│ GP8 (D8)   ├───────┤ Encoder 1 B     │
│ GP9 (D9)   ├───────┤ Encoder 1 Switch│
│ GP10 (D10) ├───────┤ Encoder 2 A     │
│ 3.3V       ├───────┤ VCC (if needed) │
│ GND        ├───────┤ GND             │
└────────────┘       └─────────────────┘
```

#### Step 5: Firmware Configuration

**QMK Configuration Example:**

```c
// config.h
#define MATRIX_ROWS 3
#define MATRIX_COLS 4

#define MATRIX_ROW_PINS { GP0, GP1, GP2 }
#define MATRIX_COL_PINS { GP3, GP4, GP5, GP6 }

#define ENCODERS_PAD_A { GP7, GP10 }
#define ENCODERS_PAD_B { GP8, GP11 }

#define DIODE_DIRECTION COL2ROW
```

**KMK (CircuitPython) Example:**

```python
# main.py
import board
from kmk.kmk_keyboard import KMKKeyboard
from kmk.scanners import DiodeOrientation

keyboard = KMKKeyboard()

keyboard.col_pins = (board.GP3, board.GP4, board.GP5, board.GP6)
keyboard.row_pins = (board.GP0, board.GP1, board.GP2)
keyboard.diode_orientation = DiodeOrientation.COL2ROW

keyboard.keymap = [
    [KC.A, KC.B, KC.C, KC.D,
     KC.E, KC.F, KC.G, KC.H,
     KC.I, KC.J, KC.K, KC.L]
]
```

**RMK (Rust) Example:**

```rust
// keyboard.rs
use rmk::config::{KeyboardConfig, MatrixConfig};

let config = KeyboardConfig {
    matrix: MatrixConfig {
        rows: [Pin::new(0), Pin::new(1), Pin::new(2)],
        cols: [Pin::new(3), Pin::new(4), Pin::new(5), Pin::new(6)],
        diode_direction: DiodeDirection::Col2Row,
    },
    ..Default::default()
};
```

### Handling Existing Features

#### Rotary Encoders

Most CH57x keyboards have 1-2 rotary encoders:
- Encoders use 2 pins for rotation (A/B) + 1 for push button
- Connect to RP2040 GPIO with internal pull-ups enabled
- QMK/KMK/RMK all support encoders natively

#### LEDs (RGB Underglow)

If your keyboard has LEDs:
- WS2812/SK6812: Single data pin to any GPIO
- Individual LEDs: May need transistor drivers
- Configure in firmware (e.g., QMK's `RGB_MATRIX_ENABLE`)

#### Layer Switch Button

The physical layer button on CH57x keyboards:
- Can be repurposed as a function/layer key
- Wire to a GPIO and configure in keymap

### Preserving Hot-Swap Sockets

The existing Kailh/Gateron hot-swap sockets remain fully usable:

1. **Do not desolder the sockets** - they're the most valuable part
2. **Trace from socket pads** to matrix connections
3. **Test continuity** before and after modification
4. Switches will work identically after MCU swap

### Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| No keys register | Wrong diode direction | Swap `COL2ROW` ↔ `ROW2COL` |
| Some keys don't work | Missed trace connection | Re-check continuity |
| Multiple keys trigger | Missing diodes | Add 1N4148 diodes |
| Encoder skips | Missing pull-ups | Enable internal pull-ups |
| USB not detected | Power issue | Check 5V/GND connections |

### Reference Projects

- **MacroBoard**: 9-key XIAO RP2040 macropad with KMK
  - GitHub: https://github.com/palmacas/MacroBoard
- **QMK RP2040 Guide**: Official documentation
  - https://docs.qmk.fm/platformdev_rp2040
- **Hand Wiring Guide**: QMK hand-wiring tutorial
  - https://docs.qmk.fm/hand_wire
- **KB2040 Keyboard Build**: Adafruit tutorial
  - https://learn.adafruit.com/using-qmk-on-rp2040-microcontrollers

### Cost-Benefit Analysis

| Approach | Cost | Effort | Firmware Freedom | Risk |
|----------|------|--------|------------------|------|
| Keep CH57x + this tool | $0 | None | Limited | None |
| MCU Swap (XIAO) | ~$5 | Medium | Full | Low-Med |
| MCU Swap (KB2040) | ~$9 | Medium | Full | Low-Med |
| Buy new RP2040 macropad | $30-60 | None | Full | None |
| Build from scratch | $40-80 | High | Full | None |

**Recommendation**: If you're comfortable with soldering and want to maximize your existing keyboard, an MCU swap with a XIAO RP2040 or similar provides the best value. The existing hot-swap sockets, case, and switches are worth preserving.

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
