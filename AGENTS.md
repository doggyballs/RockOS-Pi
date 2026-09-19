# Agent Context — RockOS

Fork of a Buildroot-based offline Bitcoin-entropy kiosk OS.
Origin: `git@github-doggyballs:doggyballs/RockOS` (doggyballs identity — see ~/doggyballs/AGENTS.md).

## Goal

Upstream PR adding multi-board image output: x86-64 UEFI + aarch64 (rpi4 / rpi5 / cm4).

## Agreed strategy

1. rpi5-only port first — prove it works on one aarch64 target.
2. BR2_EXTERNAL restructure later, once the port is validated.

rpi5 port layout:
- `config/rockos-rpi5_defconfig`
- `board/rockos/rpi5/`
- `scripts/build-rpi5-image.sh`
- Build tree lives in-repo at `buildroot-rpi5/` (gitignored).

## Test rig

- Raspberry Pi 5 + Waveshare 7" DSI-C touchscreen (DSI display + I2C touch).
- Overlay: `vc4-kms-dsi-waveshare-panel,7_0_inchC`.

## Gotchas

- The Waveshare panel driver `panel-waveshare-dsi.ko` is OUT OF TREE (ships only as an rpi-firmware blob). A black DSI screen on first boot most likely = missing module, not a bad config.
- **The working 7" panel rig is the HDMI variant (WS170120, USB-HID touch), NOT the DSI ribbon.** The DSI ribbon variant is parked (never brought up). Do NOT enable `dtoverlay=vc4-kms-dsi-waveshare-panel` while the HDMI panel is connected — with no ribbon attached it creates a phantom DSI-1 output and cage (EXTEND mode) puts the app on it, leaving HDMI black.
- **cog/WPE engine swap VALIDATED (2026-09-19)** — `config/rockos-rpi5-cog_defconfig` renders EntropyLab on the rpi5 + 7" HDMI panel. Requires four non-obvious fixes (see docs/proposal-cog-wpe-browser.md "Validation"): cage wl-drm patch, `BR2_PACKAGE_MESA3D_LEGACY_BIND_WAYLAND_DISPLAY`, `BR2_PACKAGE_SHARED_MIME_INFO`, lcms2+xkeyboard-config. QtWebEngine defconfig kept as legacy fallback.
- **EntropyLab UNPIN VALIDATED (2026-09-19, hardware)** — latest upstream (OogaBoogaX/entropylab, rock branch) runs on WPE 2.50: WASM secp256k1 sanity check passes, ES2022 (`Object.hasOwn`) fine. NO pin, NO backport, NO patches — app/entropylab.html is now a plain copy of the upstream artifact. Update flow: download fresh entropylab.html from the site or repo, replace the file, rebuild (rootfs-only, minutes). Upstream labels the file's version meta "v0.1.3" (lags); the real identity is the build commit (e.g. 6f22520).
- DEBUG-ONLY: dropbear SSH + tty1 root getty (cog overlay inittab) are temporarily in the cog variant for bring-up. MUST be removed before production / upstream PR — see `board/rockos/rpi5/DEBUG-REMOVAL-CHECKLIST.md`.
- **Open issue:** boot-time ENOSPC errors (mkdir /var/log, /etc/dropbear, dbus machine-id) on some boots — tmpfs mount ordering suspected. dropbear SSH unreliable because of it. Under investigation.
- QtWebEngine 5.15 = Chromium 87 ceiling (HISTORICAL — applies only to the legacy Qt defconfigs): upstream EntropyLab main (post 2026-09-03) needs WASM reference-types + ES2022 (`Object.hasOwn`) → secp256k1 sanity check hard-fails on Chromium 87. The legacy Qt path is still PINNED to v0.1.3 + QR-popup backport (app-backport copies are gone from the tree since the unpin; the pin only matters if you rebuild the Qt variants, which are deprecated). rockos-browser (Qt) drops all `target=_blank` clicks; cog untested for that.
- Virtual keyboard: wvkbd + kbd-toggle work under cage via the layer-shell patches (patches/cage/0001-0003). wvkbd needs `--hidden` (not `--mobintl` — layout is compile-time, not a runtime flag).

## Build host

agent-vm (this VM). Build tooling installed 2026-09-07: cmake, ninja, bison, flex, pkg-config.
