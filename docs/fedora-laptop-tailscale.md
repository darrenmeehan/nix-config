# Tailscale on the Fedora laptop — client + daemon via dnf

Tailscale on `darrenmeehan@fedora` is **not** installed by Nix. Nix-config owns
the *decision* (the comment in `home/home.nix`, this page, the setup script);
dnf owns the two binaries.

```shell
sudo ./scripts/setup-tailscale.sh   # install + enable tailscaled + trust tailscale0
sudo tailscale up                   # approve the URL once, per device
```

---

## Why dnf and not Nix

Everything in `home/home.nix` is user-level: Home-Manager's activation runs as
you and only writes `$HOME`. Tailscale on Linux is two pieces:

| Piece | Needs | Reachable from standalone HM? |
| --- | --- | --- |
| `tailscale` (client) | a binary on `$PATH` | yes |
| `tailscaled` (daemon) | root, `/dev/net/tun`, a **system** systemd unit | no |

So Nix can supply the client and never the daemon — which is what this machine
had until now: `~/.nix-profile/bin/tailscale` present, `tailscaled.service` not
found, `tailscale status` → "failed to connect to local tailscaled".

Splitting them is worse than it sounds. The client talks to the daemon over
a local API whose flags move between releases; a nix client (1.104.6 today)
driving a dnf daemon (1.102.5 today) is a pair that only roughly matches,
and `tailscale up` is exactly the kind of call that takes a version-specific
flag. Hence `tailscale` was removed from `home/home.nix` (NixOS hosts still
get it from `services.tailscale.enable`'s `systemPackages`) and dnf installs
both halves here, so they always move together on `dnf upgrade`.

The alternative — pointing a hand-written system unit at
`/home/darrenmeehan/.nix-profile/bin/tailscaled` — is rejected: the path is
per-user, it breaks when the profile generation changes, and on Fedora
(selinux enforcing) a root service executing a binary under `user_home_t`
is not something to bet the daemon on.

## What the script does

1. `dnf install -y tailscale`
2. `systemctl enable --now tailscaled`
3. `firewall-cmd --zone=trusted --add-interface=tailscale0` (live + permanent,
   skipped when firewalld is off) — the same trust `hosts/app-node`,
   `hosts/dev-1` and `hosts/media` grant, so the laptop is reachable
   point-to-point from other tailnet devices
4. `tailscale up` when a terminal is attached, otherwise prints it for you
5. verifies the daemon is active and the client is on `PATH`

No exit node, no subnet routes, no `--ssh`: this laptop is a leaf client. Add
those deliberately, not by default.

## Verify

```shell
systemctl status tailscaled --no-pager      # active (running)
tailscale status                            # your devices; this one online
tailscale ping mgmt                         # direct path to another host
ip -brief addr show tailscale0              # 100.x.y.z
```

## Gotchas

- **`tailscale up` is interactive** — it prints an auth URL and waits. Approve
  the device in the admin console, or pass a pre-authenticated `--auth-key`.
- **After `dnf upgrade`** re-run the Verify block. The rpm upgrades both halves
  together, so skew is not the risk; a moved unit file or a reset
  `tailscaled.state` is. Re-running the setup script is a no-op when healthy.
- **State lives in `/var/lib/tailscale/tailscaled.state`**, not in this repo.
  Re-provisioning the machine means a fresh device — delete the old one in the
  console instead of trying to copy state.
- **Taildrop/file receiving** needs the trusted-zone step; without it incoming
  connections from the tailnet hit firewalld.
- **MagicDNS names** need MagicDNS enabled in the tailnet's DNS settings; the
  client cannot turn that on locally.

## If this laptop ever becomes NixOS

```nix
services.tailscale.enable = true;
networking.firewall.trustedInterfaces = [ "tailscale0" ];
```

and drop `scripts/setup-tailscale.sh` — the module writes the unit, adds the
client to `systemPackages`, and `tailscale up` stays a one-time manual step.
