# Hardware configuration for media (Proxmox VM).
#
# SeaBIOS boot on the virtio disk, single ext4 root — matches the Proxmox
# seabios image flow used by hosts/app-node. The root device is the
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

  # /data/media is intentionally NOT a mount here — it will be a NAS mount
  # (NFS/SMB) or disk added later; the services only reference the path.
  # networking.useDHCP = lib.mkDefault true;   # VM gets IP from Proxmox DHCP

  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  swapDevices = [ ];
}