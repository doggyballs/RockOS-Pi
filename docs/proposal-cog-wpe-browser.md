# Proposal: replace QtWebEngine kiosk browser with cog + WPE WebKit

**Status:** ✅ **VALIDATED on rpi5 hardware (2026-09-19)** — cog + WPE WebKit
renders EntropyLab on the 7" HDMI touch panel. See "Validation" below.
**Author:** doggyballs
**Date:** 2026-09-09 (proposal) / 2026-09-19 (validated)
**Related:** multi-board PR (rpi4/rpi5/cm4), EntropyLab pin at v0.1.3

## Summary

Replace the kiosk's browser engine — currently a 18-line `QWebEngineView`
wrapper (`rockos-browser/`) on QtWebEngine 5.15 — with **cog** (the WPE
WebKit launcher) running on the existing Weston compositor. This unblocks
tracking upstream EntropyLab again and removes a growing maintenance
liability.

## The problem

QtWebEngine 5.15 ships **Chromium 87 (January 2021)**. It is the newest
QtWebEngine Buildroot can build on the 5.15 LTS line, and it is frozen.

Upstream EntropyLab crossed our engine's capability ceiling on
2026-09-03. Its current builds require:

- **WebAssembly reference-types** — `WebAssembly.instantiate()` fails with
  `expected table index 0` on Chromium 87. The app's secp256k1 engine is
  wasm-only by design; its startup sanity check hard-fails (correctly —
  we would not want it to proceed).
- **ES2022** (`Object.hasOwn`) — crashes app initialization.
- **CSP `wasm-unsafe-eval`** — unrecognized by Chromium 87, which gates
  wasm behind `unsafe-eval` instead.

These are not fixable by patching: the wasm binary itself will not
compile on the old engine, and upstream (a security tool) is right not to
resurrect a pure-JS secp256k1 fallback.

**Current workaround (in the doggyballs fork):** EntropyLab is pinned to
v0.1.3 (last Chromium-87-compatible build), with the offline-QR-popup
feature (upstream PR 255) backported as an injected script. This works —
verified on rpi5 hardware — but means RockOS no longer tracks upstream
EntropyLab. Every upstream fix and feature now requires manual triage
for engine compatibility.

This will only get worse: browser-engine requirements ratchet upward.
The next EntropyLab feature we want may not be backportable as cleanly
as PR 255's pure-DOM module.

## Proposed change

Switch the kiosk runtime to **cog 0.18.x + WPE WebKit 2.50.x** (both
already packaged in Buildroot 2026.11):

- WPE WebKit is a **current** engine (2.50 ≈ Safari 26-era feature set):
  wasm reference-types, ES2022+, modern CSP — runs upstream EntropyLab
  unmodified.
- cog is purpose-built for exactly this use case: single-app fullscreen
  web kiosk on Wayland. It replaces ~all of `rockos-browser/main.cpp`'s
  function with a maintained upstream project.
- Runs directly on our existing Weston (kiosk-shell) via
  `wpebackend-fdo` — no X11, no compositor change.
- Actively maintained upstream (Igalia), unlike QtWebEngine 5.15.

### What it looks like

Defconfig delta (illustrative, per-board package lists unchanged
otherwise):

```
- BR2_PACKAGE_QT5WEBENGINE=y        # and its Qt5 dependency chain
+ BR2_PACKAGE_WPEWEBKIT=y
+ BR2_PACKAGE_COG=y
+ BR2_PACKAGE_COG_PLATFORM_WL=y     # or FDO, per current Buildroot options
```

S99rockos startup becomes roughly:

```sh
cog --platform=wl file:///opt/rockos/app/entropylab.html
```

## Impact analysis

### Footprint

QtWebEngine is the single largest payload in the image (Chromium:
~150–200 MB installed with codecs/locales before our post-build pruning).
WPE WebKit is substantially smaller (order ~40–60 MB). Net image size
**decrease** expected; exact numbers to be measured on both arches.

### Runtime RAM

WebKit2's multi-process model (UI + Web + Network processes) has lower
typical RSS than Chromium's for a single-page kiosk, but both are
hundreds of MB. Fine on rpi5 (8 GB) and x86 targets. If we ever target
sub-2GB boards, measure first. (QtWebEngine today runs with
`--in-process-gpu --no-sandbox` — cog's sandbox story on Buildroot needs
verification; worst case it also runs unsandboxed, which is no worse
than status quo for an offline kiosk loading a single local file.)

### Build time

WPE WebKit builds faster than QtWebEngine/Chromium (fewer sources, no
bundled Chromium toolchain dance). Expect the longest-build pole to
shorten meaningfully — helps the multi-board PR's CI story too.

### What we lose

- Qt5 entirely (only the browser used it) — drops a large dependency
  chain from every build.
- Nothing user-facing: the kiosk loads one local HTML file fullscreen.

### Risks / open questions

1. **WPE WebKit + vc4/v3d (rpi) GL integration** — needs hardware
   verification: WebGL/compositing on the rpi5's V3D via Mesa. EntropyLab
   is a 2D app; even software GL would suffice, but let's verify.
2. **cog keyboard/mouse input** under kiosk-shell — expected fine via
   Wayland; verify on the Waveshare DSI touch rig too (touch input path).
3. **x86 parity** — verify the same image change works on the existing
   x86-64 UEFI target (should be identical: same Weston, same cog).
4. **Fonts/rendering** — confirm DejaVu coverage is sufficient without
   Qt's font stack (it is; WebKit uses fontconfig directly).

## Validation (2026-09-19, rpi5 hardware)

Working image: `config/rockos-rpi5-cog_defconfig` → build with
`./scripts/build-rpi5-image.sh cog`. Verified end-to-end on the rpi5
with the 7" Waveshare HDMI panel (WS170120, USB-HID touch): cage
compositor up, cog/WPE renders EntropyLab, page interactive.

Four fixes were required beyond the naive package swap:

1. **cage must advertise wayland-drm** (`patches/cage/0004-cage-wl-drm-global.patch`).
   cog hands rendered frames to the compositor via
   `eglCreateWaylandBufferFromImageWL`; Mesa only exposes that extension
   when the compositor advertises the wl_drm global. cage never called
   `wlr_drm_create()` → cog aborted on first frame export.
2. **Mesa must be built with legacy wayland-drm binding**
   (`BR2_PACKAGE_MESA3D_LEGACY_BIND_WAYLAND_DISPLAY=y`). Mesa 26.1 moved
   `EGL_WL_create_wayland_buffer_from_image` behind the `legacy-wayland`
   meson feature; without the knob the extension is compiled out of
   libEGL entirely.
3. **shared-mime-info required** (`BR2_PACKAGE_SHARED_MIME_INFO=y`).
   WebKit resolves `.html` → `text/html` through the freedesktop MIME
   database; QtWebEngine/Chromium hardcodes it. Without the DB, cog
   displayed the raw HTML source as plain text.
4. **wlroots runtime deps are not declared by cage's package**
   (`BR2_PACKAGE_LCMS2=y`, `BR2_PACKAGE_XKEYBOARD_CONFIG=y`). wlroots
   auto-detects lcms2 (color management) and needs xkb data at runtime
   (keymaps); cage's .mk declares neither — add them explicitly.

Debug aids in this variant (all DEBUG-marked, see
`board/rockos/rpi5/DEBUG-REMOVAL-CHECKLIST.md`): dropbear SSH, tty1
root getty via overlay inittab. Known open issue: transient ENOSPC
errors at boot for /var/log, /etc/dropbear, dbus machine-id (tmpfs
mount ordering suspected — under investigation).

## Rollout plan

1. **Spike (this fork):** rpi5 defconfig variant with cog/WPE, keeping
   QtWebEngine commented-not-deleted. Hardware-verify on the rpi5 rig
   (HDMI + DSI panel) and on x86 (QEMU + one bare-metal boot).
2. **Unpin EntropyLab:** once cog passes, drop the v0.1.3 pin and the
   QR backport; track upstream `entropylab.html` directly again.
3. **Upstream PR to SaniExp/RockOS** (after the multi-board PR lands,
   per the agreed incremental strategy):
   - Commit 1: engine swap with zero behavior change (v0.1.3 still
     bundled, proving parity)
   - Commit 2: unpin EntropyLab, delete backport machinery
4. Remove `rockos-browser/` (the qmake project) and its BR2_EXTERNAL
   package.

## Alternatives considered

| Option | Verdict |
|---|---|
| Stay pinned at v0.1.3 forever | Rejected — security tooling should track upstream; backport burden grows |
| Backport wasm secp256k1 fallback upstream | Rejected — upstream deliberately removed it; asking them to weaken the sanity gate for our old engine is not a good-faith PR |
| QtWebEngine 6.x | Not in Buildroot for our targets' toolchain maturity; huge rebuild risk, still Chromium-lagging |
| Firefox/kiosk (Gecko) | Not packaged for Buildroot embedded use; heavier |
| cog + WPE WebKit | **Chosen** — current engine, kiosk-native, already in Buildroot |

## Notes

- The QR-popup backport (`app/patches/`, `scripts/apply-qr-backport.py`)
  was designed to be disposable: delete two files + script, revert the
  README section, done.
- Verified evidence for the Chromium-87 ceiling is in this fork's
  history (2026-09-09 debugging session): CSP behavior, wasm compile
  errors, and the working v0.1.3+backport on rpi5 hardware.
