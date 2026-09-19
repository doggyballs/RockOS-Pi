# DEBUG-ONLY artifacts — REMOVE before production / before any upstream PR

This image currently ships a Dropbear SSH server for headless bring-up
debugging (panel / touchscreen / compositor triage on the Pi 5 + Waveshare rig).
It must never ship in a release image. Removal checklist:

- [ ] `config/rockos-rpi5-cog_defconfig` — delete the
      `DEBUG ONLY — REMOVE BEFORE PRODUCTION` block (`BR2_PACKAGE_DROPBEAR=y`)
- [ ] `rockos-overlay-cog/root/.ssh/` — delete the whole directory
      (contains `authorized_keys`); also `rockos-overlay-cog/root/` if empty
- [ ] `rockos-overlay-cog/etc/inittab` — remove the DEBUG getty line
      (`tty1::respawn:/sbin/getty -L tty1 0 vt100`)
- [ ] `git rm` both, verify: `git grep -i dropbear` returns nothing outside
      this file, then delete this file too
- [ ] Rebuild and confirm: `output/host/sbin/debugfs -R "ls /usr/sbin" \
      output/images/rootfs.ext2 | grep -i dropbear` → no match; and
      `debugfs -R "ls /etc/dropbear" ...` → no such dir

Notes:
- Auth is key-only; root has no password (unchanged from base config).
- Added 2026-09-09 during rpi5 bring-up. Tracked in repo AGENTS.md gotchas.
- The `cog-prod` variant already omits all of this; this checklist is for
  the dev `cog` variant only.
