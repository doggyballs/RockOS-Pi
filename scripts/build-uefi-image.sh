#!/bin/sh
set -eu

ROCKOS_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
BUILDROOT="$ROCKOS_DIR/buildroot"
IMAGES="$BUILDROOT/output/images"

GRUB_BUILD="$BUILDROOT/output/build/grub2-2.12/build-x86_64-efi"
GRUB_CORE="$GRUB_BUILD/grub-core"

ROOT_PARTUUID="8bca20d7-7113-4d3b-9712-362b47844201"

echo "===== RockOS UEFI image build ====="

mkdir -p "$IMAGES/rockos-efi/EFI/BOOT"

echo "Creating root filesystem copy..."
cp --sparse=always \
    "$IMAGES/rootfs.ext2" \
    "$IMAGES/rockos-rootfs.ext2"

e2label "$IMAGES/rockos-rootfs.ext2" ROCKOS

echo "Creating BOOTX64.EFI..."
"$GRUB_BUILD/grub-mkimage" \
    -d "$GRUB_CORE" \
    -O x86_64-efi \
    -o "$IMAGES/rockos-efi/EFI/BOOT/BOOTX64.EFI" \
    -p /EFI/BOOT \
    part_gpt \
    part_msdos \
    fat \
    ext2 \
    normal \
    linux \
    search \
    search_fs_uuid \
    search_label \
    search_fs_file \
    configfile \
    efi_gop \
    video \
    video_bochs \
    video_cirrus \
    gfxterm \
    gfxterm_background \
    jpeg \
    sleep \
    echo \
    chain

cp \
    "$ROCKOS_DIR/config/uefi/grub.cfg" \
    "$IMAGES/rockos-efi/EFI/BOOT/grub.cfg"

cp \
    "$ROCKOS_DIR/config/uefi/bootlogo.jpg" \
    "$IMAGES/rockos-efi/EFI/BOOT/bootlogo.jpg"

echo "Copying RockOS EFI-stub kernel..."
cp \
    "$IMAGES/bzImage" \
    "$IMAGES/rockos-efi/EFI/BOOT/ROCKOS.EFI"

echo "Creating EFI System Partition..."
rm -f "$IMAGES/rockos-esp.img"
truncate -s 64M "$IMAGES/rockos-esp.img"

"$BUILDROOT/output/host/sbin/mkfs.fat" \
    -F 32 \
    -n ROCKOSEFI \
    "$IMAGES/rockos-esp.img"

MTOOLS_SKIP_CHECK=1 \
"$BUILDROOT/output/host/bin/mmd" \
    -i "$IMAGES/rockos-esp.img" \
    ::/EFI \
    ::/EFI/BOOT

MTOOLS_SKIP_CHECK=1 \
"$BUILDROOT/output/host/bin/mcopy" \
    -i "$IMAGES/rockos-esp.img" \
    "$IMAGES/rockos-efi/EFI/BOOT/BOOTX64.EFI" \
    ::/EFI/BOOT/BOOTX64.EFI

MTOOLS_SKIP_CHECK=1 \
"$BUILDROOT/output/host/bin/mcopy" \
    -i "$IMAGES/rockos-esp.img" \
    "$IMAGES/rockos-efi/EFI/BOOT/grub.cfg" \
    ::/EFI/BOOT/grub.cfg

MTOOLS_SKIP_CHECK=1 \
"$BUILDROOT/output/host/bin/mcopy" \
    -i "$IMAGES/rockos-esp.img" \
    "$IMAGES/rockos-efi/EFI/BOOT/bootlogo.jpg" \
    ::/EFI/BOOT/bootlogo.jpg

MTOOLS_SKIP_CHECK=1 \
"$BUILDROOT/output/host/bin/mcopy" \
    -i "$IMAGES/rockos-esp.img" \
    "$IMAGES/rockos-efi/EFI/BOOT/ROCKOS.EFI" \
    ::/EFI/BOOT/ROCKOS.EFI

echo "Creating GPT USB image..."
rm -rf /tmp/rockos-genimage-work
rm -f "$IMAGES/rockos-usb.img"

"$BUILDROOT/output/host/bin/genimage" \
    --rootpath "$BUILDROOT/output/target" \
    --tmppath /tmp/rockos-genimage-work \
    --inputpath "$IMAGES" \
    --outputpath "$IMAGES" \
    --config "$ROCKOS_DIR/config/uefi/genimage.cfg"

echo
echo "===== VERIFY ====="

file "$IMAGES/rockos-efi/EFI/BOOT/BOOTX64.EFI"

echo
blkid "$IMAGES/rockos-rootfs.ext2"

echo
fdisk -l "$IMAGES/rockos-usb.img"

echo
echo "Expected root PARTUUID:"
echo "$ROOT_PARTUUID"

echo
echo "RockOS UEFI image:"
ls -lh "$IMAGES/rockos-usb.img"
