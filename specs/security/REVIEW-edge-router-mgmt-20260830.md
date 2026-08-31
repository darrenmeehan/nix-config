# Security Review — edge-router / mgmt (NixOS host configs)

- **Date:** 2026-08-30
- **Scope:** `git diff --merge-base origin/HEAD` — `hosts/edge-router/*`, `hosts/mgmt/*`, `docs/planes.md`, `flake.nix`
- **Method:** security-review 5-phase scan (SQLi/XSS/SSRF/SSTI/NoSQLi/etc. are N/A — NixOS declarative config, no application code). Relevant categories: secrets exposure (CWE-798), auth bypass / default credentials (CWE-287).
- **Confidence floor:** ≥ 8. Findings below are all verified against pinned nixpkgs module defaults (`nixpkgs/83199d0`).

## Resolution (2026-08-30)

Both findings fixed in `hosts/mgmt/default.nix`; config re-verified
(`nix flake check` rc=0, mgmt toplevel evaluates):

- **F1 fixed** — `auth.anonymous.enabled = false`; `security.admin_password`
  now `$__file{/etc/grafana/admin_password}` (generated on first boot by the
  extended `grafana-secret` oneshot, printed once to its journal; no
  hardcoded creds, nothing in the Nix store).
- **F2 fixed** — `services.openssh.settings.PasswordAuthentication = false`,
  `PermitRootLogin = "no"`, key-only (`startWhenNeeded`), mirroring the router.

## Findings (≥ 8 confidence)

### F1 — `hosts/mgmt/default.nix` — HIGH — Default credentials + anonymous auth (CWE-798 / CWE-287) — **FIXED**

Grafana is enabled without setting `settings.security.admin_password`, so it ships
the module default `admin/admin` (verified in grafana.nix:853-870 of the pinned
nixpkgs), AND `settings."auth.anonymous".enabled = true` opens the same
management-plane UI to anyone on the LAN.

**Exploit scenario:** any host on `192.168.99.0/24` (the whole LAN is trusted by
the edge router's firewall) reaches `http://192.168.99.10:3000` and logs in as
`admin/admin` → full Grafana control: modify dashboards, add datasources pointing
at arbitrary URLs (Grafana SSRF), export/read all panel queries, plant
dashboards with stored XSS for other admins. The observability plane of the
network is a pivot point.

**Recommendation:** disable anonymous auth and set an admin password via file
provider (never inline — it lands world-readable in the Nix store):

```nix
services.grafana.settings = {
  "auth.anonymous".enabled = false;          # drop LAN convenience
  security.admin_password = "$__file{/etc/grafana/admin_password}";
  # + add /etc/grafana/admin_password to the existing grafana-secret oneshot
  #   (extend it to generate both secret_key and admin_password on first boot)
};
```

### F2 — `hosts/mgmt/default.nix` — HIGH — Known password + SSH password auth (CWE-798 / CWE-287) — **FIXED**

`services.openssh.enable = true` with **no** `PasswordAuthentication = false`,
while the local admin user `drn` is created with `initialPassword = "changeme"`.
NixOS sshd's `PasswordAuthentication` default is `true` (verified
sshd.nix:547-556). The edge router got `PasswordAuthentication = false`
(hosts/edge-router/default.nix:127) — mgmt did not.

**Exploit scenario:** if the operator boots the box and forgets `passwd` (docs
say "change me" but nothing enforces it), any LAN user runs
`ssh drn@192.168.99.10` with the publicly-known password `changeme`. `drn` is in
`wheel` → passwordless-ish sudo → root. The management plane is owned.

**Recommendation:** mirror the router's hardening:

```nix
services.openssh = {
  enable = true;
  settings.PasswordAuthentication = false;
  # keep only pubkey auth (authorizedKeys already present)
};
```

## Suppressed (< 8 confidence / hard exclusions)

| Item | Reason |
| --- | --- |
| `initialPassword = "changeme"` alone (both hosts, routers too) | Folds into F2's fix; console-only risk without password auth; docs already instruct rotation. Score 7 → suppress; addressed by F2. |
| Router node_exporter `9100` and mgmt Prometheus `9090` unauthenticated on LAN | Node/system metrics only; canonical lab pattern. Exclusion #7 (lack of hardening), #2 (not secrets). |
| `nixpkgs.config.allowUnfree = true` (MongoDB) | Not a vuln; dependency availability concern. Exclusion #9. |
| Router SSH reachable from WAN | **Verified safe**: firewall trusts LAN only, WAN inbound denied (no allowedTCPPorts on WAN). No finding. |

## Verified-good

- Router SSH: `PasswordAuthentication = false`, key-only, WAN-blocked.
- Grafana `secret_key`: file provider + first-boot generation (not in Nix store).
- Unbound: interface + access-control restricted to loopback and `192.168.99.0/24`.
- Firewall trust boundary: only the LAN interface is trusted on the router.
