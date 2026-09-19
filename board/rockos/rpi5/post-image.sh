#!/bin/sh
set -eu

# Force-copy the latest config.txt from the repo into the staging dir.
# Buildroot copies this at defconfig time; if you run `make` without
# re-running `make rockos-rpi5-cog_defconfig`, a stale config.txt ships.
# This guarantees the repo's config.txt is always what lands in the image.
ROCKOS_DIR="$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)"
CONFIG_SRC="$ROCKOS_DIR/board/rockos/rpi5/config.txt"
CONFIG_DST="${BINARIES_DIR}/rpi-firmware/config.txt"
if [ -f "$CONFIG_SRC" ] && [ -f "$CONFIG_DST" ]; then
    cp "$CONFIG_SRC" "$CONFIG_DST"
    echo "post-image: refreshed config.txt from repo"
fi

GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
ROOTPATH_TMP="$(mktemp -d)"
trap 'rm -rf "${ROOTPATH_TMP}"' EXIT

rm -rf "${GENIMAGE_TMP}"

genimage \
	--rootpath "${ROOTPATH_TMP}" \
	--tmppath "${GENIMAGE_TMP}" \
	--inputpath "${BINARIES_DIR}" \
	--outputpath "${BINARIES_DIR}" \
	--config "$(dirname "$0")/genimage-rockos-rpi5.cfg"
