# Proxmox image settings for app-node.
# Docs (docs/provisioning.md): 40GB virtio disk, 2 cores type host, vmbr0.
# bios = seabios because hosts/app-node/hardware-configuration.nix uses
# SeaBIOS grub on /dev/vda (no EFI) — an ovmf image would be unbootable.

{ config, pkgs, lib, ... }:
{
  # lkl's cptofs hardcodes `mem=100M` and kernel-panics on multi-GB closures
  # ("deadlocked on memory" / cptofs failed). Patch it to a saner size.
  nixpkgs.overlays = [ (final: prev: {
    lkl = prev.lkl.overrideAttrs (oa: {
      postPatch = (oa.postPatch or "") + ''
        substituteInPlace tools/lkl/cptofs.c --replace-fail 'mem=100M' 'mem=4096M'
      '';
    });
  }) ];

  # diskSize lives at the canonical renamed path (was proxmox.qemuConf.diskSize)
  virtualisation.diskSize = 40960; # 40G

  proxmox = {
    qemuConf = {
      bios = "seabios";
      cores = 2;
      memory = 4096;
      net0 = "virtio=00:00:00:00:00:00,bridge=vmbr0,firewall=1";
      additionalSpace = "10G";
      agent = true; # 2026 nixpkgs wants a bool, not "1"
      bootSize = "512M";
      name = "app-node";
    };
    qemuExtraConf = {
      cpu = "host";
      tags = "nixos";
    };
    filenameSuffix = "app-node";
  };
}