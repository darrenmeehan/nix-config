# Data Plane vs Management Plane — two hosts, one VLAN

New home-lab networking stricture: the **data plane** (routing, DHCP, DNS,
NAT) and the **management plane** (UniFi controller + observability) run on
**separate physical hosts**. Keeps a router rebuild from taking the UniFi
controller and dashboards down, and vice versa.

## The two hosts

```
                    ┌──────────────────────────────────────────────┐
   ISP modem/       │ DATA PLANE — edge-router (CWT N18 Mini PC)   │
   gateway ─WAN/DHCP─│   NAT · Kea DHCP · Unbound DNS · node_exporter │
                    └──────────────┬───────────────────────────────┘
                                   │ LAN 192.168.99.1/24 (trusted)
                                   │
                    ┌──────────────▼───────────────────────────────┐
                    │ MANAGEMENT PLANE — mgmt (ThinkStation)        │
                    │   UniFi · Prometheus · Grafana               │
                    │   192.168.99.10/24                           │
                    └──────────────────────────────────────────────┘
```

| | `edge-router` | `mgmt` |
| --- | --- | --- |
| Plane | **Data** | **Management** |
| Hardware | CWT N18 Mini PC | ThinkStation |
| IP | WAN: DHCP client · LAN `192.168.99.1/24` | static `192.168.99.10/24` |
| Services | Kea DHCP, Unbound DNS, NAT, node_exporter | UniFi, Prometheus, Grafana |
| Config dir | `hosts/edge-router/` | `hosts/mgmt/` |
| Build artifacts | USB ISO | none (plain `nixos-rebuild`) |

## How they talk

- **DNS:** LAN clients get `domain-name-servers = 192.168.99.1` from Kea, so
  everything resolves through Unbound on the router.
- **Telemetry:** the router exports Prometheus metrics on `192.168.99.1:9100`;
  Prometheus on `mgmt` scrapes it (`job_name: edge-router`). The router runs
  **no** Prometheus/Grafana by design.
- **UniFi adoption:** same broadcast domain, so APs discover the controller
  on `mgmt` via UDP 10001. The router's DHCP doesn't hand out `.10` (it's
  above the `.50-.200` pool), so `mgmt`'s static IP never clashed.

## Build & test loop (dev machine only — never `switch` to this laptop)

```sh
# build the router's USB installer ISO
nix build .#edge-router-iso

# dry-eval any host without applying anything (safe, read-only)
nix eval .#nixosConfigurations.mgmt.config.networking.hostName
```

> The two hosts are added under `nixosConfigurations.{edge-router,mgmt}` and
> the artifacts under `packages.x86_64-linux` in `flake.nix`. Building them
> never touches this development machine — only `nixos-rebuild` on the target
> box does.

## Full bring-up sequence

1. **Build the router ISO** → write to USB → boot the CWT N18 → install
   `#edge-router` (see `hosts/edge-router/README.md`).
2. **Plug in the cables** (exact mapping in each host README):
   ISP gateway → router WAN port; switch → router LAN port; ThinkStation →
   switch.
3. Router comes up: Kea hands out `192.168.99.50-200`, Unbound resolves,
   NAT works. Verify from a LAN client (`nslookup`, `curl` out).
4. **Install `mgmt`** (ThinkStation): plug into the switch, boot installer,
   `nixos-install --flake ...#mgmt` (see `hosts/mgmt/README.md`).
5. UniFi wizard on `https://192.168.99.10:8443`, adopt APs. Grafana on
   `http://192.168.99.10:3000`, then build dashboards against the
   pre-provisioned Prometheus datasource (scraping both hosts).

## Maintenance

```sh
# push config changes to a target host (run on that host, or via ssh)
nixos-rebuild switch --flake /etc/nixos#<edge-router|mgmt>

# rebuild the router ISO after any config change
nix build .#edge-router-iso
```

Repos aside, the two host configs are fully self-documenting with their own
readmes; this file is just the "why two boxes" map for the network.
