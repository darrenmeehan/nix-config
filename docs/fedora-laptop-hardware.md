# Fedora laptop — keyboard backlight + fingerprint for sudo

Hardware fixes for the Fedora laptop (`darrenmeehan@fedora`, ThinkPad,
standalone Home-Manager under `home/`). Both features are **system-level**:
nix-config installs the tool, the OS-side state is changed once by hand
because standalone Home-Manager has no root.

| Feature | What nix-config owns | What the OS owns (one time) |
| --- | --- | --- |
| Keyboard backlight | `brightnessctl` in `home/home.nix` `home.packages` | udev rule + `video` group |
| Fingerprint → sudo | nothing | `fprintd` enrollment (already installed) |

---

## Why can't Home-Manager manage this?

Home-Manager is a **user-level** tool. Its activation script runs as the
logged-in user and its only writable target is `$HOME` (`~/.config`,
`~/.nix-profile`) plus files it is explicitly pointed at. It never elevates:
there is no `sudo`, no root phase, no system context. Anything outside
`$HOME` is simply out of its reach.

The two things these features need are both root-owned kernel/system state:

| Needed | Owned by | Reachable from HM? |
| --- | --- | --- |
| `/etc/udev/rules.d/*.rules` | root, udev daemon | no — `/etc` is not `$HOME` |
| `usermod -aG video` | root, `/etc/group` + `/etc/gshadow` | no |
| `/sys/class/leds/tpacpi::kbd_backlight/brightness` | kernel, `root:root 0644` at device-add | no |
| `/etc/pam.d/*` (authselect `with-fingerprint`) | root | no |
| system-wide `fprintd.service` | systemd, system bus | no |

That is exactly the gap **NixOS modules** fill: they are evaluated into
`/etc` and run at system activation **as root**, which is why every NixOS
answer to these questions starts with `services.fprintd.enable = true;` or
`services.udev.packages = [ pkgs.brightnessctl ];` — those modules write to
`/etc` and into systemd. Standalone Home-Manager on Fedora has no equivalent
hook, by design (it cannot assume root, and shouldn't).

Second trap specific to non-NixOS distros: **nix store paths are not scanned
for udev rules.** The nixpkgs `brightnessctl` package ships
`$out/lib/udev/rules.d/90-brightnessctl.rules`; on NixOS
`services.udev.packages` links that into `/etc/udev/rules.d`. Fedora's udev
only reads `/usr/lib/udev/rules.d` and `/etc/udev/rules.d`, so installing
`brightnessctl` from `home.packages` gives you the binary **without** the
permission fix — the tool and the grant are separate.

---

## Actual fix

### 1. Keyboard backlight

`thinkpad_acpi` already exposes the device — nothing to enable:

```shell
ls /sys/class/leds/tpacpi::kbd_backlight   # brightness, max_brightness (=2)
```

It is unwritable because it appears `root:root 0644`, and this user is not in
`video`. Fix both:

```shell
sudo tee /etc/udev/rules.d/90-kbd-backlight.rules >/dev/null <<'EOF'
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="tpacpi::kbd_backlight", \
  RUN+="/usr/bin/chgrp video /sys/class/leds/%k/brightness", \
  RUN+="/usr/bin/chmod g+w /sys/class/leds/%k/brightness"
EOF
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=leds
sudo usermod -aG video "$USER"     # log out and back in for the group
```

Then add the tool to `home/home.nix` (`home.packages`, utils block) and
switch:

```nix
brightnessctl
```

```shell
home-switch
brightnessctl --device='tpacpi::kbd_backlight' info
brightnessctl --device='tpacpi::kbd_backlight' set 2    # 0 / 1 / 2
brightnessctl --device='tpacpi::kbd_backlight' set 1-   # step down
```

### 2. Fingerprint for sudo

Already wired — `fprintd` + `fprintd-pam` are installed, authselect's profile
`local` has the `with-fingerprint` feature, so `pam_fprintd.so` sits in
`/etc/pam.d/system-auth` and `/etc/pam.d/sudo` does `auth include system-auth`.
The reader is detected (`06cb:00bd Synaptics Prometheus MIS Touch`).

The only missing part is an enrolled finger:

```shell
fprintd-enroll        # as the user, 5 swipes
fprintd-verify
sudo -k && sudo true  # fingerprint prompt; password still accepted after
```

Remove a finger later with `fprintd-delete "$USER"`.

---

## Verify

```shell
# backlight
ls -l /sys/class/leds/tpacpi::kbd_backlight/brightness   # group video, g+w
brightnessctl --device='tpacpi::kbd_backlight' info
# fingerprint
fprintd-list "$USER"                                     # fingers enrolled
authselect current | grep fingerprint                    # with-fingerprint
grep fprintd /etc/pam.d/system-auth
```

## Gotchas

- **GUI auth prompts stay password-only.** Fingerprint covers sudo and tty
  logins via `system-auth`. There is no `/etc/pam.d/polkit-1` here, so
  polkit dialogs (GNOME Software, GUI admin actions) don't get the reader.
  Create the file with a `pam_fprintd` line if you want those too.
- `pam_faildelay.so 2000000` in `system-auth` adds a 2s pause after a failed
  auth; a mis-swiped finger feels slower than it is.
- `pam_fprintd.so` is `sufficient`, not `required` — password fallback is
  always available, and a fingerprint can't lock you out of sudo.
- The udev rule matches the ThinkPad LED name; it does nothing on another
  vendor's laptop (they'd need their own `KERNEL==` pattern).
- After a distro upgrade re-run the **Verify** block. `dnf upgrade` replaces
  `libfprint`/`fprintd` but never touches `/etc/udev/rules.d` or your
  authselect feature set, so both fixes normally survive — verify rather than
  assume, since a new udev rule dropped by a package can conflict.

## If this laptop ever becomes NixOS

The declarative equivalents, instead of the hand steps above:

```nix
services.fprintd.enable = true;
security.pam.services.sudo.fprintAuth = true;

services.udev.packages = [ pkgs.brightnessctl ];
users.users.darrenmeehan.extraGroups = [ "video" ];
```
