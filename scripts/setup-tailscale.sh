#!/usr/bin/env bash
# One-time, root-level setup for Tailscale on the Fedora laptop. See
# docs/fedora-laptop-tailscale.md.
#
# Client and daemon both come from dnf, not Nix: tailscaled is a root systemd
# unit and standalone Home-Manager has no root, so a nix-shipped tailscaled
# cannot be started, and a nix-shipped `tailscale` would shadow the dnf client
# and talk to the daemon across a version gap.
#
# Idempotent: safe to re-run. Run with sudo, from the repo root:
#   sudo ./scripts/setup-tailscale.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Run with sudo: sudo $0" >&2
    exit 1
fi

echo "==> Installing tailscale (dnf)"
dnf install -y tailscale

echo "==> Enabling tailscaled"
systemctl enable --now tailscaled

# The tailnet interface is trusted, matching the other hosts: the VPN does the
# authenticating, so firewalld does not need to filter tailscale0.
if systemctl is-active --quiet firewalld; then
    echo "==> Trusting tailscale0 in firewalld"
    firewall-cmd --zone=trusted --add-interface=tailscale0 || true
    firewall-cmd --permanent --zone=trusted --add-interface=tailscale0 || true
else
    echo "==> firewalld not running, skipping firewall zone"
fi

if tailscale status --json 2>/dev/null | grep -q '"BackendState": "Running"'; then
    echo "==> Already authenticated"
    tailscale status | head -5
else
    echo "==> Not authenticated yet"
    if [ -t 0 ]; then
        # Blocks until you approve the URL it prints.
        tailscale up
        firewall-cmd --zone=trusted --add-interface=tailscale0 >/dev/null 2>&1 || true
    else
        echo "    Run this yourself and approve the URL it prints:"
        echo "      sudo tailscale up"
    fi
fi

echo "==> Verifying"
fail=0
systemctl is-active --quiet tailscaled || {
    echo "❌ tailscaled not active"
    fail=1
}
command -v tailscale >/dev/null || {
    echo "❌ tailscale client missing from PATH"
    fail=1
}
[ "$fail" -eq 0 ] && echo "✅ tailscaled running; 'sudo tailscale up' to join the tailnet"
exit "$fail"
