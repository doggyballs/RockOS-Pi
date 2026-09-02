#!/bin/sh
set -e

mkdir -p "${TARGET_DIR}/boot/grub"

cp "${BINARIES_DIR}/bzImage" "${TARGET_DIR}/boot/bzImage"
cp "${CONFIG_DIR}/board/pc/grub-bios.cfg" "${TARGET_DIR}/boot/grub/grub.cfg"
