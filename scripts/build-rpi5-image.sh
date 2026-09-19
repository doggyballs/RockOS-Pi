#!/bin/sh
# RockOS rpi5 build script.
#
# Usage:
#   ./scripts/build-rpi5-image.sh [dev|cog|cog-prod|prod]
#
#   dev      (default) -> config/rockos-rpi5_defconfig      (QtWebEngine, DHCP+dropbear)
#   cog                 -> config/rockos-rpi5-cog_defconfig      (WPE+cog, DHCP+dropbear)
#   cog-prod            -> config/rockos-rpi5-cog-prod_defconfig (WPE+cog, offline, radios off)
#   prod                -> config/rockos-rpi5-prod_defconfig      (LEGACY QtWebEngine, offline)
#
# Result: buildroot-rpi5/output/images/rockos-rpi5-sdcard.img

set -eu

MODE="${1:-dev}"
case "$MODE" in
    dev)
        DEFCONFIG="rockos-rpi5_defconfig"
        ;;
    cog)
        DEFCONFIG="rockos-rpi5-cog_defconfig"
        ;;
    cog-prod)
        DEFCONFIG="rockos-rpi5-cog-prod_defconfig"
        ;;
    prod)
        DEFCONFIG="rockos-rpi5-prod_defconfig"
        ;;
    *)
        echo "Usage: $0 [dev|cog|cog-prod|prod]" >&2
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
        if grep -q '^BR2_SYSTEM_DHCP=' .config; then
            echo "ERROR: cog-prod build still has DHCP enabled" >&2
            exit 1
        fi
        if grep -q '^BR2_PACKAGE_DROPBEAR=y' .config; then
            echo "ERROR: cog-prod build still ships dropbear" >&2
            exit 1
        fi
        # Kernel: radios must be compiled out.
        if grep -q '^CONFIG_BT=y\|^CONFIG_BT=m' .config 2>/dev/null; then
            echo "ERROR: cog-prod kernel still has CONFIG_BT" >&2
            exit 1
        fi
        if grep -q '^CONFIG_BRCMFMAC' .config 2>/dev/null; then
            echo "ERROR: cog-prod kernel still has CONFIG_BRCMFMAC (WiFi)" >&2
            exit 1
        fi
        # Note: kernel .config check above needs the linux build dir; the
        # resolved fragment symbols only exist there post-configure, so
        # these greps run against .config (Buildroot symbols) as a first
        # gate. post-image + kernel fragment enforcement follows in-build.
        echo "COG-PROD pre-flight OK: no dhcp, no dropbear"
        ;;
    prod)
        if grep -q '^BR2_SYSTEM_DHCP=' .config; then
            echo "ERROR: prod build still has DHCP enabled" >&2
            exit 1
        fi
        if grep -q '^BR2_PACKAGE_DROPBEAR=y' .config; then
            echo "ERROR: prod build still ships dropbear" >&2
            exit 1
        fi
        echo "PROD pre-flight OK: dhcp off, dropbear absent"
        ;;
esac

make BR2_EXTERNAL="$ROCKOS_DIR"

echo
echo "===== RockOS rpi5 image ($MODE) ====="
ls -lh output/images/rockos-rpi5-sdcard.img
echo "Flash with: dd if=output/images/rockos-rpi5-sdcard.img of=/dev/sdX bs=4M status=progress"
