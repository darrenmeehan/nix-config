# Hardware configuration for the app-node Proxmox VM.
# SeaBIOS boot on the virtio disk, single ext4 root. The root device is
# /dev/disk/by-label/nixos (matches what both nixos-install and the
# proxmox-image module label the root partition); the mkDefault lets
# proxmox-image override it when building a VMA image.
# If the VM layout differs, regenerate on the VM after install:
#   nixos-generate-config --dir /etc/nixos  # or --show-hardware-config

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  fileSystems."/" = {
    # by-label matches the label nixos-install AND proxmox-image give the root
    # partition; mkDefault so the proxmox-image module can override it for
    # image builds (it defines /dev/disk/by-label/nixos itself).
    device = lib.mkDefault "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };
}