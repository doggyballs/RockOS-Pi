#!/bin/sh
# RockOS rpi5 build script.
#
# Usage:
#   ./scripts/build-rpi5-image.sh [cog|cog-prod]
#
#   cog      (default) -> config/rockos-rpi5-cog_defconfig      (WPE+cog, DHCP+dropbear, debug)
#   cog-prod            -> config/rockos-rpi5-cog-prod_defconfig (WPE+cog, offline, radios off)
#
# Result: buildroot-rpi5/output/images/rockos-rpi5-sdcard.img

set -eu

MODE="${1:-cog}"
case "$MODE" in
    cog)
        DEFCONFIG="rockos-rpi5-cog_defconfig"
        ;;
    cog-prod)
        DEFCONFIG="rockos-rpi5-cog-prod_defconfig"
        ;;
    *)
        echo "Usage: $0 [cog|cog-prod]" >&2
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

case "$MODE" in
    cog-prod)
        # Pre-flight: production must be offline and debug-free.
        # BR2_SYSTEM_DHCP="" (empty) is OK — no interface is brought up.
        if grep -qE '^BR2_SYSTEM_DHCP="..*"' .config; then
            echo "ERROR: cog-prod build still has DHCP enabled" >&2
            exit 1
        fi
        if grep -q '^BR2_PACKAGE_DROPBEAR=y' .config; then
            echo "ERROR: cog-prod build still ships dropbear" >&2
            exit 1
        fi
        echo "COG-PROD pre-flight OK: no dhcp, no dropbear"
        ;;
esac

make BR2_EXTERNAL="$ROCKOS_DIR"

echo
echo "===== RockOS rpi5 image ($MODE) ====="
ls -lh output/images/rockos-rpi5-sdcard.img
echo "Flash with: dd if=output/images/rockos-rpi5-sdcard.img of=/dev/sdX bs=4M status=progress"
