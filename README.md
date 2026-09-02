# RockOS 0.1.0-beta.1

RockOS is a minimal Linux appliance operating system designed to boot directly
into the bundled EntropyLab application.

## Beta status

This is an early hardware-testing release.

### Current requirements

- x86-64 PC
- UEFI firmware
- USB boot support
- Secure Boot disabled

## Installation / testing

RockOS is currently intended to run directly from a USB flash drive.

Write:

    RockOS-0.1.0-beta.1.img

to a USB drive using a raw disk imaging tool such as Rufus, balenaEtcher, or dd.

WARNING: Writing the image will overwrite the selected USB drive.

Do not install RockOS to your computer's internal storage at this stage.

## Boot process

RockOS currently uses:

    UEFI
      -> GRUB
      -> RockOS boot logo
      -> Linux EFI-stub chainload
      -> RockOS
      -> EntropyLab

## Known issues

- Some laptop trackpads are not yet supported.
- Graphics acceleration is not yet optimized on all Intel GPUs.
- Performance may therefore be slower than expected on some systems.
- Hardware compatibility is still being expanded.
- Network/Wi-Fi/Bluetooth removal and offline hardening are not yet complete.

## Verified hardware

The beta has successfully booted on physical x86-64 UEFI hardware and in
virtual-machine testing.

## Verify the image

Compare the SHA-256 hash of the downloaded image with SHA256SUMS.txt.

## Feedback

Useful hardware-test reports should include:

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

RockOS 0.1.0-beta.1
