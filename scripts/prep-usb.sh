#!/usr/bin/env bash
#
# prep-usb.sh — Prepare a USB drive to flash Minisforum MS-S1 Max BIOS from EFI Shell
#
# Usage: sudo ./scripts/prep-usb.sh /dev/sdX
#
# This script will ERASE ALL DATA on the specified device.

set -euo pipefail

BIOS_URL="https://pc-file.s3.us-west-1.amazonaws.com/MS-S1+MAX/BIOS/SHWSA_1.06_260104B.7z"
BIOS_ARCHIVE="SHWSA_1.06_260104B.7z"
BIOS_DIR="SHWSA_1.06_260104B"
SHELL_URL="https://github.com/pbatard/UEFI-Shell/releases/download/24H2/ShellX64.efi"
MOUNT_POINT="/mnt/ms-s1-bios"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

die() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
info() { echo -e "${GREEN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

# --- Argument validation ---
if [[ $# -ne 1 ]]; then
    echo "Usage: sudo $0 /dev/sdX"
    echo ""
    echo "Prepares a USB drive to flash the MS-S1 Max BIOS via EFI Shell."
    echo "WARNING: All data on the target device will be erased."
    echo ""
    echo "Available USB devices:"
    lsblk -d -o NAME,SIZE,MODEL,TRAN | grep usb || echo "  (none detected)"
    exit 1
fi

DEVICE="$1"

# --- Safety checks ---
[[ $EUID -eq 0 ]] || die "This script must be run as root (use sudo)"
[[ -b "$DEVICE" ]] || die "$DEVICE is not a block device"
[[ "$DEVICE" != *"nvme"* ]] || die "Refusing to operate on NVMe device $DEVICE"
[[ "$DEVICE" != *"loop"* ]] || die "Refusing to operate on loop device $DEVICE"

TRAN=$(lsblk -nd -o TRAN "$DEVICE" 2>/dev/null || true)
if [[ "$TRAN" != "usb" ]]; then
    warn "$DEVICE does not appear to be a USB device (transport: ${TRAN:-unknown})"
    read -rp "Are you SURE you want to continue? (type YES to confirm): " confirm
    [[ "$confirm" == "YES" ]] || die "Aborted"
fi

MODEL=$(lsblk -nd -o MODEL "$DEVICE" 2>/dev/null || echo "unknown")
SIZE=$(lsblk -nd -o SIZE "$DEVICE" 2>/dev/null || echo "unknown")

echo ""
warn "This will ERASE ALL DATA on: $DEVICE ($MODEL, $SIZE)"
read -rp "Continue? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || die "Aborted"

# --- Check dependencies ---
for cmd in sgdisk mkfs.vfat wget 7z partprobe; do
    command -v "$cmd" &>/dev/null || die "Missing required command: $cmd"
done

# --- Create temp working directory ---
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"; umount "$MOUNT_POINT" 2>/dev/null || true; rmdir "$MOUNT_POINT" 2>/dev/null || true' EXIT

cd "$WORKDIR"

# --- Download files ---
info "Downloading BIOS update..."
wget -q --show-progress -O "$BIOS_ARCHIVE" "$BIOS_URL"

info "Downloading UEFI Shell..."
wget -q --show-progress -O shellx64.efi "$SHELL_URL"

info "Extracting BIOS archive..."
7z x "$BIOS_ARCHIVE" -o"$WORKDIR" -y >/dev/null

# Verify expected files exist
[[ -f "$WORKDIR/$BIOS_DIR/AfuEfix64.efi" ]] || die "AfuEfix64.efi not found in archive"
[[ -f "$WORKDIR/$BIOS_DIR/EfiFlash.nsh" ]] || die "EfiFlash.nsh not found in archive"
[[ -f "$WORKDIR/$BIOS_DIR/SHWSA.BIN" ]] || die "SHWSA.BIN not found in archive"

# --- Prepare USB drive ---
info "Wiping partition table on $DEVICE..."
sgdisk --zap-all "$DEVICE" >/dev/null 2>&1

info "Creating EFI System Partition..."
sgdisk -a1 -n1:0:0 -c 1:efiboot -t1:EF00 "$DEVICE" >/dev/null
partprobe "$DEVICE"
sleep 1

# Detect partition name (sda1 vs sda-part1 etc.)
PART="${DEVICE}1"
[[ -b "$PART" ]] || PART="${DEVICE}p1"
[[ -b "$PART" ]] || die "Cannot find partition: tried ${DEVICE}1 and ${DEVICE}p1"

info "Formatting as FAT32..."
mkfs.vfat -F32 -n "BIOS" "$PART" >/dev/null

# --- Copy files ---
mkdir -p "$MOUNT_POINT"
mount "$PART" "$MOUNT_POINT"

info "Copying BIOS flash files..."
cp "$WORKDIR/$BIOS_DIR/AfuEfix64.efi" "$MOUNT_POINT/"
cp "$WORKDIR/$BIOS_DIR/EfiFlash.nsh" "$MOUNT_POINT/"
cp "$WORKDIR/$BIOS_DIR/SHWSA.BIN" "$MOUNT_POINT/"
cp "$WORKDIR/shellx64.efi" "$MOUNT_POINT/"

sync

# --- Verify ---
info "Files on USB:"
ls -lh "$MOUNT_POINT/"

umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

echo ""
echo -e "${GREEN}USB drive is ready!${NC}"
echo ""
echo "Next steps:"
echo "  1. Plug the USB into your MS-S1 Max"
echo "  2. Press Del at boot to enter BIOS"
echo "  3. Disable Secure Boot"
echo "  4. Boot into UEFI Shell"
echo "  5. Run:  FS0:  then  EfiFlash.nsh"
echo "  6. Wait for flash + auto-reboot (first boot takes 5-10 min)"
echo ""
