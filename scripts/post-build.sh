#!/bin/sh

set -eu

TARGET_DIR="$1"

echo "ROCKOS: running final rootfs cleanup"

# ------------------------------------------------------------
# Remove obsolete Cog / WPE WebKit runtime remnants
# ------------------------------------------------------------

rm -f \
    "$TARGET_DIR/usr/bin/cog" \
    "$TARGET_DIR/usr/bin/cogctl"

rm -rf \
    "$TARGET_DIR/usr/lib/cog" \
    "$TARGET_DIR/usr/lib/wpe-webkit-2.0" \
    "$TARGET_DIR/usr/share/wpe-webkit-2.0" \
    "$TARGET_DIR/usr/libexec/wpe-webkit-2.0"

rm -f \
    "$TARGET_DIR"/usr/lib/libcogcore.so* \
    "$TARGET_DIR"/usr/lib/libWPEWebKit-2.0.so* \
    "$TARGET_DIR"/usr/lib/libWPEBackend-fdo-1.0.so*

# ------------------------------------------------------------
# RockOS only needs English QtWebEngine locales
# ------------------------------------------------------------

LOCALES="$TARGET_DIR/usr/translations/qtwebengine_locales"

if [ -d "$LOCALES" ]; then
    find "$LOCALES" \
        -type f \
        ! -name 'en-US.pak' \
        ! -name 'en-GB.pak' \
        -delete
fi

echo "ROCKOS: final rootfs cleanup complete"

# ------------------------------------------------------------
# eudev hardware database is disabled in RockOS
# ------------------------------------------------------------

rm -f "$TARGET_DIR/lib/udev/hwdb.bin"
rm -rf "$TARGET_DIR/etc/udev/hwdb.d"


# ------------------------------------------------------------
# Remove obsolete standalone libwpe runtime
# ------------------------------------------------------------

rm -f "$TARGET_DIR"/usr/lib/libwpe-1.0.so*


# ------------------------------------------------------------
# Remove obsolete Weston modules
# RockOS uses only the kiosk shell
# ------------------------------------------------------------

rm -f \
    "$TARGET_DIR/usr/lib/weston/desktop-shell.so" \
    "$TARGET_DIR/usr/lib/weston/fullscreen-shell.so" \
    "$TARGET_DIR/usr/lib/weston/ivi-shell.so" \
    "$TARGET_DIR/usr/lib/weston/hmi-controller.so" \
    "$TARGET_DIR/usr/lib/weston/screen-share.so"


# ------------------------------------------------------------
# Remove unused Weston utilities
# RockOS runs directly as a kiosk and does not use these tools
# ------------------------------------------------------------

rm -f \
    "$TARGET_DIR/usr/bin/weston-debug" \
    "$TARGET_DIR/usr/bin/weston-screenshooter" \
    "$TARGET_DIR/usr/bin/weston-calibrator" \
    "$TARGET_DIR/usr/bin/weston-touch-calibrator" \
    "$TARGET_DIR/usr/bin/weston-terminal"


# ------------------------------------------------------------
# Remove SQLite command-line utility
# Keep libsqlite3: runtime libraries still depend on it
# ------------------------------------------------------------

rm -f "$TARGET_DIR/usr/bin/sqlite3"


# ------------------------------------------------------------
# Remove unused PCI / USB descriptive hardware ID databases
# Keep pnp.ids because it is selected by a runtime dependency
# ------------------------------------------------------------

rm -f \
    "$TARGET_DIR/usr/share/hwdata/pci.ids" \
    "$TARGET_DIR/usr/share/hwdata/usb.ids"


# ------------------------------------------------------------
# Remove QtWebEngine DevTools resources
# RockOS does not expose or use Chromium developer tools
# ------------------------------------------------------------

rm -f "$TARGET_DIR/usr/resources/qtwebengine_devtools_resources.pak"


# ------------------------------------------------------------
# Remove QML development / debugging / testing tools
# RockOS is a fixed QtWebEngine kiosk, not a QML development system
# ------------------------------------------------------------

rm -f \
    "$TARGET_DIR/usr/bin/qml" \
    "$TARGET_DIR/usr/bin/qmlscene" \
    "$TARGET_DIR/usr/bin/qmlpreview" \
    "$TARGET_DIR/usr/bin/qmltestrunner" \
    "$TARGET_DIR/usr/bin/qmltime"

rm -rf \
    "$TARGET_DIR/usr/lib/qt/plugins/qmltooling" \
    "$TARGET_DIR/usr/qml/QtTest"

# Remove QML designer-only metadata
find "$TARGET_DIR/usr/qml" \
    -type d \
    -name designer \
    -prune \
    -exec rm -rf {} + 2>/dev/null || true


# ------------------------------------------------------------
# Remove unused QtQuick Controls QML modules
# RockOS uses QWebEngineView/Qt Widgets and does not use these
# application-facing QML control sets.
# Boot and EntropyLab functionality confirmed without them.
# ------------------------------------------------------------

rm -rf \
    "$TARGET_DIR/usr/qml/QtQuick/Controls" \
    "$TARGET_DIR/usr/qml/QtQuick/Controls.2"


# ------------------------------------------------------------
# Remove unused Qt PDF subsystem
# RockOS does not use Qt PDF/PDF Widgets or the Qt PDF image plugin.
# Boot and EntropyLab functionality confirmed without them.
# ------------------------------------------------------------

rm -f \
    "$TARGET_DIR/usr/lib/libQt5Pdf.so" \
    "$TARGET_DIR/usr/lib/libQt5Pdf.so.5" \
    "$TARGET_DIR/usr/lib/libQt5Pdf.so.5.15" \
    "$TARGET_DIR/usr/lib/libQt5Pdf.so.5.15.14" \
    "$TARGET_DIR/usr/lib/libQt5PdfWidgets.so" \
    "$TARGET_DIR/usr/lib/libQt5PdfWidgets.so.5" \
    "$TARGET_DIR/usr/lib/libQt5PdfWidgets.so.5.15" \
    "$TARGET_DIR/usr/lib/libQt5PdfWidgets.so.5.15.14" \
    "$TARGET_DIR/usr/lib/qt/plugins/imageformats/libqpdf.so"

rm -rf \
    "$TARGET_DIR/usr/qml/QtQuick/Pdf"


# ------------------------------------------------------------
# Remove unused Qt display backends
# RockOS runs exclusively as a Qt Wayland client under Weston.
# EGLFS, minimal, minimalegl, offscreen and VNC were boot-tested
# as unnecessary.
# ------------------------------------------------------------

rm -f \
    "$TARGET_DIR/usr/lib/qt/plugins/platforms/libqeglfs.so" \
    "$TARGET_DIR/usr/lib/qt/plugins/platforms/libqminimal.so" \
    "$TARGET_DIR/usr/lib/qt/plugins/platforms/libqminimalegl.so" \
    "$TARGET_DIR/usr/lib/qt/plugins/platforms/libqoffscreen.so" \
    "$TARGET_DIR/usr/lib/qt/plugins/platforms/libqvnc.so"

rm -rf \
    "$TARGET_DIR/usr/lib/qt/plugins/egldeviceintegrations"

rm -f \
    "$TARGET_DIR/usr/lib/libQt5EglFSDeviceIntegration.so" \
    "$TARGET_DIR/usr/lib/libQt5EglFSDeviceIntegration.so.5" \
    "$TARGET_DIR/usr/lib/libQt5EglFSDeviceIntegration.so.5.15" \
    "$TARGET_DIR/usr/lib/libQt5EglFSDeviceIntegration.so.5.15.14" \
    "$TARGET_DIR/usr/lib/libQt5EglFsKmsSupport.so" \
    "$TARGET_DIR/usr/lib/libQt5EglFsKmsSupport.so.5" \
    "$TARGET_DIR/usr/lib/libQt5EglFsKmsSupport.so.5.15" \
    "$TARGET_DIR/usr/lib/libQt5EglFsKmsSupport.so.5.15.14"


# ------------------------------------------------------------
# Remove target-side GRUB maintenance/configuration tools
# RockOS only needs the already-generated boot files under /boot.
# Boot-tested successfully without these runtime utilities.
# ------------------------------------------------------------

rm -f "$TARGET_DIR"/bin/grub-*
rm -f "$TARGET_DIR"/sbin/grub-*

rm -rf \
    "$TARGET_DIR/etc/grub.d" \
    "$TARGET_DIR/share/locale" \
    "$TARGET_DIR/share/info" \
    "$TARGET_DIR/share/grub"

