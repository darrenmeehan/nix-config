# Hardware configuration for dev-1 (Proxmox VM).
#
# SeaBIOS boot on the virtio disk, single ext4 root — matches the Proxmox image
# flow used by hosts/media and hosts/app-node. The root device is the
# by-label/nixos that proxmox-image gives the VM; mkDefault lets that module
# override it for VMA image builds.

{ config, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  fileSystems."/" = {
    device = lib.mkDefault "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  swapDevices = [ ];
}
