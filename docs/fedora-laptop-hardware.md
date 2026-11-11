# Fedora laptop — keyboard backlight + fingerprint for sudo

Hardware fixes for the Fedora laptop (`darrenmeehan@fedora`, ThinkPad,
standalone Home-Manager under `home/`). Both features are **system-level**:
nix-config installs the tool, the OS-side state is changed once by hand
because standalone Home-Manager has no root.

| Feature | What nix-config owns | What the OS owns (one time) |
| --- | --- | --- |
| Keyboard backlight | `scripts/kbd-backlight` (toggle) | udev rule (`scripts/setup-laptop-hardware.sh`) |
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
| `usermod -aG video` (not needed — `wheel` is used) | root, `/etc/group` + `/etc/gshadow` | no |
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
`video`. The fix is the script in this repo:

```shell
sudo ./scripts/setup-laptop-hardware.sh
```

It is idempotent and self-verifying. What it does, if you'd rather do it by
hand:

```shell
sudo tee /etc/udev/rules.d/90-kbd-backlight.rules >/dev/null <<'EOF'
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="tpacpi::kbd_backlight", \
  RUN+="/usr/bin/chgrp wheel /sys/class/leds/%k/brightness", \
  RUN+="/usr/bin/chmod g+w /sys/class/leds/%k/brightness"
EOF
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=leds
sudo chgrp wheel /sys/class/leds/tpacpi::kbd_backlight/brightness   # live device
sudo chmod g+w   /sys/class/leds/tpacpi::kbd_backlight/brightness
```

`wheel`, not `video`: this user is already in `wheel`, so there is no
`usermod` and no log-out/in round trip. Wheel members can already `sudo`, so
it grants no new privilege.

Toggle it with `scripts/kbd-backlight` (symlinked into `~/.local/bin` by the
setup script):

```shell
kbd-backlight        # cycle 0 -> 1 -> 2 -> 0
kbd-backlight 2      # set a level
```

Bind it in GNOME: Settings → Keyboard → Custom Shortcuts, command
`kbd-backlight`. To make **Fn+Space** itself work, set the shortcut's
accelerator to the `XF86KbdLightOnOff` keysym (GNOME Settings can't capture Fn
combos, but it accepts the keysym if set directly):

```shell
# adds a custom shortcut bound to the same key Fn+Space emits
base=org.gnome.settings-daemon.plugins.media-keys.custom-keybinding
path=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/kbd-backlight/
gsettings set ${base}:${path} name 'Keyboard backlight'
gsettings set ${base}:${path} command 'kbd-backlight'
gsettings set ${base}:${path} binding 'XF86KbdLightOnOff'
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
  "['${path}']"
```

Why Fn+Space does nothing today: the key reaches userspace (`ThinkPad Extra
Buttons`, `event5`) as `XF86KbdLightOnOff`, GNOME's static handler
(`keyboard-brightness-toggle-static`) forwards it to upower's
`KbdBacklight` interface — which in upower 1.x has no `Brightness` property,
so it is a silent no-op. The custom shortcut above bypasses upower entirely.

### Using an unused function key instead

Any key that reaches userspace can be bound instead. Measured on this machine
(`sudo showkey -k` on a VT, Ctrl+Alt+F3):

| Pressed | keycode | kernel name | XKB keysym |
| --- | --- | --- | --- |
| F10 | 68 | `KEY_F10` | `F10` |
| Fn+F10 (phone icon) | 445 | `KEY_PICKUP_PHONE` | `XF86PickupPhone` |
| Fn+Space | 228 | `KEY_KBDILLUMTOGGLE` | `XF86KbdLightOnOff` |

The phone key maps to `XF86PickupPhone` (`/usr/share/X11/xkb/symbols/inet:355`,
`key <I453>`), not `XF86Phone` — `KEY_PHONE` (169) is a different key. Nothing
in GNOME claims it (`gsettings list-recursively org.gnome.shell.keybindings |
grep -i phone` is empty), the layout is `ie` and the evdev ruleset appends
`+inet(evdev)` (`/usr/share/X11/xkb/rules/evdev:378`), so the keysym exists;
the name is present in `libxkbcommon`, so GTK/`gsd-media-keys` can parse it as
an accelerator.

Use the same gsettings block with `binding 'XF86PickupPhone'` for Fn+F10, or
`binding 'XF86KbdLightOnOff'` for Fn+Space.

A keycode-level remap (making the key emit something else everywhere, not
just in GNOME) needs hwdb under `/etc/udev/hwdb.d/` — root, and `keyd` is not
in the Fedora 45 repos anyway. For a backlight toggle the GNOME shortcut is
enough. `brightnessctl` is optional sugar for `info` / `set 1+` (add it to
`home.packages` if you want it). `set 1+` clamps at max, so it cannot toggle —
hence the script.

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
ls -l /sys/class/leds/tpacpi::kbd_backlight/brightness   # group wheel, g+w
kbd-backlight 1 && kbd-backlight 0                      # toggle works
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
