# Hardware configuration for mgmt (ThinkStation).
#
# *** DO NOT USE THIS VERBATIM FOR INSTALL *** — deliberately generic so the
# config evaluates on any host for building. After install, regenerate on the
# target:
#   nixos-generate-config --root /mnt
# and copy the generated hardware-configuration.nix into hosts/mgmt/.

{ config, lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/minimal.nix") ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  swapDevices = [ ];

  # Placeholder bootloader so `nix build`/`flake check` work before the real
  # hardware config is generated on the ThinkStation. mkDefault so it doesn't
  # fight the `minimal.nix` profile default.
  boot.loader.grub.enable = lib.mkDefault true;
  boot.loader.grub.device = lib.mkDefault "/dev/sda";

  # DHCP placeholder so the NIC is up during guided install; the real static
  # IP is forced in default.nix.
  networking.useDHCP = lib.mkDefault true;
}