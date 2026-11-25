# dev-1

A Proxmox VM on the LAN whose job is to keep pi running when the laptop is not.

The agent process lives on the VM inside herdr, whose background server keeps
the terminals running when the client exits, and its session files live in
`~/.pi/agent/sessions` on the VM's disk. A closed lid, a dropped SSH connection
or the laptop going to sleep stops nothing: reconnect, run `herdr`, reattach to
the same pane. That is the whole durability story.

It is also the general dev box for rust / npm / fly / docker work.

| | |
| --- | --- |
| Hostname | `dev-1` |
| User | `drn` (wheel, docker) — key-only SSH, password from `passwd` |
| Disk / RAM / cores | 100G / 16G / 8 (`proxmox.nix`) |
| Bridge | `vmbr0`, DHCP, MAC `02:00:00:00:00:03` |
| Reachable by | SSH 22 and Pi-Bolt remote control 48123, on the LAN and over Tailscale |
| Boot | SeaBIOS + grub on `/dev/vda` (`hardware-configuration.nix`) |

## Specs

Measured against the actual Proxmox host (i7-8700T, 6 cores / 12 threads,
62G RAM, ~50G free; thin pool `local-lvm` 349G with ~324G free):

| Resource | Value | Why |
| --- | --- | --- |
| cores | 8 | ≤ the host's 12 threads, so nothing is truly oversubscribed. `cargo build` saturates whatever it gets; PVE time-shares the bursts with `lisheen` and `app-node`. |
| memory | 16G | rustc + lld spike to several GB per process; `-j8` on a big crate is comfortable here without squeezing the host. |
| zram | 8G (half of RAM) | `default.nix`: the VM has no disk swap, so without it a link that outruns RAM gets OOM-killed. Compressed in-memory swap beats that and costs no disk. |
| disk | 100G thin | `cargo target/` (tens of GB), `node_modules`, docker images. Thin-provisioned on `local-lvm`, so it costs only what is written. Grow it later with `docs/disk-resize.md`. |
| cpu type | `host` | rustc picks up AVX2 etc. — a `kvm64` CPU makes rust and node builds notably slower. |

Rust is a build-bound workload: cores and disk IO matter, RAM matters when
`-j` is high. If builds feel slow rather than blocked, the lever is the
toolchain (mold/lld linker, `sccache`), not more vCPU on a 35W 8th-gen chip.

## Where to run what

Three machines are involved: **laptop** (this repo, has Nix + flakes),
**pve** (the Proxmox host), and **dev-1** (the VM, which does not exist until
pve restores the image). Nothing here runs on pve as NixOS config — pve only
runs `qm*`.

| Command | Runs on | Notes |
| --- | --- | --- |
| `nix build .#nixosConfigurations.dev-1.config.system.build.VMA` | laptop, repo root | builds into `result/`; the VM cannot build its own image |
| `scp result/vzdump-qemu-dev-1.vma.zst root@pve:/var/lib/vz/dump/` | laptop | push the image to pve |
| `qmrestore … 200 --storage local-lvm`, `qm start 200`, `qm set 200 --onboot 1` | **pve** (or `ssh root@pve '<cmd>'` from the laptop) | Proxmox commands, not NixOS |
| `make provision-vm PROVISION_HOST=dev-1 VMID=200` | laptop, repo root | the three rows above in one step — use it *instead of* them |
| `qm guest cmd 200 network-get-interfaces` | pve, or `ssh root@pve '…'` | to find the VM's DHCP address |
| `passwd`, `git clone … ~/code/nix-config` | **dev-1**, over `ssh drn@<ip>` | first login only |
| `scp -r ~/.pi/agent/… dev-1:~/.pi/agent/` | laptop | needs the ssh alias below to have a real `HostName` |
| `sudo nixos-rebuild switch --flake ~/code/nix-config#dev-1` | **dev-1** | day-2: pull the VM's own checkout, then switch. Follow with `pi-bolt service restart` |
| `rebuild-dev` (shell alias) | laptop, anywhere | escape hatch only: builds the local tree and activates it over ssh. Normal path is on the VM. Asks for drn's sudo password. |
| `ssh -t dev-1 herdr` | laptop | daily use — the herdr server runs on dev-1 |

## Deploy (first time)

Same "no ISO" VMA flow as `media` and `app-node`, scripted:

```shell
make provision-vm PROVISION_HOST=dev-1 VMID=200
# builds .#nixosConfigurations.dev-1.system.build.VMA, scp's it to pve,
# refuses an existing VMID, restores and starts the VM
```

Doing it by hand, and the two things worth knowing:

```shell
nix build .#nixosConfigurations.dev-1.config.system.build.VMA
# → result/vzdump-qemu-dev-1.vma.zst  (~1.5–2.5G compressed)
#   the first build compiles pi-bolt from source: allow 10+ minutes

scp result/vzdump-qemu-dev-1.vma.zst root@pve:/var/lib/vz/dump/

# on pve — 100/101/202 are taken, so 200:
qmrestore /var/lib/vz/dump/vzdump-qemu-dev-1.vma.zst 200 --storage local-lvm
qm start 200
qm set 200 --onboot 1        # optional: come back after a host reboot
```

- `/var/lib/vz` is on `pve-root`, which is **95% full (5.3G free)** — check it
  before uploading, and pass `--storage local-lvm` explicitly on restore,
  because `local` holds backups/ISOs only, no VM images.
- `qm guest cmd 200 network-get-interfaces` (or the DHCP leases) gives the IP.
  `proxmox-image` leaves `networking.hostName` empty on purpose and cloud-init
  names the box after the Proxmox VM name, so give the laptop an alias rather
  than relying on DNS:

```
Host dev-1
  HostName 192.168.68.<ip>
  User drn
```

## First login

```shell
ssh drn@dev-1
passwd            # replace the bootstrap hash from git
git clone <this repo> ~/code/nix-config   # the VM switches from this checkout
sudo tailscale up   # prints a URL; approve the device in the tailnet
```

Bring pi's own config over from the laptop — it is plain JSON/Markdown, and
carrying it keeps the models, packages (extensions/skills) and provider
credentials identical on both machines:

```shell
# from the laptop
scp -r ~/.pi/agent/{settings.json,auth.json,AGENTS.md} dev-1:~/.pi/agent/
scp -r ~/.pi/agent/skills ~/.pi/agent/agents dev-1:~/.pi/agent/ 2>/dev/null
```

The provider key rides along in `auth.json` (`openrouter: { type: "api_key",
key: "sk-or-…" }`, mode 0600). Prefer a **separate OpenRouter key named
`dev-1`** with its own credit limit over reusing the laptop's: this box is
reachable from a phone, so it should be revocable on its own. Either copy
`auth.json` as above, or run `pi` on the VM and use `/login` → OpenRouter to
paste the key there. Check it with `pi auth check --provider openrouter`.

Never put the key in Nix: the store is world-readable. If it should be
declarative, this flake already carries `sops-nix` (app-node uses it) — decrypt
to `/run/secrets` and export `OPENROUTER_API_KEY` from a login hook, which is
the one env var path pi honours. `environment.variables` would leak it into
`/nix/store`.

pi's own config is **declared, not hand-edited**: `~/.pi/agent/settings.json`
and `~/.pi/agent/extensions/guardrails.json` come from home-manager
(`hosts/dev-1/pi.nix`), built from the file both machines share —
[`pkgs/pi-bolt/pi-config.nix`](../../pkgs/pi-bolt/pi-config.nix). One list, two
consumers, so the boxes cannot drift: the laptop takes the default
(`pi-curam-security = true`), dev-1 passes `pi-curam-security = false`.

`pi-bolt` itself is built here with the same four extensions the laptop
compiles in — `@aliou/pi-guardrails`, `@heyhuynhgiabuu/pi-diff`,
`@melihmucuk/leash`, `@mjasnikovs/pi-task` — plus the pi-bolt-only
`opensec-pi-{todo,fff,subagents}` pulled from npm at run time. Same nixpkgs
(the flake's single `nixos-unstable` lock) and the same
`pkgs/pi-bolt/package.nix` as the laptop, so it is the same Pi-Bolt release.

Two deliberate differences from the laptop build:

- **`cpu` stays baseline.** The laptop uses `cpu = "native"` because it builds
  and runs locally; this image is built on the laptop and run on the Proxmox
  host's CPU, so a native build would tie it to the build machine.
  `jitSupport = true` is kept, because `opensec-pi-fff` reaches its native
  library through `bun:ffi`.
- **`remoteControl.enabled = true`** is in the declared settings (the laptop
  leaves it off). A store-path settings file is read-only, so
  `pi-bolt remote-control enable` cannot persist anything here — change it in
  `hosts/dev-1/pi.nix` and rebuild on the VM.

Both files are store paths, so `pi` cannot save settings changes on this box
either (`/model` shows the change but does not keep it). That is the same
trade-off as the laptop.

## Day-2

On the VM, from its own checkout:

```shell
cd ~/code/nix-config && git pull
sudo nixos-rebuild switch --flake .#dev-1
pi-bolt service restart   # re-exec the new binary; no-op if the service is uninstalled
```

## Working on it from the laptop

```shell
ssh -t dev-1 herdr               # runs herdr; the server outlives the client
# detach with Ctrl-b q — pi keeps running
```

Same herdr you already run on the laptop (`home/home.nix`), so the prefix keys
and layout carry over, and pi-bolt's own herdr support (pane prompts,
agent state) is what guardrails talks to.

How it holds up: herdr's server keeps terminals alive across client exit and
SSH loss; a server or VM reboot restores the saved layout and resumes supported
agent sessions (pi resumes from its session files), but the original processes
do not survive a reboot — a run mid-tool-call at that moment is lost. herdr's
`ui.toast.delivery = "system"` silently no-ops over SSH (no `notify-send`
target); leave toasts in-app.

Running `pi` directly in a plain SSH shell does not survive the laptop; running
it in a herdr pane does.

## Remote control from the phone

`pi-bolt` ships phone control itself, so there is nothing custom here — the box
is only wired so it *works headless*, which is the part that otherwise looks
broken:

| Piece | Why it is in `default.nix` |
| --- | --- |
| `users.users.drn.linger = true` | `pi-bolt service` is a **systemd --user** unit. Without lingering the user manager only lives as long as an SSH session, so the phone would lose the box the moment you close the laptop. |
| `networking.firewall.allowedTCPPorts = [ 48123 ]` | the service listens on every interface at `remoteControl.port`, 48123 when unset — reachable on the LAN (phone at home, over Wi-Fi). |
| `networking.firewall.trustedInterfaces = [ "tailscale0" ]` + `services.tailscale.enable` | the same 48123 over the tailnet when you are away. A stable `100.x` address, unlike a Cloudflare quick tunnel that hands out a new hostname on every restart. |

`remoteControl.enabled` is already declared in `hosts/dev-1/pi.nix` (a
store-path settings file cannot be written by `pi-bolt remote-control enable`).
What is left is the unit:

```shell
pi-bolt service install --no-tunnel  # systemd --user unit; LAN + tailnet only, no Cloudflare
# ^ writes a unit systemd refuses: see docs/pi-bolt-service-unit.md, then:
sed -i "s|^WorkingDirectory=.*|WorkingDirectory=$HOME|" \
  ~/.config/systemd/user/pi-bolt-remote-control.service
systemctl --user daemon-reload && systemctl --user restart pi-bolt-remote-control.service
pi-bolt service status               # addresses + paired phones
pi-bolt service pair --link          # prints a pairing link to paste into the app
```

Confirmed working on dev-1 (2026-11-15): `active (running)`, listening on
`0.0.0.0:48123`, reachable at `ws://192.168.68.131:48123/rc` and
`ws://100.118.37.99:48123/rc` (tailnet), `Linger=yes`.

App: <https://pi-bolt.opensec.in/android>. `--link` is the point: a QR code is
awkward through SSH, and the link pairs one phone within ten minutes.

What a paired phone can do is what you can do typing into pi: prompt, steer,
queue, abort, answer dialogs, switch model, and read-only review (git status,
diff, log, files). So guardrails decisions land on a small screen — that is the
one thing to be deliberate about. Revoke with `/remote-control devices`;
`remoteControl.readSecretFiles` stays `false`, so `.env`, keys and `auth.json`
are withheld from the review views.

Two settings are per-user and mutable, not Nix: `remoteControl.enabled` (the
command above) and `remoteControl.port` (leave it 0 — 48123 is the default and
already open).

**Two unit-level gotchas.** `WorkingDirectory=` comes out quoted
(`WorkingDirectory="/home/drn"`), which systemd rejects as "path is not
absolute" — [`docs/pi-bolt-service-unit.md`](../../docs/pi-bolt-service-unit.md)
has the symptom, the root cause and the `sed` fix; every `pi-bolt service
install` re-breaks it. Separately, the running daemon keeps the code it started
with, so the day-2 switch ends with `pi-bolt service restart` to re-exec the new
binary (a no-op when the service is not installed). `ExecStart` names
`/run/current-system/sw/bin/pi-bolt`, so an upgrade cannot leave it pointing at
a GC'd store path.

Not done: the unit is machine-local (`systemctl --user cat
pi-bolt-remote-control`), not declared here. Declaring it would need
`systemd.user.services.*` with the exact arguments `service install` writes, and
guessing those is worse than the restart line.

## Toolchains

- **Rust** — none installed globally, by design. Each repo carries its own
  devShell: `nix flake init -t ~/code/nix-config#rust`, `direnv allow`, and
  `rustc`/`cargo`/`rust-analyzer`/`clippy` come from that flake. See
  `templates/rust/README.md`.
- **npm/node** — `nodejs_26` (npm included).
- **fly** — `flyctl`.
- **docker** — `virtualisation.docker`, `drn` in the `docker` group, weekly
  auto-prune. Compose is `docker-compose`.

## Not configured on purpose

- **Port forwarding / Cloudflare tunnels** — Tailscale is on (for the phone),
  but no router ports are opened and no third party carries the traffic.
- **`pi-bolt service` as a declared unit** — machine-local by design; see the
  wart above.
- **autoUpgrade** — a dev box should not rebuild itself mid-task; switching is
  explicit (`nixos-rebuild switch` on the VM).
- **Global rust toolchain** — AGENTS.md: never. The VM follows the same rule as
  every other machine here.
