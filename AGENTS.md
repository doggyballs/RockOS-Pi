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
- DEBUG-ONLY: dropbear SSH is temporarily in the rpi5 defconfig + `rockos-overlay/root/.ssh/` for headless bring-up (added 2026-09-09). MUST be removed before production / upstream PR — see `board/rockos/rpi5/DEBUG-REMOVAL-CHECKLIST.md`.
- QtWebEngine 5.15 = Chromium 87 ceiling: upstream EntropyLab main (post 2026-09-03) needs WASM reference-types + ES2022 (`Object.hasOwn`) → secp256k1 sanity check hard-fails on our browser. App is PINNED to v0.1.3 + QR-popup backport (PR 255, pure DOM + vendored uqr). See README "Updating EntropyLab". rockos-browser also drops all `target=_blank` clicks (bare QWebEngineView, no createWindow override) — dead link clicks in online mode are expected, QR popup only fires when app reports offline.

## Build host

agent-vm (this VM). Build tooling installed 2026-09-07: cmake, ninja, bison, flex, pkg-config.
