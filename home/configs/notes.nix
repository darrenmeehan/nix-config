{ pkgs, ... }:
# Obsidian vault kept in step between the Fedora laptop and dev-1 by Syncthing.
#
# Syncthing talks over the tailnet only: no relays, no global or LAN discovery
# and no NAT traversal, so the vault is never announced to public discovery
# servers and every byte moves through Tailscale (MagicDNS names `dev-1` and
# `fedora`). Both machines are on the same LAN, so tailnet transport is still
# direct, not relayed.
#
# Pairing is a one-time manual step per machine: device IDs are generated from
# each host's own key, so they cannot be declared here. On each machine:
#   syncthing --device-id                     # hand this to the other side
#   syncthing cli config devices add \
#     --name dev-1 --device-id <other id> --addresses tcp://dev-1:22000
# then share the vault folder with that device (GUI on 127.0.0.1:8384, reachable
# from the laptop with `ssh -L 8384:127.0.0.1:8384 drn@dev-1`). Folders/devices
# stay out of this file on purpose: the syncthing-init unit would rewrite them
# on every switch and undo the shares.
{
  # syncthing on PATH for the `syncthing cli` pairing commands.
  home.packages = [ pkgs.obsidian pkgs.syncthing ];

  services.syncthing = {
    enable = true;
    settings.options = {
      relaysEnabled = false;
      globalAnnounceEnabled = false;
      localAnnounceEnabled = false;
      natEnabled = false;
    };
  };
}
