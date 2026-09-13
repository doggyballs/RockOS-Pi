#!/bin/sh
# RockOS rpi5 build script.
#
# Usage:
#   ./scripts/build-rpi5-image.sh [dev|prod]
#
#   dev  (default) -> config/rockos-rpi5_defconfig (DHCP+dropbear for debug)
#   prod           -> config/rockos-rpi5-prod_defconfig (offline, dropbear-free)
#
# Result: buildroot-rpi5/output/images/rockos-rpi5-sdcard.img

set -eu

MODE="${1:-dev}"
case "$MODE" in
    dev)
        DEFCONFIG="rockos-rpi5_defconfig"
        ;;
    prod)
        DEFCONFIG="rockos-rpi5-prod_defconfig"
        ;;
    *)
        echo "Usage: $0 [dev|prod]" >&2
        exit 1
        ;;
esac

ROCKOS_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
BR_DIR="$ROCKOS_DIR/buildroot-rpi5"

if [ ! -d "$BR_DIR/.git" ]; then
    echo "Cloning Buildroot into buildroot-rpi5/ ..."
    git clone --depth 1 https://github.com/buildroot/buildroot.git "$BR_DIR"
fi

cd "$BR_DIR"
cp "$ROCKOS_DIR/config/$DEFCONFIG" configs/
make BR2_EXTERNAL="$ROCKOS_DIR" "$DEFCONFIG"

if [ "$MODE" = "prod" ]; then
    # Pre-flight: prod must ship with DHCP disabled and no dropbear.
    if grep -q '^BR2_SYSTEM_DHCP=' .config; then
        echo "ERROR: prod build still has DHCP enabled" >&2
        exit 1
    fi
    if grep -q '^BR2_PACKAGE_DROPBEAR=y' .config; then
        echo "ERROR: prod build still ships dropbear" >&2
        exit 1
    fi
    echo "PROD pre-flight OK: dhcp off, dropbear absent"
fi

make BR2_EXTERNAL="$ROCKOS_DIR"

echo
echo "===== RockOS rpi5 image ($MODE) ====="
ls -lh output/images/rockos-rpi5-sdcard.img
echo "Flash with: dd if=output/images/rockos-rpi5-sdcard.img of=/dev/sdX bs=4M status=progress"
