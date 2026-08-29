# Hardware configuration for the fitness-node Proxmox VM.
# Generated-style config matching the documented install flow
# (docs/provisioning.md): SeaBIOS boot on /dev/vda, single ext4 root.
# If the VM layout differs, regenerate on the VM after install:
#   nixos-generate-config --dir /etc/nixos  # or --show-hardware-config

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };
}