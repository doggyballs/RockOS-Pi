# DEBUG-ONLY artifacts — REMOVE before production / before any upstream PR

This image currently ships a Dropbear SSH server for headless bring-up
debugging (panel / touchscreen / weston triage on the Pi 5 + Waveshare rig).
It must never ship in a release image. Removal checklist:

- [ ] `config/rockos-rpi5_defconfig` — delete the
      `DEBUG ONLY — REMOVE BEFORE PRODUCTION` block (`BR2_PACKAGE_DROPBEAR=y`)
- [ ] `rockos-overlay/root/.ssh/` — delete the whole directory
      (contains `authorized_keys`); also `rockos-overlay/root/` if empty
- [ ] `git rm` both, verify: `git grep -i dropbear` returns nothing outside
      this file, then delete this file too
- [ ] Rebuild and confirm: `output/host/sbin/debugfs -R "ls /usr/sbin" \
      output/images/rootfs.ext2 | grep -i dropbear` → no match; and
      `debugfs -R "ls /etc/dropbear" ...` → no such dir

Notes:
- Auth is key-only; root has no password (unchanged from base config).
- Added 2026-09-09 during rpi5 bring-up. Tracked in repo AGENTS.md gotchas.
