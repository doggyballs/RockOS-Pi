# RockOS-Pi

A Raspberry Pi 5 + 7" touch panel appliance build of
[RockOS](https://github.com/SaniExp/RockOS) — the minimal Linux OS that
boots straight into [EntropyLab](https://entropylab.online), the
self-contained Bitcoin key and wallet calculator.

This is a sibling project rather than a fork-with-intent-to-merge: same
goal, different hardware, so it lives in its own repo. Full credit to
the upstream for the original appliance design and for EntropyLab —
none of this exists without it.

**Status:** working prototype — boots to an interactive EntropyLab on
the Pi 5 + 7" HDMI touch panel. *(Photos coming.)*

## Approach

There are a few good ways to run air-gapped entropy tooling, and
they're all trade-offs:

- **Bootable USB on your own machine** (upstream RockOS's approach) —
  most convenient, no extra hardware, and the upstream has done solid
  work making this safe
- **A dedicated offline laptop** — maximum capability, at the cost of
  dedicating an expensive general-purpose machine
- **A small appliance** (this repo) — a Pi and panel in a case that
  does exactly one thing

The appliance approach is what this project explores, and its core
idea is simple: **the SD card is the only thing that ever moves.** The
assembled unit has one job and no other OS to accidentally boot, no
radios to re-enable, no second life to drift into. The failure mode
this targets is human — *"oops, I thought I was on the dedicated
stick"* — by making the mistake physically impossible. That's a
trade-off (it's another box on your shelf, and the Pi's HDMI panel and
case are extra parts), not a claim that it's the right answer for
everyone.

## What changed from upstream

Three areas, briefly. Details live in `AGENTS.md` and
`docs/proposal-cog-wpe-browser.md`.

### ARM port (Raspberry Pi 5)

The x86 UEFI/GRUB chain is replaced by the Pi's own firmware booting
the kernel from the FAT partition via `config.txt` — a shorter chain,
and the Pi-specific v3d/vc4 GPU drivers come along properly. The 7"
panel is the HDMI variant (WS170120, USB-HID touch); the DSI-ribbon
variant is a parked side-quest.

### Smaller footprint

Post-build pruning plus the engine swap below cut the rootfs from
~420 MB (Qt stack) to ~234 MB, with the corresponding attack-surface
and build-time reductions.

### Browser engine: QtWebEngine → cog + WPE WebKit

Upstream ships QtWebEngine 5.15 (Chromium 87), which pinned EntropyLab
at v0.1.3 — newer EntropyLab needs WASM reference-types and ES2022
that Chromium 87 can't run. This repo swaps in **cog + WPE WebKit
2.50** (maintained by Igalia), which lifts that ceiling and brings
active security backports. The kiosk stack became cage (a wlroots
kiosk compositor) + cog — no X11, no Qt.

Getting there took more than Buildroot switches: cage needed a patch to
advertise `wayland-drm`, Mesa needed its `legacy-wayland` EGL binding
enabled, WebKit needed the freedesktop MIME database to serve
`text/html`, and wlroots' undeclared runtime deps had to be chased one
crash at a time. All documented in the proposal doc's "Validation"
section.

## Building

Four variants via one script:

    ./scripts/build-rpi5-image.sh dev        # QtWebEngine, debug SSH — legacy reference
    ./scripts/build-rpi5-image.sh cog        # cog/WPE engine, debug SSH — dev default
    ./scripts/build-rpi5-image.sh cog-prod   # cog/WPE, offline appliance image
    ./scripts/build-rpi5-image.sh prod       # QtWebEngine, offline — legacy

**dev** builds include debug conveniences (DHCP + dropbear SSH + a
tty1 root getty) for bring-up on the bench. **cog-prod** is the
appliance image: no SSH, no getty, no DHCP, and comms disabled at three
layers — firmware device-tree overlays (`disable-wifi-pi5`,
`disable-bt-pi5` so the kernel never probes the radios), kernel config
(BT/WiFi/netfilter/IPv6 compiled out; loopback kept for Wayland's local
IPC), and userspace (nothing brings up an interface). The script runs
pre-flight checks that refuse to build a prod image with DHCP or
dropbear in it.

The script clones Buildroot into `buildroot-rpi5/` on first run; the
repo is a `BR2_EXTERNAL` tree. Rebuilds are incremental with ccache
(`scripts/ccache-maint.sh`).

Flash the result to an SD card:

    sudo dd if=buildroot-rpi5/output/images/rockos-rpi5-sdcard.img \
        of=/dev/sdX bs=4M status=progress conv=fsync

Boot chain on the Pi: **firmware → Linux → busybox init → cage → cog →
EntropyLab**. Touch works via libinput; the virtual keyboard (wvkbd +
toggle button) is included.

## Bundled app

`app/entropylab.html` is the single source of truth for the bundled
EntropyLab; `scripts/post-build.sh` stamps it into the image and logs
the shipped version at build time. Currently v0.1.3 + QR backport;
the cog/WPE engine should allow tracking upstream again (test pending).

## Credits

- [RockOS](https://github.com/SaniExp/RockOS) (SaniExp) — the upstream
  appliance OS this project builds on
- [EntropyLab](https://entropylab.online) — the bundled application
- [cage](https://www.hjdskes.nl/projects/cage/),
  [wlroots](https://gitlab.freedesktop.org/wlroots/wlroots),
  [WPE WebKit](https://wpewebkit.org/),
  [cog](https://github.com/Igalia/cog) — the display and engine stack
