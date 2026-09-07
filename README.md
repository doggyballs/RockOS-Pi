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