#!/bin/sh
# RockOS-Pi dev deploy: build entropylab.html and push it to the Pi kiosk.
#
# Usage: ./scripts/dev-deploy.sh [pi-ip]
#
# App-only change loop — no image rebuild, no reflashing.
# Requires: dev (cog) image running on the Pi with dropbear SSH up.

set -eu

PI_IP="${1:-192.168.30.5}"
KEY="${HOME}/.ssh/doggyballs"
EL_DIR="${HOME}/doggyballs/entropylab"

echo "=== building entropylab.html ==="
cd "$EL_DIR"
npm run build >/dev/null 2>&1

echo "=== pushing to ${PI_IP} ==="
scp -i "$KEY" -o IdentitiesOnly=yes -o ConnectTimeout=5 \
    entropylab.html "root@${PI_IP}:/opt/rockos/app/entropylab.html"

echo "=== restarting kiosk ==="
ssh -i "$KEY" -o IdentitiesOnly=yes "root@${PI_IP}" \
    "kill \$(cat /run/cage.pid 2>/dev/null) 2>/dev/null; sleep 1; /etc/init.d/S99rockos restart" \
    || ssh -i "$KEY" -o IdentitiesOnly=yes "root@${PI_IP}" "reboot"

echo "=== deployed: kiosk restarting ==="
