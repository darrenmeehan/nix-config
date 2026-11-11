#!/usr/bin/env bash
# One-time, root-level setup for the Fedora laptop's hardware bits that
# Home-Manager cannot own (see docs/fedora-laptop-hardware.md):
#   - group-write on the ThinkPad keyboard-backlight LED, via udev
#   - kbd-backlight toggle on PATH
#   - reports what is left to do for the fingerprint reader (per-user enroll)
#
# Idempotent: safe to re-run. Run with sudo, from the repo root:
#   sudo ./scripts/setup-laptop-hardware.sh
#
# Why not Nix: /etc/udev and /sys are root-owned; standalone Home-Manager
# runs as the user and only writes $HOME.

set -euo pipefail

RULE=/etc/udev/rules.d/90-kbd-backlight.rules
LED=tpacpi::kbd_backlight
LED_PATH=/sys/class/leds/$LED/brightness
# wheel, not video: the user is already in it, so no usermod + re-login.
# wheel members can sudo anyway, so this grants no new privilege.
GROUP=wheel

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Run with sudo: sudo $0" >&2
    exit 1
fi

TARGET_USER=${SUDO_USER:-}
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = root ]; then
    echo "❌ Run via sudo from your own account (SUDO_USER is unset)" >&2
    exit 1
fi
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

echo "==> udev rule: $RULE"
cat >"$RULE" <<EOF
# Keyboard backlight writable by group $GROUP (ThinkPad). Managed by
# nix-config/scripts/setup-laptop-hardware.sh — see docs/fedora-laptop-hardware.md
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="$LED", \\
  RUN+="/usr/bin/chgrp $GROUP /sys/class/leds/%k/brightness", \\
  RUN+="/usr/bin/chmod g+w /sys/class/leds/%k/brightness"
EOF

echo "==> Reloading udev and re-triggering leds"
udevadm control --reload
udevadm trigger --subsystem-match=leds
# the RUN+= rules fire on device add; apply to the live device now
chgrp "$GROUP" "$LED_PATH"
chmod g+w "$LED_PATH"

echo "==> Installing kbd-backlight into $USER_HOME/.local/bin"
REPO=$(cd "$(dirname "$0")/.." && pwd)
install -d -o "$TARGET_USER" -g "$(id -gn "$TARGET_USER")" "$USER_HOME/.local/bin"
ln -sf "$REPO/scripts/kbd-backlight" "$USER_HOME/.local/bin/kbd-backlight"
chmod +x "$REPO/scripts/kbd-backlight"

echo "==> Verifying"
fail=0
if [ ! -f "$RULE" ]; then
    echo "❌ rule file missing"
    fail=1
fi
if ! sudo -u "$TARGET_USER" test -w "$LED_PATH"; then
    echo "❌ $TARGET_USER cannot write $LED_PATH (group $(id -gn "$TARGET_USER") not in $GROUP?)"
    fail=1
fi
sudo -u "$TARGET_USER" bash -lc 'command -v kbd-backlight' >/dev/null ||
    echo "⚠ kbd-backlight not on $TARGET_USER PATH — check ~/.local/bin is exported"
[ "$fail" -eq 0 ] && echo "✅ keyboard backlight controllable by $TARGET_USER"

cat <<EOF

Still per-user (no root needed, cannot be scripted — needs your finger):
  fprintd-enroll          # 5 swipes; fprintd + pam_fprintd are already wired
  fprintd-verify
  sudo -k && sudo true    # confirm the prompt

Bind the toggle: GNOME Settings → Keyboard → Custom Shortcuts
  name:    keyboard backlight
  command: kbd-backlight
EOF
