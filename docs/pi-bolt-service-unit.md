# `pi-bolt service install` writes a unit systemd rejects

**Status:** upstream bug in pi-bolt 1.2.1 (unit generator); the fix below has
to be re-applied after every `pi-bolt service install`.
**Last checked:** 2026-11-15, on dev-1 (NixOS 26.11, pi-bolt 1.2.1, systemd from
nixpkgs `f4a03c0`).

## Symptom

`pi-bolt service install` appears to work, then fails at the restart step:

```text
$ pi-bolt service install --no-tunnel
Set remoteControl.service.tunnel to "off": the service serves the local
network and Tailscale only.
Error: systemctl --user restart pi-bolt-remote-control.service failed (1):
Failed to restart pi-bolt-remote-control.service: Unit
pi-bolt-remote-control.service has a bad unit file setting.
```

`systemctl --user status pi-bolt-remote-control.service` says
`Loaded: bad-setting (Reason: Unit … has a bad unit file setting.)`, and the
user journal names the line:

```text
pi-bolt-remote-control.service:8: WorkingDirectory= path is not absolute: "/home/drn"
Unit configuration has fatal error, unit will not be started.
```

## Root cause

The generated `~/.config/systemd/user/pi-bolt-remote-control.service` quotes a
path setting:

```ini
WorkingDirectory="/home/drn"
```

systemd does not strip quotes from path-type settings — the value it parses is
the literal string `"/home/drn"`, quotes included, which is therefore not an
absolute path and is a fatal unit error.

Quoting `ExecStart=` is fine (it is an argv list) and is not the problem:

```ini
ExecStart="/run/current-system/sw/bin/pi-bolt" "service" "run"
```

## Fix

```sh
sed -i "s|^WorkingDirectory=.*|WorkingDirectory=/home/drn|" \
  ~/.config/systemd/user/pi-bolt-remote-control.service
systemctl --user daemon-reload
systemctl --user restart pi-bolt-remote-control.service
```

Then check it is actually serving:

```sh
systemctl --user status pi-bolt-remote-control.service   # active (running)
ss -ltn | grep 48123                                     # LISTEN on 0.0.0.0:48123
pi-bolt service status                                   # local + tailscale addresses, pairing link
```

## Notes

- Re-running `pi-bolt service install` (for example after an update) rewrites
  the unit and brings the quotes back. `grep WorkingDirectory
  ~/.config/systemd/user/pi-bolt-remote-control.service` is the one-line check.
- A pristine copy of the broken unit is kept as
  `pi-bolt-remote-control.service.orig` on dev-1, for an upstream report.
- `ExecStart` names `/run/current-system/sw/bin/pi-bolt`, not a `/nix/store`
  path, so a pi-bolt upgrade does not leave the unit pointing at a store path
  that GC can delete. The running daemon keeps the old code until it is
  restarted — which is what the day-2 switch on dev-1 does at the end.
- The service is a **systemd --user** unit, so it needs
  `users.users.<user>.linger = true` on a headless box; without lingering the
  user manager only exists while an SSH session does.
