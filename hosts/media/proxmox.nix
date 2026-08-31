# Proxmox image settings for media.
# Following the app-node pattern: seabios, virtio disk on vmbr0.

{ lib, pkgs, ... }:
{
  # lkl's cptofs hardcodes `mem=100M` and kernel-panics on multi-GB closures
  # ("deadlocked on memory" / cptofs failed). Patch it to a saner size
  # (same overlay as hosts/app-node).
  nixpkgs.overlays = [ (final: prev: {
    lkl = prev.lkl.overrideAttrs (oa: {
      postPatch = (oa.postPatch or "") + ''
        substituteInPlace tools/lkl/cptofs.c --replace-fail 'mem=100M' 'mem=4096M'
      '';
    });
  }) ];

  # Keep the disk small (expansible later when the NAS arrives).
  virtualisation.diskSize = 10240;   # 10G base — expand via Proxmox when needed

  proxmox = {
    qemuConf = {
      bios = "seabios";
      cores = 4;
      memory = 4096;
      net0 = "virtio=00:00:00:00:00:00,bridge=vmbr0,firewall=1";
      additionalSpace = "10G";
      agent = true;
      bootSize = "512M";
      name = "media";
    };
    qemuExtraConf = {
      cpu = "host";
      tags = "nixos,media";
    };
    filenameSuffix = "media";
  };
}