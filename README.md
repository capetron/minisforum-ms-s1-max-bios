# Minisforum MS-S1 Max BIOS Update from Linux (No Windows Required)

Update the BIOS/UEFI firmware on your **Minisforum MS-S1 Max** mini PC directly from Linux — no Windows installation, no VM, no dual boot needed. This guide uses the built-in **EFI Shell** to flash the BIOS using Minisforum's official firmware files.

The MS-S1 Max (AMD Ryzen AI Max+ 395 / Strix Halo) is a popular choice for AI workstations, homelabs, and NixOS/Linux servers, but Minisforum only provides Windows-based BIOS update tools. This guide solves that problem.

## Why Update the BIOS?

- **Stability fixes** for memory, NVMe, and USB4 V2
- **Performance improvements** for AI and compute workloads
- **Security patches** for AMD Platform Security Processor (PSP) and UEFI vulnerabilities
- **Compatibility** with newer Linux kernels, NixOS, and virtualization features

## Requirements

- A **USB flash drive** (512 MB or larger)
- A Linux machine to prepare the USB (can be the MS-S1 Max itself, or any other box)
- The BIOS update file from Minisforum (linked below)
- `7z` (p7zip) for extraction
- `sgdisk` (from `gptfdisk` package) for partitioning

## Quick Start (Automated)

Use the included script to prepare the USB drive in one command:

```bash
git clone https://github.com/capetron/minisforum-ms-s1-max-bios.git
cd minisforum-ms-s1-max-bios
sudo ./scripts/prep-usb.sh /dev/sdX   # Replace sdX with your USB device!
```

> **WARNING:** Double-check your device path with `lsblk` before running. This script will **erase all data** on the target drive.

## Manual Step-by-Step Guide

### Step 1: Download the BIOS Update

Download the latest BIOS from Minisforum's support page:

| Version | Date | Download | Notes |
|---------|------|----------|-------|
| 1.06 | 2026-01-04 | [SHWSA_1.06_260104B.7z](https://pc-file.s3.us-west-1.amazonaws.com/MS-S1+MAX/BIOS/SHWSA_1.06_260104B.7z) | Latest available |

```bash
mkdir -p ~/ms-s1-bios && cd ~/ms-s1-bios
wget -O SHWSA_1.06.7z "https://pc-file.s3.us-west-1.amazonaws.com/MS-S1+MAX/BIOS/SHWSA_1.06_260104B.7z"
```

### Step 2: Download the UEFI Shell

The EFI Shell lets you boot into a command-line environment that can flash the BIOS without any operating system.

```bash
wget -O shellx64.efi "https://github.com/pbatard/UEFI-Shell/releases/download/24H2/ShellX64.efi"
```

### Step 3: Prepare the USB Drive

Identify your USB device (be careful — wrong device = data loss!):

```bash
lsblk -d -o NAME,SIZE,MODEL,TRAN
```

Install dependencies if needed:

```bash
# Arch / CachyOS / Manjaro
sudo pacman -S gptfdisk dosfstools p7zip

# Ubuntu / Debian
sudo apt install gdisk dosfstools p7zip-full

# Fedora
sudo dnf install gdisk dosfstools p7zip

# NixOS (temporary shell)
nix-shell -p gptfdisk dosfstools p7zip
```

Partition and format the USB (replace `/dev/sdX` with your device):

```bash
# Wipe existing partition table
sudo sgdisk --zap-all /dev/sdX

# Create a single EFI System Partition
sudo sgdisk -a1 -n1:0:0 -c 1:efiboot -t1:EF00 /dev/sdX
sudo partprobe /dev/sdX

# Format as FAT32
sudo mkfs.vfat -F32 -n "BIOS" /dev/sdX1
```

### Step 4: Copy Files to the USB

```bash
# Mount the USB
sudo mount /dev/sdX1 /mnt

# Extract BIOS files
7z x SHWSA_1.06.7z -o/tmp/bios-extract/
sudo cp /tmp/bios-extract/SHWSA_1.06_260104B/AfuEfix64.efi /mnt/
sudo cp /tmp/bios-extract/SHWSA_1.06_260104B/EfiFlash.nsh /mnt/
sudo cp /tmp/bios-extract/SHWSA_1.06_260104B/SHWSA.BIN /mnt/

# Copy the EFI Shell
sudo cp shellx64.efi /mnt/

# Verify
ls -la /mnt/
# Should show: AfuEfix64.efi  EfiFlash.nsh  shellx64.efi  SHWSA.BIN

# Unmount
sudo sync
sudo umount /mnt
```

### Step 5: Boot into UEFI Shell on the MS-S1 Max

1. **Plug the USB** into the MS-S1 Max
2. **Power on** and press **Del** repeatedly to enter BIOS Setup
3. **Disable Secure Boot:**
   - You may need to set an Administrator password first (Security menu)
   - Navigate to Secure Boot settings and set it to **Disabled**
   - Save and exit BIOS
4. **Re-enter BIOS** (press Del again)
5. Look for **"UEFI Shell"** or **"Launch EFI Shell from filesystem device"** in the boot menu
   - If not available, go to Boot menu → Add Boot Option → point to `shellx64.efi` on the USB
6. **Boot into the UEFI Shell**

### Step 6: Flash the BIOS

At the `Shell>` prompt:

```
FS0:
dir
```

If you see your files (`AfuEfix64.efi`, `EfiFlash.nsh`, `SHWSA.BIN`), run:

```
EfiFlash.nsh
```

If `FS0:` doesn't show your files, try `FS1:`, `FS2:`, etc.

The flash process will:
1. Write the new BIOS image
2. Automatically shut down or reboot the system
3. Enter BIOS setup briefly to finalize the update

### Step 7: First Boot After Update

> **Don't panic!** The first boot after a BIOS update takes **5–10 minutes** while the system performs memory training. You may see a black screen or several reboots — this is completely normal.

After the first boot completes:
- All BIOS settings will be **reset to defaults**
- Re-enter BIOS (Del key) to verify the new version and adjust settings
- Re-enable Secure Boot if desired
- Check boot order — your Linux installation should still be there

## Troubleshooting

### "Access Denied" or EFI Shell won't launch
Secure Boot is probably still enabled. Disable it in BIOS → Security → Secure Boot.

### Can't find files in EFI Shell
The USB may be on a different filesystem mapping. Try all `FSx:` entries:
```
map -c
FS0:
dir
FS1:
dir
```

### System won't boot after flashing
- Wait at least 10 minutes — memory training can take a while, especially with 128 GB LPDDR5X
- If still no boot after 15 minutes, try a CMOS reset (unplug power, remove CMOS battery for 30 seconds)

### NixOS boot entry disappeared
The boot entry is stored in NVRAM which survives BIOS updates. If it's missing, re-add it from a NixOS live USB:
```bash
sudo nixos-rebuild boot
```
Or manually add a boot entry in BIOS pointing to `\EFI\systemd\systemd-bootx64.efi` or `\EFI\BOOT\BOOTX64.EFI`.

## MS-S1 Max Specifications

| Component | Specification |
|-----------|--------------|
| **CPU** | AMD Ryzen AI Max+ 395 (Strix Halo) — 16C/32T, Zen 5, up to 5.1 GHz |
| **RAM** | 128 GB LPDDR5X-8000 (soldered) |
| **GPU** | Radeon 8060S — 40 CUs, RDNA 3.5 (up to 96 GB shared VRAM) |
| **AI** | 126 TOPS total / 50 TOPS NPU |
| **TDP** | 160 W configurable |
| **Networking** | Dual 10 GbE, WiFi 7, Bluetooth 5.4 |
| **Connectivity** | 2x USB4, 2x USB4 V2, HDMI |
| **Storage** | 2 TB NVMe SSD (expandable) |

## What's in the BIOS Package

| File | Purpose |
|------|---------|
| `AfuEfix64.efi` | AMI Firmware Update utility for EFI Shell |
| `EfiFlash.nsh` | Automated flash script (calls AfuEfix64 with correct flags) |
| `SHWSA.BIN` | The actual BIOS/UEFI firmware image (33 MB) |
| `AFUWINx64.EXE` | Windows flash tool (not needed for this guide) |
| `WinFlash.bat` | Windows flash script (not needed for this guide) |
| `shellx64.efi` | UEFI Shell binary (added by this guide) |

## How It Works

Minisforum ships BIOS updates with Windows-only tools (`AFUWINx64.EXE`), but the package also includes `AfuEfix64.efi` — AMI's EFI-native flash utility. Modern UEFI firmware includes a built-in EFI Shell environment that runs before any OS loads. Since the flash tool is a native EFI application, it has direct hardware access to the SPI flash chip. No operating system is needed at all.

The `EfiFlash.nsh` script simply calls:
```
AfuEfix64.efi SHWSA.bin /p /b /n /k /r /capsule /q
```

| Flag | Meaning |
|------|---------|
| `/p` | Program main BIOS area |
| `/b` | Program boot block |
| `/n` | Program NVRAM |
| `/k` | Preserve keys |
| `/r` | Preserve SMBIOS data |
| `/capsule` | Use capsule update method |
| `/q` | Quiet/silent mode |

## Related Resources

- [Minisforum MS-S1 Max Product Page](https://www.minisforum.com/products/ms-s1-max)
- [Minisforum Support Center](https://www.minisforum.com/pages/support-center)
- [pbatard/UEFI-Shell Releases](https://github.com/pbatard/UEFI-Shell/releases) — Pre-built EFI Shell binaries
- [Blog: How to Update Your MS-S1 Max BIOS for AI Workloads](https://www.petronellatech.com/blog/technology/minisforum-ms-s1-max-bios-update-linux/) — Extended guide from Petronella Technology Group

## Contributing

Found a newer BIOS version? Have tips for other Minisforum models? PRs and issues welcome.

## License

MIT

---

*Guide by [Petronella Technology Group](https://www.petronellatech.com) — IT consulting and AI infrastructure for businesses since 2002.*
