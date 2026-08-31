# mgmt — Management Plane (ThinkStation)

UniFi Controller + central Observability (Prometheus + Grafana). Sits **behind**
the edge router as a plain LAN client on `192.168.99.0/24`.

| Plane | Host | IP | Runs |
| --- | --- | --- | --- |
| **Data** | `edge-router` | `192.168.99.1` (static) + WAN DHCP | NAT, Kea DHCP, Unbound DNS, node_exporter |
| **Management** | `mgmt` | `192.168.99.10` (static) | UniFi, Prometheus, Grafana |

## Network state

- Static `192.168.99.10/24` (pinned in `hosts/mgmt/default.nix` — `enp3s0`,
  adjust to your NIC via `ip link`).
- Default gateway + DNS = `192.168.99.1` (the edge router).

## Services

| Service | Port | Bind | Notes |
| --- | --- | --- | --- |
| UniFi Controller | 8443 (UI), 8080 (inform), 10001 (UDP, discovery) | all | `openFirewall = true` |
| Prometheus | 9090 | `192.168.99.10` | scrapes `mgmt:9100` + `edge-router:9100` |
| Grafana | 3000 | `192.168.99.10` | auto-provisioned default datasource = local Prometheus |
| SSH | 22 | all | key-only |

The Prometheus scrape jobs (`job_name: edge-router`) target the router's
node_exporter at `192.168.99.1:9100` — that's how the Data plane reports its
telemetry to the Management plane without running Prometheus itself.

### Open ports

Grafana runs on the LAN NIC (`192.168.99.10:3000`), explicitly opened on the
firewall. UniFi's `openFirewall` adds its own controller ports. Prometheus is
LAN-read only (Grafana talks to it over loopback `localhost:9090`).

## Installing to the ThinkStation SSD

1. Boot any NixOS install media (the `edge-router-iso` builder also works here
   — it's a generic NixOS installer image; you only need the `mgmt` flake attr
   after cloning).
2. Fix `enp3s0` in `hosts/mgmt/default.nix` to the ThinkStation's real NIC
   (`ip link`).
3. Clone the config, mount, and install as `mgmt`:

   ```sh
   git clone https://github.com/<you>/nix-config /root/nix-config
   # format disk to a by-label/nixos layout (see hosts/edge-router/README.md §Install)
   mount /dev/disk/by-label/nixos /mnt
   mkdir -p /mnt/boot && mount /dev/disk/by-label/boot /mnt/boot
   nixos-install --flake /root/nix-config#mgmt --no-root-passwd
   reboot
   ```

> The ISO you boot can be any NixOS installer media (e.g. the
> `edge-router-iso` builder in this flake — it's a generic guided installer; the
> `mgmt` flake attr is what actually gets installed).

> `hardware-configuration.nix` is a generic placeholder (same as the router);
> regenerate on the box after install and commit it.

## Ethernet cabling

```
edge-router LAN (enp2s0) ──> switch ──> ThinkStation (enp3s0, 192.168.99.10)
```

Just plug the ThinkStation into the **LAN-side** switch. The router's Kea DHCP
would assign it `192.168.99.x` automatically, but the config pins the static
`.10` — keep `.10` unused by DHCP (.50-.200 pool is below/above it, so no
clash).

## First-boot orders of business

1. `passwd` — `changeme` is a placeholder for both this host and the router.
2. **UniFi:** open `https://192.168.99.10:8443`, run the setup wizard. Adopt
   your access points through the controller. UniFi APs discover the
   controller on the same broadcast domain (UDP 10001) — for VLAN/subnet
   splits you'd set `inform` and a DNS override on the router.
3. **Grafana:** `http://192.168.99.10:3000` — the Prometheus datasource is
   already provisioned as default, so you can build dashboards immediately.
   `server.root_url` is pinned, so reverse-proxying later only needs that one
   value changed.
   - **Admin login:** the password is **random, generated on first boot** and
     printed once to the journal:
     `journalctl -u grafana-secret -b` (look for `Grafana admin password:`).
     User is `admin`. Change it once logged in (Administration → Users).
     Anonymous access is disabled.
4. **Verify the pipeline:**

   ```sh
   curl -s localhost:9090/api/v1/status/tsdb   # Prometheus up
   curl -s 'localhost:9090/targets' | grep -o '192.168.99.1:9100'   # router target
   ```

## Hardening before leaving the lab

- `allowUnfree` is on for **this host only** (MongoDB ships unfree — required
  by UniFi). Consider an `overlays`-pinned `unifi`/`mongodb` if you want
  reproducible versions.
- Change/subseed the `initialPassword` for the target host before deploy.
- Grafana anonymous auth is already disabled; the admin password is already a
  generated file (no hardcoded creds).
