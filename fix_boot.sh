#!/bin/bash

set -e

# 1. Get the unique Partition ID of the SSD
# We use 'blkid' because it's the most reliable across different Linux versions
TARGET_UUID=$(sudo blkid -s PARTUUID -o value /dev/nvme0n1p1)

echo "Found SSD PARTUUID: $TARGET_UUID"

# 2. Mount the SSD partition so we can edit the config
sudo mount /dev/nvme0n1p1 /mnt

# 3. Use 'sed' to find the 'root=' part and swap it with our new PARTUUID
# This command looks for root= and replaces everything until the next space
sudo sed -i "s|root=[^ ]*|root=PARTUUID=$TARGET_UUID|" /mnt/boot/extlinux/extlinux.conf

# 4. Verify the change was made
echo "--- Updated extlinux.conf ---"
grep "root=PARTUUID" /mnt/boot/extlinux/extlinux.conf

# 5. Clean up
sudo umount /mnt
echo "Done! You are ready to reboot."
