# ── Federated docs hub ───────────────────────────────────────────────────────
# Every project's docs/ is aggregated into one Zola site, rebuilt from the
# source working trees and published read-only over Tailscale. Sources and the
# site live in docs-hub/ in this repository; the generated site lives under this
# user's data directory, never in git.
#
# The sync runs as a system unit working as `drn` (the repos are in
# /home/drn/code and the site is in /home/drn/.local/share), so it does not
# depend on lingering or on Tailscale operator state: `tailscale serve` runs as
# root. Manual runs (as drn, `hub-sync` on PATH) write to the same root, so a
# manual trigger updates exactly what is being served.
{ config, lib, pkgs, ... }:

let
  hubSync = pkgs.callPackage ../../pkgs/docs-hub.nix { };
  hubRoot = "/home/drn/.local/share/docs-hub";
  tailscale = "${pkgs.tailscale}/bin/tailscale";
in
{
  environment.systemPackages = [ hubSync ];

  systemd.services.docs-hub-sync = {
    description = "Stage project docs into the hub site and rebuild it";
    # Local sources only need the filesystem; a remote source that fails one
    # round (no network yet) is warned about and retried by the next timer tick,
    # which is why this deliberately does not wait on network-online.target
    # (disabled on this host anyway — see default.nix).
    serviceConfig = {
      Type = "oneshot";
      User = "drn";
      Environment = [
        "HOME=/home/drn"
        "DOCS_HUB_ROOT=${hubRoot}"
      ];
    };
  };

  systemd.timers.docs-hub-sync = {
    description = "Rebuild the docs hub every five minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
    };
  };

  # Its own tailnet HTTPS port, so the hand-made serve paths on 443/8080/9000
  # (/docs, /cve) are left exactly as they are. tailscale serve keeps this
  # config in tailscaled's state, hence the plain oneshot + restart on failure.
  systemd.services.docs-hub-serve = {
    description = "Serve the docs hub on the tailnet (https :8443)";
    after = [
      "tailscale.service"
      "docs-hub-sync.service"
    ];
    wants = [ "docs-hub-sync.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "30s";
    };
    script = ''
      ${tailscale} serve --bg --https=8443 --set-path=/ ${hubRoot}/public
    '';
  };
}
