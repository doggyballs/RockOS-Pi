# RockOS 0.1.0-beta.1

RockOS is a minimal Linux appliance operating system designed to boot directly into the bundled **EntropyLab** application.

## Beta Status

This is an early hardware-testing release.

## Current Requirements

- x86-64 PC
- UEFI firmware
- USB boot support
- Secure Boot disabled

## Installation / Testing

RockOS is currently intended to run directly from a USB flash drive.

Write the RockOS image to a USB drive using a raw disk imaging tool such as Rufus, balenaEtcher, or `dd`.

> **WARNING:** Writing the image will overwrite the selected USB drive.

Do **not** install RockOS to your computer's internal storage at this stage.

## Boot Process

RockOS currently uses:

**UEFI → GRUB → RockOS boot logo → Linux EFI-stub chainload → RockOS → EntropyLab**

## Known Issues

- Some laptop trackpads are not yet supported.
- Graphics acceleration is not yet optimized on all Intel GPUs.
- Performance may therefore be slower than expected on some systems.
- Hardware compatibility is still being expanded.
- Network/Wi-Fi/Bluetooth removal and final offline hardening are not yet complete.

## Verified Hardware

The beta has successfully booted on physical x86-64 UEFI hardware and in virtual-machine testing.

## Verify the Image

Compare the SHA-256 hash of the downloaded image with the value provided in `SHA256SUMS.txt`.

## Hardware Test Feedback

Useful test reports should include:

- Computer manufacturer and model
- CPU
- GPU
- Whether RockOS reached EntropyLab
- Keyboard status
- Mouse/trackpad status
- Display/resolution issues
- Approximate boot time
- Any visible boot errors

## Version
**RockOS 0.1.0-beta.1**

## Raspberry Pi 5 (experimental)

An experimental aarch64 port for the Raspberry Pi 5 + Waveshare 7" DSI
touchscreen lives alongside the x86 build:

- `config/rockos-rpi5_defconfig` — Buildroot defconfig (bcm2712, mesa v3d/vc4,
  QtWebEngine, Weston kiosk)
- `board/rockos/rpi5/` — firmware config, kernel fragment, genimage layout
- `scripts/build-rpi5-image.sh` — one-shot build, produces
  `buildroot-rpi5/output/images/rockos-rpi5-sdcard.img`

The Waveshare panel is enabled via `vc4-kms-dsi-waveshare-panel,7_0_inchC` in
`board/rockos/rpi5/config.txt`. All other RockOS hardening and the EntropyLab
app are unchanged from the x86 build.

## Building the rpi5 image

    ./scripts/build-rpi5-image.sh

The script clones Buildroot into `buildroot-rpi5/` on first run, applies
`config/rockos-rpi5_defconfig`, and builds. The repo is a `BR2_EXTERNAL`
tree, so the script passes `BR2_EXTERNAL=..` to make. Output:

    buildroot-rpi5/output/images/rockos-rpi5-sdcard.img

Flash with `dd` (or Rufus/balenaEtcher) to an SD card:

    sudo dd if=buildroot-rpi5/output/images/rockos-rpi5-sdcard.img \
        of=/dev/sdX bs=4M status=progress conv=fsync

Rebuilds are incremental — ccache is enabled (cache at
`~/.buildroot-ccache`, outside the build tree). Manage it with:

    ./scripts/ccache-maint.sh status    # current size and stats
    ./scripts/ccache-maint.sh cap 12G   # set max size (auto-evicts LRU)
    ./scripts/ccache-maint.sh clean     # empty the cache

## Updating EntropyLab

`app/entropylab.html` is the single source of truth for the bundled app.
`scripts/post-build.sh` copies it into the image at build time and logs the
bundled version (read from the file's `application-version` meta tag), so
every build records which EntropyLab shipped.

To update:

    cp /path/to/new-entropylab.html app/entropylab.html
    git commit -am "EntropyLab vX.Y.Z"
    cd buildroot-rpi5 && make BR2_EXTERNAL=..

The rebuild only regenerates the rootfs and image (minutes, not hours).
Check the build output for the `ROCKOS: EntropyLab version: vX.Y.Z` line
to confirm what shipped.