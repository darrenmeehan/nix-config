# Nix reference https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/proxmox-image.nix
# PVE reference https://pve.proxmox.com/wiki/Qemu/KVM_Virtual_Machines#qm_virtual_machines_settings

{ config, pkgs, nixpkgs, nix, lib, ... }:
{
  # diskSize lives at the canonical renamed path (was proxmox.qemuConf.diskSize)
  virtualisation.diskSize = 102400; # 100g

  proxmox = {
    qemuConf = {
      # EFI support
      bios = "ovmf";
      cores = 8;
      memory = 8192;
      net0 = "virtio=00:00:00:00:00:00,bridge=vmbr2,firewall=1";
      additionalSpace = "10G";
      agent = true;
      bootSize = "512M";
      name = "rocinante";
    };
    qemuExtraConf = {
      # start the VM automatically on boot
      # onboot = "1";
      cpu = "host";
      tags = "nixos";
    };
    filenameSuffix = "rocinante"; # was "media" (copy-paste from hosts/media)
  };
}
