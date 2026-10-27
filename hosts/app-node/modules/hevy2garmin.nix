# Hevy → Garmin workout sync on a schedule.
#
# Runs `hevy2garmin sync` (from the fitness repo, via uv) every 2 hours as a
# systemd timer. Credentials come from /run/secrets/hevy-env (sops-decrypted);
# the CLI reuses cached Garmin tokens in ~/.garminconnect and dedups against
# ~/.hevy2garmin/sync.db.
#
# The whole module is gated on secrets/hevy-env.yaml existing, so committing
# it does not affect `make deploy-app-node` until that secret is added.
#
# One-time bootstrap (also in hosts/app-node/README.md → "Hevy → Garmin sync"):
#   1. sops secrets/hevy-env.yaml with HEVY_API_KEY / GARMIN_EMAIL / GARMIN_PASSWORD
#   2. app-node's age key at /home/darren/.config/sops/age/keys.txt — same key
#      the curam secrets already use (sops.age.keyFile below)
#   3. Copy ~/.garminconnect and ~/.hevy2garmin from the dev machine once — a
#      fresh sync.db would re-upload old workouts as Garmin duplicates
#   4. Git access to the fitness repo for clone/pull on the box (private repo
#      ⇒ SSH deploy key or PAT for the darren account)
#
# hevy2garmin is not packaged in nixpkgs, so there is no derivation to pin;
# the repo's own uv project runs exactly like on the laptop. uv downloads its
# own Python unless UV_PYTHON points at the nixpkgs interpreter (set below).
{ config, lib, pkgs, ... }:

let
  repoUrl = "git@github.com:darrenmeehan/fitness.git"; # private repo → SSH deploy key on the box
  checkoutDir = "/srv/fitness";
  serviceUser = "darren";
  serviceGroup = "users";
in
lib.mkIf (builtins.pathExists ../../../secrets/hevy-env.yaml) {
  sops.age.keyFile = "/home/${serviceUser}/.config/sops/age/keys.txt";

  sops.secrets.hevy-env = {
    sopsFile = ../../../secrets/hevy-env.yaml;
    owner = serviceUser;
    group = serviceGroup;
    mode = "0400";
  };

  systemd.services.hevy2garmin-sync = {
    description = "Sync Hevy workouts to Garmin Connect";
    after = [ "network-online.target" "sops-nix.service" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.git pkgs.uv pkgs.python313 ];
    serviceConfig = {
      Type = "oneshot";
      User = serviceUser;
      Group = serviceGroup;
      WorkingDirectory = checkoutDir;
      EnvironmentFile = "/run/secrets/hevy-env";
      Environment = [ "UV_PYTHON=${pkgs.python313}/bin/python3" ];
      TimeoutStartSec = 600;
      Nice = 10;
    };
    script = ''
      if [ ! -d "${checkoutDir}/.git" ]; then
        git clone "${repoUrl}" "${checkoutDir}"
      else
        git -C "${checkoutDir}" pull --ff-only >/dev/null 2>&1 || true
      fi
      cd "${checkoutDir}"
      uv run hevy2garmin sync
    '';
  };

  systemd.timers.hevy2garmin-sync = {
    description = "Run hevy2garmin sync every 2 hours";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 0/2:00:00"; # every 2h on the hour
      Persistent = true; # catch up after downtime
      RandomizedDelaySec = 600; # avoid stampeding with autoUpgrade at 04:00
    };
  };
}
