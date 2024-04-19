{ inputs, globals, overlays, ... }:

inputs.nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    globals
    inputs.home-manager.nixosModules.home-manager
    ../../modules/common
    ../../modules/nixos
    "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"
    ./proxmox.nix
    {
      nixpkgs.overlays = overlays;

      networking.hostName = "rocinante";

      # Secrets must be prepared ahead before deploying
      passwordHash = inputs.nixpkgs.lib.fileContents ../../misc/password.sha512;

      # Programs and services
      # atuin.enable = true;
      # charm.enable = true;
      # neovim.enable = true;
      # media.enable = true;
      # dotfiles.enable = true;
      # firefox.enable = true;
      # kitty.enable = true;
      # _1password.enable = true;
      # discord.enable = true;
      # nautilus.enable = true;
      # obsidian.enable = true;
      # mail.enable = true;
      # mail.aerc.enable = true;
      # mail.himalaya.enable = true;
      # keybase.enable = true;
      # mullvad.enable = false;
      # nixlang.enable = true;
      # rust.enable = true;
      # terraform.enable = true;
      # yt-dlp.enable = true;

      services.openssh.enable = true; # Required for Cloudflare tunnel and identity file

    }
  ];
}
