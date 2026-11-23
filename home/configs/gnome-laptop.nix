{ pkgs, ... }:

# Fedora laptop (GNOME/Wayland): no suspend, and no screen lock, while on mains.
#
# Suspend-on-AC is one key. The lock is not: GNOME has a single lock policy for
# both power states (`org.gnome.desktop.screensaver lock-enabled`), so a 30s
# user timer re-applies it whenever the adapter changes. The screen still
# blanks on mains after the normal idle-delay; it just wakes without a password.
let
  acLock = pkgs.writeShellScript "gnome-lock-on-battery" ''
    set -eu
    # dconf, not gsettings: the nix glib only knows stock upstream schema
    # defaults, while the session reads Fedora's vendor overrides.
    dconf=${pkgs.dconf}/bin/dconf
    key=/org/gnome/desktop/screensaver/lock-enabled
    # sysfs AC online: 1 on mains, 0 on battery.
    online=$(cat "''${AC_ONLINE_FILE:-/sys/class/power_supply/AC/online}")
    if [ "$online" = 1 ]; then want=false; else want=true; fi
    [ "$($dconf read $key)" = "$want" ] && exit 0
    $dconf write $key "$want"
  '';
in
{
  # `dconf load` merges into ~/.config/dconf/user, so the settings this
  # machine's GNOME UI already wrote are left alone.
  dconf = {
    enable = true;
    settings."org/gnome/settings-daemon/plugins/power" = {
      # What Settings → Power → Automatic Suspend → Plugged in: Off writes.
      sleep-inactive-ac-type = "nothing";
    };
  };

  systemd.user.services.gnome-lock-on-battery = {
    Unit.Description = "GNOME locks on battery, not on mains";
    Service = {
      Type = "oneshot";
      ExecStart = "${acLock}";
    };
  };

  systemd.user.timers.gnome-lock-on-battery = {
    Unit.Description = "Re-check mains/battery for the GNOME lock policy";
    Timer = {
      OnActiveSec = "10s";
      OnUnitActiveSec = "30s";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
