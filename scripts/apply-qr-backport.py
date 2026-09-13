#!/usr/bin/env python3
"""Apply the RockOS PR-255 QR-popup backport to a pristine EntropyLab HTML.

Usage:
    scripts/apply-qr-backport.py <input.html> <output.html>

What it does:
  1. Injects app/patches/qr-references.css before the last </style> in <head>
  2. Injects app/vendor/uqr-0.1.3.js (export statement stripped) +
     app/patches/qr-references.js as an inline <script> before </body>

Idempotent: refuses to patch a file that already contains the backport
(marker: 'qr-ref-overlay' string), so re-running on an already-patched
file fails loudly instead of double-injecting.

Why this exists: upstream EntropyLab main (post 2026-09-03) requires
WebAssembly reference-types and ES2022 (Object.hasOwn), which QtWebEngine
5.15 (Chromium 87) cannot run — its secp256k1 sanity check hard-fails.
RockOS pins v0.1.3 (last compatible build) and backports just the
offline-QR module (pure DOM + uqr, no wasm) so air-gapped users still
get scannable reference links. See README "Updating EntropyLab".
"""

import re
import sys
from pathlib import Path

ROCKOS_DIR = Path(__file__).resolve().parent.parent
CSS_FILE = ROCKOS_DIR / "app" / "patches" / "qr-references.css"
JS_FILE = ROCKOS_DIR / "app" / "patches" / "qr-references.js"
UQR_FILE = ROCKOS_DIR / "app" / "vendor" / "uqr-0.1.3.js"

MARKER = "qr-ref-overlay"


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2

    src_path, dst_path = Path(sys.argv[1]), Path(sys.argv[2])
    html = src_path.read_text(encoding="utf-8")

    if MARKER in html:
        print(f"ERROR: {src_path} already contains the QR backport "
              f"(found '{MARKER}'). Refusing to double-patch.", file=sys.stderr)
        return 1

    css = CSS_FILE.read_text(encoding="utf-8")
    js = JS_FILE.read_text(encoding="utf-8")
    uqr = UQR_FILE.read_text(encoding="utf-8")

    # Strip uqr's ESM export statement (single line at end of file) so
    # renderSVG stays in plain script scope for the backport module.
    uqr_stripped, n = re.subn(r"export \{[^}]*\}\s*;?\s*$", "", uqr)
    if n != 1:
        print("ERROR: could not strip uqr export statement — "
              "vendored file unexpected shape", file=sys.stderr)
        return 1

    # CSS: before the last </style> within <head>
    head_end = html.find("</head>")
    if head_end < 0:
        print("ERROR: no </head> found", file=sys.stderr)
        return 1
    style_close = html.rfind("</style>", 0, head_end)
    if style_close < 0:
        print("ERROR: no </style> found in <head>", file=sys.stderr)
        return 1
    html = html[:style_close] + css + html[style_close:]

    # JS: single inline script just before </body>
    body_close = html.rfind("</body>")
    if body_close < 0:
        print("ERROR: no </body> found", file=sys.stderr)
        return 1
    inject = "<script>\n" + uqr_stripped + "\n" + js + "\n</script>\n"
    html = html[:body_close] + inject + html[body_close:]

    dst_path.write_text(html, encoding="utf-8")
    print(f"OK: {dst_path} ({len(html)} bytes, "
          f"{html.count('qr-ref')} qr-ref markers)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
