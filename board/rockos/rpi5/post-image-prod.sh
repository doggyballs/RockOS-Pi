#!/bin/sh
set -eu

# RockOS rpi5 PRODUCTION post-image: identical to post-image.sh but
# swaps in the production firmware config (radios disabled at the
# device-tree level) instead of the dev config.txt.

ROCKOS_DIR="$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)"
CONFIG_SRC="$ROCKOS_DIR/board/rockos/rpi5/config-prod.txt"
CONFIG_DST="${BINARIES_DIR}/rpi-firmware/config.txt"
if [ -f "$CONFIG_SRC" ] && [ -f "$CONFIG_DST" ]; then
    cp "$CONFIG_SRC" "$CONFIG_DST"
    echo "post-image-prod: refreshed config.txt from config-prod.txt (radios OFF)"
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
