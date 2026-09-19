#!/bin/sh

set -eu

TARGET_DIR="$1"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
ROCKOS_DIR="$(dirname "$SCRIPT_DIR")"

echo "ROCKOS: running final rootfs cleanup"

# ------------------------------------------------------------
# EntropyLab: app/entropylab.html is the single source of truth.
# Sync it into the app path and log the bundled version so every
# build records exactly which EntropyLab shipped.
# ------------------------------------------------------------

ENTROPY_SRC="$ROCKOS_DIR/app/entropylab.html"
ENTROPY_DST="$TARGET_DIR/opt/rockos/app/entropylab.html"

if [ ! -f "$ENTROPY_SRC" ]; then
    echo "ROCKOS ERROR: $ENTROPY_SRC not found" >&2
    exit 1
fi

mkdir -p "$(dirname "$ENTROPY_DST")"
cp "$ENTROPY_SRC" "$ENTROPY_DST"

ENTROPY_VERSION="$(sed -n 's/.*<meta name="application-version" content="\([^"]*\)".*/\1/p' "$ENTROPY_SRC" | head -n1)"
echo "ROCKOS: EntropyLab version: ${ENTROPY_VERSION:-unknown}"

echo "ROCKOS: final rootfs cleanup complete"

# ------------------------------------------------------------
# eudev hardware database is disabled in RockOS
# ------------------------------------------------------------

rm -f "$TARGET_DIR/lib/udev/hwdb.bin"
rm -rf "$TARGET_DIR/etc/udev/hwdb.d"

# ------------------------------------------------------------
# Remove SQLite command-line utility
# Keep libsqlite3: runtime libraries still depend on it
# ------------------------------------------------------------

rm -f "$TARGET_DIR/usr/bin/sqlite3"

# ------------------------------------------------------------
# !!! DEBUG ONLY — REMOVE BEFORE PRODUCTION / BEFORE ANY UPSTREAM PR !!!
# Dropbear SSH for headless bring-up debugging. Rootfs overlays land
# with default 0644 perms; dropbear requires strict key file perms.
# Remove this block together with BR2_PACKAGE_DROPBEAR and
# rockos-overlay/etc/dropbear/ — see
# board/rockos/rpi5/DEBUG-REMOVAL-CHECKLIST.md
# ------------------------------------------------------------

if [ -d "$TARGET_DIR/root/.ssh" ]; then
    chmod 700 "$TARGET_DIR/root" "$TARGET_DIR/root/.ssh"
    chmod 600 "$TARGET_DIR/root/.ssh/authorized_keys"
    echo "ROCKOS: dropbear DEBUG key perms fixed (REMOVE BEFORE PRODUCTION)"
fi

# ------------------------------------------------------------
# Remove unused PCI / USB descriptive hardware ID databases
# Keep pnp.ids because it is selected by a runtime dependency
# ------------------------------------------------------------

rm -f \
    "$TARGET_DIR/usr/share/hwdata/pci.ids" \
    "$TARGET_DIR/usr/share/hwdata/usb.ids"
