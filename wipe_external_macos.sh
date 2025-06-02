#!/bin/bash

################################################################################
# Script: wipe_external_macos.sh
# Purpose: Securely wipe all externally connected removable storage devices on macOS
#
# Usage:
#   1. Save as wipe_external_macos.sh
#   2. Make executable: chmod +x wipe_external_macos.sh
#   3. Run with root privileges: sudo ./wipe_external_macos.sh
#
# What it does:
#   - Detects external (non-internal) disks via diskutil
#   - Confirms before wiping each drive
#   - Unmounts volumes on the disk
#   - Uses dd to overwrite disk with random data and zeros
#
# Notes:
#   - Targets *external* disks only
#   - Wiping is destructive — confirm before running
################################################################################

# Must be run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

echo "=== Secure wipe of all external storage devices (macOS) ==="

# Get all external disks (excluding internal system drives)
EXTERNAL_DISKS=$(diskutil list external physical | grep "^/dev/" | awk '{print $1}')

# Exit if no external drives are found
if [ -z "$EXTERNAL_DISKS" ]; then
    echo "No external drives detected. Exiting..."
    exit 0
fi

# Iterate over each detected external disk
for DRIVE in $EXTERNAL_DISKS; do
    echo ""
    echo ">>> Detected device: $DRIVE"

    read -p "Are you sure you want to wipe $DRIVE? Type YES to confirm: " CONFIRM
    if [ "$CONFIRM" != "YES" ]; then
        echo "Skipping $DRIVE"
        continue
    fi

    echo "  Unmounting $DRIVE ..."
    if ! diskutil unmountDisk "$DRIVE"; then
        echo "  Error: Failed to unmount $DRIVE. Skipping."
        continue
    fi

    echo "  Overwriting $DRIVE with random data (1 pass)..."
    if ! dd if=/dev/urandom of="$DRIVE" bs=1m status=progress; then
        echo "  Error: dd random pass failed on $DRIVE. Skipping."
        continue
    fi

    echo "  Overwriting $DRIVE with zeros (final pass)..."
    if ! dd if=/dev/zero of="$DRIVE" bs=1m status=progress; then
        echo "  Error: dd zero pass failed on $DRIVE."
        continue
    fi

    echo ">>> Wipe complete for $DRIVE"
done

echo ""
echo "=== All confirmed external drives wiped ==="
