#!/bin/bash

################################################################################
# Script: wipe_external.sh
# Purpose: Securely wipe all externally connected removable storage devices (USB, SD cards, etc.)
#
# Usage:
#   1. Save this script as wipe_external.sh
#   2. Make executable: chmod +x wipe_external.sh
#   3. Run with root privileges: sudo ./wipe_external.sh
#
# What it does:
#   - Detects all removable drives
#   - For each drive, prompts the user to type YES to confirm wiping
#   - Unmounts any mounted partitions on the device
#   - Runs wipefs to clear filesystem signatures
#   - Runs shred with 3 random passes plus a final zero pass for secure erase
#
# Notes:
#   - Targets only removable drives (RM=1)
#   - Avoids wiping internal drives (NVMe, SATA without RM=1)
#   - Interactive confirmation prevents accidental wipes
################################################################################

# Must be run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Ensure required tools are installed
for cmd in lsblk umount wipefs shred; do
    if ! command -v $cmd &> /dev/null; then
        echo "$cmd is required but not installed. Installing..."
        apt update && apt install -y $cmd || { echo "Failed to install $cmd. Exiting."; exit 1; }
    fi
done

echo "=== Secure wipe of all external storage devices ==="

# Detect removable drives by RM flag, remove partition numbers, get unique devices
USB_DRIVES=$(lsblk -o NAME,RM -nr | awk '$2 == 1 { print "/dev/" $1 }' | sed 's/[0-9]*$//' | sort -u)

# Exit if no removable drives found
if [ -z "$USB_DRIVES" ]; then
    echo "No removable external drives detected. Exiting..."
    exit 0
fi

# Loop through each detected device
for DRIVE in $USB_DRIVES; do
    echo ""
    echo ">>> Detected device: $DRIVE"

    # Prompt for confirmation
    read -p "Are you sure you want to wipe $DRIVE? Type YES to confirm: " CONFIRM
    if [ "$CONFIRM" != "YES" ]; then
        echo "Skipping $DRIVE"
        continue
    fi

    # Identify and unmount mounted partitions
    MOUNTED_PARTS=$(lsblk -nr -o NAME,MOUNTPOINT "$DRIVE" | awk '$2!="" {print $1}')
    for PART in $MOUNTED_PARTS; do
        echo "  Unmounting /dev/$PART ..."
        if ! umount "/dev/$PART"; then
            echo "  Error: Failed to unmount /dev/$PART. Skipping $DRIVE."
            continue 2  # Skip to next drive
        fi
    done

    # Clear filesystem signatures
    echo "  Running wipefs ..."
    if ! wipefs -a "$DRIVE"; then
        echo "  Warning: wipefs failed on $DRIVE, continuing with shred."
    fi

    # Overwrite data securely
    echo "  Running shred (3 passes + final zero pass)..."
    if ! shred -vzn 3 "$DRIVE"; then
        echo "  Error: shred failed on $DRIVE. Aborting."
        exit 1
    fi

    echo ">>> Wipe complete for $DRIVE"
done

echo ""
echo "=== All confirmed external drives wiped ==="
