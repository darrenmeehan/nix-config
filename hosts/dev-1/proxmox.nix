# Proxmox image settings for dev-1.
# Same image flow as hosts/media and hosts/app-node: seabios + virtio disk on
# vmbr0, so hardware-configuration.nix's grub on /dev/vda boots it.

{ lib, pkgs, ... }:
{
  # lkl's cptofs hardcodes `mem=100M` and kernel-panics on multi-GB closures
  # ("deadlocked on memory" / cptofs failed). Patch it to a saner size (same
  # overlay as hosts/media, hosts/app-node).
  nixpkgs.overlays = [
    (final: prev: {
      lkl = prev.lkl.overrideAttrs (oa: {
        postPatch = (oa.postPatch or "") + ''
          substituteInPlace tools/lkl/cptofs.c --replace-fail 'mem=100M' 'mem=4096M'
        '';
      });
    })
  ];

  # 100G: cargo target dirs, node_modules and docker images all live here.
  # Grow it in Proxmox later (docs/disk-resize.md) if that runs out.
  virtualisation.diskSize = 102400;

  proxmox = {
    qemuConf = {
      bios = "seabios";
      # Big enough for rustc/lld link steps and a docker build side by side.
      cores = 8;
      memory = 16384;
      # Distinct MAC: two VMs sharing one on vmbr0 fight over the address.
      net0 = "virtio=02:00:00:00:00:03,bridge=vmbr0,firewall=1";
      additionalSpace = "10G";
      agent = true;
      bootSize = "512M";
      name = "dev-1";
    };
    qemuExtraConf = {
      cpu = "host";
      tags = "nixos,pi";
    };
    filenameSuffix = "dev-1";
  };
}
