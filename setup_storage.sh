#!/bin/bash
set -e

TARGET_MOUNT="/opt/py-memo"
DRIVE="/dev/nvme0n1"

while getopts "d:" opt; do
  case ${opt} in
    d ) DRIVE=$OPTARG ;;
  esac
done

if [ "$EUID" -ne 0 ]; then 
  echo "Run as root"; exit 1
fi

echo "--- Partitioning $DRIVE ---"

# Check free space logic
FREE_SPACE=$(sgdisk -p "$DRIVE" | grep "Total free space is" | awk '{print $5}') || true

if [ -z "$FREE_SPACE" ] || [ "$FREE_SPACE" -lt 2048 ]; then
    echo "No space found"; exit 1
fi

sgdisk -n 0:0:0 -t 0:8300 -c 0:"PYMEMO_DATA" "$DRIVE"
partprobe "$DRIVE"
sleep 2

NEW_PART_NUM=$(sgdisk -p "$DRIVE" | grep "^ " | awk '{print $1}' | sort -n | tail -1)
if [[ "$DRIVE" == *"nvme"* ]]; then
    NEW_PART_DEV="${DRIVE}p${NEW_PART_NUM}"
else
    NEW_PART_DEV="${DRIVE}${NEW_PART_NUM}"
fi

mkfs.ext4 -F "$NEW_PART_DEV"
mkdir -p "$TARGET_MOUNT"
UUID=$(blkid -s UUID -o value "$NEW_PART_DEV")

if ! grep -qs "$TARGET_MOUNT" /etc/fstab; then
    echo "UUID=$UUID  $TARGET_MOUNT  ext4  defaults  0  2" >> /etc/fstab
fi

mount -a
chown -R "$SUDO_USER":"$SUDO_USER" "$TARGET_MOUNT"
chmod -R 755 "$TARGET_MOUNT"
echo "Success!"
df -h "$TARGET_MOUNT"
