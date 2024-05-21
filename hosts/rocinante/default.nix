# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports = [ ];

  users.users.drn = {
    home = "/home/drn";
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    initialHashedPassword = "$y$j9T$Ua3zZctnVLe2shI6PbePh0$PGsx86ZGX/x8yu6lg4fWeB6VKL1LaL2qEyh89q4imeA";
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKCothD9QCHn87gI2Mkcuoj7h9OKnlzN8icUe+bSx2Fz hi@drn.ie" ];
    packages = with pkgs; [
      curl
      parted
      vim
    ];
  };
  networking.hostName = "rocinante";
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  time.timeZone = "Europe/Dublin";
  services = {
    # Enable Qemu guest support as this is a VM on Proxmox.
    qemuGuest.enable = true;
    # Enable systemd-networkd
    # allowing cloud-init to set up network interfaces on boot. 
    # cloud-init.network.enable = true;
    openssh.enable = true;
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
  ];

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

}

