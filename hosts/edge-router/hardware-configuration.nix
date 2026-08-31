# Hardware configuration for the edge-router (CWT N18 Mini PC).
#
# *** DO NOT USE THIS VERBATIM FOR INSTALL *** — it is a deliberately generic
# bootstrap so the router config evaluates on any box (including the CI/dev
# host) for building the ISO. The disk layout is the
# standard NixOS one; the NixOS installer will partition + format the real
# disk at install time.
#
# After installation, regenerate on the target to lock in the real hardware:
#   nixos-generate-config --root /mnt
# then copy the generated hardware-configuration.nix into hosts/edge-router/.

{ config, lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/minimal.nix") ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # No explicit /boot — `nixos-install` handles the boot partition on a
  # fresh sda clash-free automatically for a plain single-disk layout.

  # Placeholder bootloader so `nix build`/`flake check` work before the real
  # hardware config is generated. Regenerate on the box (`nixos-generate-config
  # --root /mnt`) and this gets replaced with the correct GRUB/EFI settings.
  # mkDefault so it doesn't fight the `minimal.nix` profile default.
  boot.loader.grub.enable = lib.mkDefault true;
  boot.loader.grub.device = lib.mkDefault "/dev/sda";       # adjust to real SSD

  swapDevices = [ ];

  # Let any ethernet the box has come up so `ip link` can tell us which port
  # is WAN and which is LAN during the guided setup.
  networking.useDHCP = lib.mkDefault true;
}