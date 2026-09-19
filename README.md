# RockOS-Pi — a dedicated, air-gapped Bitcoin entropy appliance

RockOS-Pi is a Raspberry Pi 5 + 7" touch panel appliance build of
[RockOS](https://github.com/SaniExp/RockOS) — a minimal Linux operating
system that boots directly into the bundled
[EntropyLab](https://entropylab.online) application. This is a
**separate, related repo**: we forked RockOS to take it somewhere the
upstream x86-64 USB-boot design doesn't go, and the two will keep
evolving independently.

**Status:** working prototype — boots to an interactive EntropyLab on
the Pi 5 + 7" HDMI touch panel. *(Photos coming.)*

## Why dedicated hardware? The air-gap argument

There are several approaches in this space, including upstream RockOS's
bootable USB drive and fully offline laptop builds. We went a different
way, and we'd argue it's slightly better for overall air-gap hygiene:

**The SD card is the only thing that ever moves.**

Once the Pi + panel are assembled (eventually in a much sleeker, 3D
printable case), the appliance is a sealed unit. It has one job and one
shape. The only artifact that travels between your online world and
this device is an SD card carrying a confirmed release of RockOS-Pi.

Compare that with the alternatives:

- A bootable USB drive on your everyday laptop: the machine is still
  your general-purpose computer, with its general-purpose attack
  surface, its dozens of partitions, its firmware you don't audit. The
  failure mode is human — *"oops, I thought I booted the USB stick, but
  I'm actually live on my laptop's main OS"* — and that mistake is
  exactly what this design makes impossible.
- A fully offline laptop: dedicated and excellent, but a laptop is a
  big, expensive, general-purpose object that tempts repurposing, and
  its Wi-Fi/Bluetooth hardware is a solder-float away from being
  "temporarily" re-enabled.

A Pi in a case with a panel bolted on cannot be mistaken for anything
else. There is no other OS on it to accidentally boot, no other role it
can drift into, no hardware radio to re-enable, no keyboard wedge
between you and the entropy. It's easy to use *because* it's
fool-proof: the user cannot get the air gap wrong, because the device
has no second life.

## What changed from upstream RockOS

This repo started as a fork of the x86-64/UEFI/GRUB RockOS and
diverged in three big areas. The short version: ARM port, smaller
footprint, new browser engine.

### 1. ARM compatibility (Raspberry Pi 5 port)

The x86 boot chain (UEFI → GRUB → EFI-stub kernel) is replaced
entirely. The Pi's own firmware boots the kernel straight from a FAT
boot partition via `config.txt` — a strictly simpler and smaller chain
than GRUB, which is a security win, not just a size win.

- `config/rockos-rpi5_defconfig` (+ `-cog`, `-prod` variants) —
  Buildroot defconfigs for the bcm2712 SoC
- `board/rockos/rpi5/` — firmware config, kernel fragment, genimage
  SD-card layout
- `scripts/build-rpi5-image.sh` — one-command build →
  `rockos-rpi5-sdcard.img`
- Kernel is built from the Raspberry Pi Linux tree (6.12.y) with a
  minimal RockOS fragment on top of `bcm2712_defconfig`, and the Mesa
  stack is the proper v3d/vc4 GPU drivers — no software rendering

The 7" panel rig is the **HDMI variant** of the Waveshare 1024x600
touchscreen (WS170120, USB-HID touch), driven directly over HDMI. (The
DSI-ribbon variant of the panel is a parked project; enabling its
overlay without the ribbon attached creates a phantom output that
gremlins the display mapping.)

### 2. Minimized footprint

Everything in the image that isn't needed to boot, render one web page,
and accept touch input has been removed or disabled:

- **Browser engine swap** (the big one — see below) dropped the entire
  Qt5/QtWebEngine stack, ~185 MB of installed rootfs and the single
  largest attack surface in the OS
- Aggressive post-build pruning of locales, DevTools, QML tooling,
  unused compositor shells, and hardware ID databases
- No getty on serial, no unnecessary shells/terminals in the image
- Networking is reduced to loopback + a DEBUG-only wired-SSH path that
  ships in dev images only and is flagged for removal before any
  release (see `board/rockos/rpi5/DEBUG-REMOVAL-CHECKLIST.md`)

The result: a ~234 MB rootfs (512 MB ext2 partition) where the previous
QtWebEngine build carried ~420 MB — roughly half the image, a fraction
of the attack surface, and a much faster build.

### 3. Browser engine: QtWebEngine/Chromium → cog + WPE WebKit

The upstream RockOS renders EntropyLab through QtWebEngine 5.15, which
is Chromium 87 (January 2021) — frozen, with no security backports.
That old engine also pinned EntropyLab to v0.1.3: upstream main needs
WebAssembly reference-types and ES2022, which Chromium 87 cannot run.

We replaced it with **cog + WPE WebKit 2.50** (the Safari-lineage
engine, actively maintained by Igalia):

- **EntropyLab unpin becomes possible** — WPE 2.50 is a current engine;
  the WASM/ES2022 ceiling disappears
- **Modern security posture** — active upstream WebKit backports vs a
  five-year-old frozen Chromium
- **Native kiosk architecture** — cage (a purpose-built wlroots kiosk
  compositor) + cog (a single-window WPE launcher) replace Qt's entire
  presence; no X11, no XWayland, no Qt input stack
- **Half the RAM, ~⅓–½ the compile time**, and it works with the
  on-screen keyboard (wvkbd) via wlroots layer-shell patches

Getting this running took real work beyond flipping Buildroot switches
— cage needed patches to advertise the `wayland-drm` protocol, Mesa
needed its `legacy-wayland` EGL binding enabled, WebKit needed the
freedesktop MIME database to even serve `text/html`, and wlroots'
undeclared runtime deps (lcms2, xkb data) had to be hunted down one
crash at a time. The `docs/proposal-cog-wpe-browser.md` "Validation"
section has the full story if you enjoy that kind of thing.

*(Until the EntropyLab unpin test passes on hardware, the QtWebEngine
defconfig is kept in-tree as a fallback.)*

## Using it

Write the image to an SD card with `dd` (or Rufus/balenaEtcher):

    sudo dd if=buildroot-rpi5/output/images/rockos-rpi5-sdcard.img \
        of=/dev/sdX bs=4M status=progress conv=fsync

Boot process on the Pi is intentionally boring:

**Pi firmware → Linux → busybox init → cage compositor → cog → EntropyLab**

Touch input works through libinput/cage; the virtual keyboard (wvkbd +
a floating toggle button) is included.

## Building

    ./scripts/build-rpi5-image.sh           # QtWebEngine dev build
    ./scripts/build-rpi5-image.sh cog       # cog/WPE engine (validated)
    ./scripts/build-rpi5-image.sh prod      # production: no SSH, no DHCP

The script clones Buildroot into `buildroot-rpi5/` on first run; the
repo is a `BR2_EXTERNAL` tree. Rebuilds are incremental with ccache
(cache at `~/.buildroot-ccache`, managed by `scripts/ccache-maint.sh`).

## Bundled app

`app/entropylab.html` is the single source of truth for the bundled
EntropyLab; `scripts/post-build.sh` stamps it into the image and logs
the shipped version at build time. See "Updating EntropyLab" details in
AGENTS.md while the v0.1.3 pin unwinds.

## Credits

- [RockOS](https://github.com/SaniExp/RockOS) (SaniExp) — the upstream
  x86-64 appliance this project forked from
- [EntropyLab](https://entropylab.online) — the bundled application
- [cage](https://www.hjdskes.nl/projects/cage/), [wlroots](https://gitlab.freedesktop.org/wlroots/wlroots),
  [WPE WebKit](https://wpewebkit.org/), [cog](https://github.com/Igalia/cog)
  — the display and engine stack
