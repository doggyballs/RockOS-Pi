#!/bin/sh
# Fetch Buildroot (once), apply the RockOS rpi5 defconfig, and build the SD image.
# Result: buildroot-rpi5/output/images/rockos-rpi5-sdcard.img
set -eu

ROCKOS_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
BR_DIR="$ROCKOS_DIR/buildroot-rpi5"

if [ ! -d "$BR_DIR/.git" ]; then
    echo "Cloning Buildroot into buildroot-rpi5/ ..."
    git clone --depth 1 https://github.com/buildroot/buildroot.git "$BR_DIR"
fi

cd "$BR_DIR"
cp "$ROCKOS_DIR/config/rockos-rpi5_defconfig" configs/
make BR2_EXTERNAL="$ROCKOS_DIR" rockos-rpi5_defconfig
make BR2_EXTERNAL="$ROCKOS_DIR"

echo
echo "===== RockOS rpi5 image ====="
ls -lh output/images/rockos-rpi5-sdcard.img
echo "Flash with: dd if=output/images/rockos-rpi5-sdcard.img of=/dev/sdX bs=4M status=progress"
