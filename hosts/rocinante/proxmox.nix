# Nix reference https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/proxmox-image.nix
# PVE reference https://pve.proxmox.com/wiki/Qemu/KVM_Virtual_Machines#qm_virtual_machines_settings

{ ... }:
{
  proxmox = {
    qemuConf = {
      # EFI support
      bios = "ovmf";
      cores = 6;
      memory = 8192;
      net0 = "virtio=00:00:00:00:00:00,bridge=vmbr2,firewall=1";
      diskSize = "102400"; # 10g
      additionalSpace = "10G";
      agent = "1";
      bootSize = "512M";
      name = "rocinante";
    };
    qemuExtraConf = {
      # start the VM automatically on boot
      # onboot = "1";
      cpu = "host";
      tags = "nixos";
    };
    filenameSuffix = "rocinante";
  };
}
