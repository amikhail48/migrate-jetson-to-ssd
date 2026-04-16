#!/bin/bash
# master_deploy.sh

sudo bash ./make_partitions.sh
sudo bash ./copy_partitions.sh
sync
sudo bash ./configure_ssd_boot.sh
sudo bash ./fix_boot.sh
sudo bash ./setup_storage.sh
