# media — Media Server (Proxmox VM)

Jellyfin + the *arr automation stack (Sonarr, Radarr, Prowlarr, Bazarr), with
Tailscale for remote access. Hosted on Proxmox (hostname `media`).

| Service | Port | Purpose |
| --- | --- | --- |
| Jellyfin | 8096 | Media server (movies/TV/music) |
| Sonarr | 8989 | TV show automation |
| Radarr | 7878 | Movie automation |
| Prowlarr | 9696 | Indexer management (shared by Sonarr/Radarr) |
| Bazarr | 6767 | Subtitle management |
| SSH | 22 | key-only |

All media services run as a single system user `media` and share
**`/data/media`** as the library root. LAN-only firewall + `tailscale0` trusted
(see §External access — Tailscale).

## Deploy to Proxmox (VMA image)

Same flow as `app-node`/`media`/`rocinante` (repo README → "New Proxmox VM
setup"):

```sh
nix build .#nixosConfigurations.media.config.system.build.VMA
# → result/vzdump-qemu-media.vma.zst

scp result/vzdump-qemu-media.vma.zst root@pve:/var/lib/vz/dump/
# on pve:
qmrestore vzdump-qemu-media.vma.zst <vmid> --unique true
qm start <vmid>
```

VM shape (from `hosts/media/proxmox.nix`): seabios, 4 cores, 4 GB RAM,
virtio disk on `vmbr0`, ~20 GB (10G + additionalSpace). **Keep the disk small —
storage lives at `/data/media`, which is where the NAS plugs in.**

After boot: `ssh drn@<vm-ip>` (find it in the Proxmox summary; DHCP). The box
uses NetworkManager DHCP like `hosts/media`.

## Adding a NAS (expand storage later)

The services never reference a specific mount — they all point at
`/data/media`. To move storage onto a NAS:

1. Mount the NAS at `/data/media` (represents services /data/media path):

   ```nix
   # hosts/media/default.nix →
   fileSystems."/data/media" = {
     device = "nas.local:/srv/media";      # NFS example
     fsType = "nfs";
     options = [ "nofail" "x-systemd.automount" ];  # boot even if NAS is down
     # or SMB:  fsType = "cifs"; options = [ "nofail" "x-systemd.automount" "credentials=/etc/nas-secret" ];
   };
   ```

2. Ensure the NAS export grants the VM read/write (UID of `media` — check with
   `id media` on the box; on an NFS export use `anonuid`/`anongid` or a
   matching UID/GID).
3. `nixos-rebuild switch --flake /etc/nixos#media` — nothing else changes.
   The `clear`/`downloads` subdirs get created by tmpfiles on the mounted path.

Existing files just need `chown -R media:media` once after the first sync onto
the NAS.

## Setting up an Amazon Firestick to connect to Jellyfin

**On the same LAN (couch test):**

1. From the Firestick home, install the **Jellyfin** app from the Amazon
   Appstore (search "Jellyfin").
2. Open Jellyfin → **Add server manually**.
3. Server address: `http://<jellyfin-ip>:8096` — find the IP with
   `nmcli -p device show` on the box or the Proxmox summary (e.g.
   `http://192.168.99.20:8096`).
4. Log in with the username/password you created on first Jellyfin setup
   (`http://<jellyfin-ip>:8096/web` on a laptop to create the account).

**Off-LAN (from anywhere — see §External access):**

1. Install the **Tailscale** app on the Firestick. It isn't on the Appstore, so
   sideload it:
   - Install the **Downloader** app from the Appstore.
   - `https://pkgs.tailscale.com/stable/#android` → download the APK → install.
2. Open Tailscale → **Sign in** → approve the device (see §Tailscale auth).
3. Open Jellyfin → **Add server manually** → use the **MagicDNS name**:
   `http://jellyfin:8096` (Tailscale resolves `jellyfin` from the device's
   hostname). Or use the box's tailnet IP `http://100.x.y.z:8096`.
4. Login and stream. Jellyfin transcodes on the server; whether the Firestick
   direct-plays depends on your media/bandwidth — the server handles that.

> The Firestick joins **only the tailnet** (via the Tailscale app) — it is
> granted access **only to `jellyfin:8096`** (ACL below), never to the rest of
> your network.

## External access — Tailscale (point-to-point)

People outside your home reach Jellyfin through **Tailscale** (WireGuard), not
by opening ports on the edge router. **No port forwarding, no DMZ.** The media
box runs `services.tailscale.enable = true` and the firewall trusts
`tailscale0`.

### Model: per-machine auth, point-to-point ACLs

- **Every device is its own identity.** A friend installs Tailscale on *their*
  device and you **approve that specific device** in your tailnet — there is no
  shared "guest login". Revoking = unapprove/remove one device, nothing else.
- **Tailnet ACLs restrict what each device can reach** (Tailscale admin console
  → Access controls → policy file). A device may only reach the **one host and
  port** it needs — point-to-point, not blanket tailnet access.
- **`node expiry` / device expiry** on by default — approved devices that go
  stale stop connecting after the window, so old approvals rot away.

### Suggested ACL policy (point-to-point)

Tailscale admin console → **Access controls**. This gives **jellyfin** access
only to `jellyfin.host` port 8096, and keeps your own machines' default
allow:

```jsonc
{
  "acls": [
    // Your own machines: unrestricted within the tailnet (default).
    { "action": "accept", "src": ["tag:owner"], "dst": ["*:*"] },
    // Everyone else (guests): Jellyfin ONLY — no host but jellyfin, no port but 8096.
    { "action": "accept", "src": ["autogroup:member"], "dst": ["jellyfin:8096"] }
  ],
  "tagOwners": { "tag:owner": ["your@email.com"] }
  // Tag your own machines (jellyfin, edge-router, mgmt, …) with tag:owner in
  // the Devices tab — this stops autogroup:member from reaching anything else.
  // Optionally add "ssh": [] if you don't want Tailscale SSH.
}
```

Effect: a guest's device can reach **only** `jellyfin:8096`. It cannot touch
the edge router, mgmt/Prometheus, app-node, or other guests' traffic.

### Approving a friend (the only per-person step)

1. They install Tailscale (phone/laptop/streaming stick) and sign in with
   their own account; they join your tailnet (they need a link from your
   tailnet or they request access — you approve).
2. In the admin console → **Machines** → approve their device.
3. Done — the ACL already limits them to Jellyfin.

### Tailscale on the server

```nix
# hosts/media/default.nix
services.tailscale.enable = true;
networking.firewall.trustedInterfaces = [ "tailscale0" ];
```

First start: `sudo tailscale up` on the box and approve its device from your
tailnet (it'll be tagged `tag:owner`).

### Security notes

- Tailscale traffic is end-to-end encrypted (WireGuard); the guest's device
  gets your tailnet's DNS + a **NAT'd 100.x IP** — your LAN stays hidden.
- **Never** set `tailscale up --advertise-exit-node` or share routes for the
  jellyfin box — that would turn guests into VPN exit points. Point-to-point
  only (the ACL already prevents exit-node misuse from guests).
- Jellyfin auth is still on top: guests need the Jellyfin account you create
  for them. For small numbers of trusted people, one shared family account is
  fine; the ACL is the real boundary.

## Maintenance

```sh
ssh drn@media        # or via tailscale: ssh drn@media
nixos-rebuild switch --flake /etc/nixos#media   # on the box after git pull
journalctl -u jellyfin -f
```

## Hardening before leaving the lab

- `passwd` — `changeme` is a placeholder for `drn`.
- Create the Jellyfin admin account on first run; add per-person accounts for
  guests (don't share one forever).
- Set up a download client in Sonarr/Radarr (e.g. Transmission or qBittorrent
  on this box or a NAS container) and point its download dir at
  `/data/media/downloads`. The arr apps expect that layout.
