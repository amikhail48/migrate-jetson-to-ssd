#!/bin/bash
set -e
set -u

# --- CONFIG ---
TARGET_MOUNT="/opt/py-memo"
DEFAULT_DRIVE="/dev/nvme0n1"
DRIVE=$DEFAULT_DRIVE
TEMP_MOUNT="/mnt/ssd_root_tmp"

# --- HELP / ARGS ---
while getopts "d:" opt; do
  case ${opt} in
    d ) DRIVE=$OPTARG ;;
    * ) echo "Usage: $0 [-d /dev/device]"; exit 1 ;;
  esac
done

if [ "$EUID" -ne 0 ]; then 
  echo "❌ Error: Please run as root (sudo)"; exit 1
fi

# Determine who the actual human is
REAL_USER=${SUDO_USER:-$USER}
USER_ID=$(id -u "$REAL_USER")
GROUP_ID=$(id -g "$REAL_USER")

echo "--- 🛠️  Data Partitioning: Targeting $DRIVE from SD Card ---"

# 1. Check for unallocated space
FREE_SPACE=$(sgdisk -p "$DRIVE" | grep "Total free space is" | awk '{print $5}') || true
if [ -z "$FREE_SPACE" ] || [ "$FREE_SPACE" -lt 2048 ]; then
    echo "❌ Error: No significant unallocated space found on $DRIVE."
    exit 1
fi

# 2. Create the new partition
echo "Creating new data partition..."
sgdisk -n 0:0:0 -t 0:8300 -c 0:"PYMEMO_DATA" "$DRIVE"
partprobe "$DRIVE"
sleep 2dentify the new partition device
NEW_PART_NUM=$(sgdisk -p "$DRIVE" | grep "^ " | awk '{print $1}' | sort -n | tail -1)
if [[ "$DRIVE" == *"nvme"* ]]; then
    NEW_PART_DEV="${DRIVE}p${NEW_PART_NUM}"
    SSD_ROOT_DEV="${DRIVE}p1"
else
    NEW_PART_DEV="${DRIVE}${NEW_PART_NUM}"
    SSD_ROOT_DEV="${DRIVE}1"
fi

# 4. Format the new partition
echo "Formatting $NEW_PART_DEV (EXT4)..."
mkfs.ext4 -F "$NEW_PART_DEV"
UUID_DATA=$(blkid -s UUID -o value "$NEW_PART_DEV")

# 5. Modify the SSD's Filesystem
echo "Mounting SSD root ($SSD_ROOT_DEV) to configure fstab..."
mkdir -p "$TEMP_MOUNT"
mount "$SSD_ROOT_DEV" "$TEMP_MOUNT"

# Ensure /etc/fstab on the SSD is updated
if grep -qs "$TARGET_MOUNT" "$TEMP_MOUNT/etc/fstab"; then
    echo "⚠️  Note: $TARGET_MOUNT already exists in SSD fstab."
else
    echo "Writing mount entry to SSD's /etc/fstab..."
    echo "UUID=$UUID_DATA  $TARGET_MOUNT  ext4  defaults  0  2" >> "$TEMP_MOUNT/etc/fstab"
fi

# Create folder & set ownership dynamically
echo "Creating $TARGET_MOUNT and set ownership to $REAL_USER..."
mkdir -p "$TEMP_MOUNT$TARGET_MOUNT"
chown -R "$USER_ID":"$GROUP_ID" "$TEMP_MOUNT$TARGET_MOUNT"
chmod -R 755 "$TEMP_MOUNT$TARGET_MOUNT"

# 6. Cleanup
umount "$TEMP_MOUNT"
rmdir "$TEMP_MOUNT"

echo "--- ✅ Success! Data partition configured for $REAL_USER. ---"
