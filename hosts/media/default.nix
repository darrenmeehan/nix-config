# ============================================================================
# Host — media (Media Server VM on Proxmox)
#
# Jellyfin + the *arr automation stack (Sonarr/Radarr/Prowlarr/Bazarr), with
# Tailscale for remote access. Media lives under /data/media so a NAS can be
# mounted there later without touching any service config.
#
# Sane defaults for a home VM:
#   - Proxmox guest (seabios, virtio disk on vmbr0) — see proxmox.nix
#   - LAN-only firewall + tailscale0 trusted (point-to-point remote access)
#   - shared `media` group so all *arr apps + jellyfin can reach /data/media
#   - stateVersion matches the pinned release (26.11)
# ============================================================================

{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ── Identity ─────────────────────────────────────────────────────────────
  system.stateVersion = "26.11";
  networking.hostName = "media";
  time.timeZone = "Europe/Dublin";

  # ── Network ───────────────────────────────────────────────────────────────
  # DHCP on the Proxmox bridge (same pattern as hosts/media) + Tailscale.
  networking.networkmanager.enable = true;
  services.tailscale.enable = true;

  # ── Shared media user/group ────────────────────────────────────────────────
  # All media services (jellyfin + the *arr apps) run as a single system user
  # `media` so they share one library ownership under /data/media. Avoids
  # per-service user juggling and keeps the NAS-mounted dirs readable by all.
  users.groups.media = { };
  users.users.media = {
    isSystemUser = true;
    group = "media";
    description = "Shared media user (jellyfin + *arr)";
    home = "/var/lib/media";
    createHome = true;
  };

  # ── Media storage (NAS-expandable) ────────────────────────────────────────
  # Services reference /data/media, NOT a specific mount. When a NAS arrives,
  # mount it at /data/media (see README §Adding a NAS) and nothing else moves.
  systemd.tmpfiles.rules = [
    "d /data/media 0775 root media -"
    "d /data/media/movies 0775 root media -"
    "d /data/media/tv 0775 root media -"
    "d /data/media/music 0775 root media -"
    "d /data/media/downloads 0775 root media -"
  ];

  # ── Jellyfin ──────────────────────────────────────────────────────────────
  services.jellyfin = {
    enable = true;
    openFirewall = true;          # starts 8096/tcp
    user = "media";
    group = "media";
    # dataDir defaults to /var/lib/jellyfin (config/log); media is /data/media.
  };

  # ── *arr stack ─────────────────────────────────────────────────────────────
  # Each opens its web UI port on the LAN (and via tailscale0, trusted below).
  services.sonarr = {
    enable = true;
    openFirewall = true;          # 8989
    user = "media";
    group = "media";
    # set download + library root folders in the Sonarr UI (e.g. /data/media/tv)
  };
  services.radarr = {
    enable = true;
    openFirewall = true;          # 7878
    user = "media";
    group = "media";
  };
  services.prowlarr = {
    enable = true;
    openFirewall = true;          # 9696
    # prowlarr uses DynamicUser (no user/group options); grant it the media
    # group so it can read indexers/download paths under /data/media.
  };
  # DynamicUser services need their supplementary group set at the unit level.
  systemd.services.prowlarr.serviceConfig.SupplementaryGroups = [ "media" ];
  services.bazarr = {
    enable = true;
    openFirewall = true;          # 6767
    user = "media";
    group = "media";
  };

  # ── Firewall ──────────────────────────────────────────────────────────────
  # Trust tailscale0 so the box is reachable point-to-point from other tailnet
  # machines; LAN ports are the only other exposure.
  networking.firewall.enable = true;
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  # (jellyfin/sonarr/radarr/prowlarr/bazarr set openFirewall above, which adds
  # their TCP ports; no extra allowedTCPPorts needed here.)

  # ── Management + user ─────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      PubkeyAuthentication = true;
    };
    startWhenNeeded = true;
  };
  users.users.drn = {
    isNormalUser = true;
    extraGroups = [ "wheel" "media" ];
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      # dev machine (darrenmeehan@fedora)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK5LOFpTvGdlomaMjY33qWhvybAVYJLZ9efU6wny2NUq hi@drn.ie"
      # ops (home-k8s, same key the app-node workflow uses)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHSmchQ7JS1UcyBy2lMoYuBQs/6H/VgqB+TrArRE6QDW home-k8s"
    ];
  };

  environment.systemPackages = with pkgs; [
    vim
    curl
    jq
    htop
  ];
}