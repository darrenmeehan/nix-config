{
  description = "Nix Configuration for all my systems";

  # Other flakes to pull from
  inputs = {
    # System packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # User packages and dotfiles
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Community packages; used for Firefox extensions
    nur.url = "github:nix-community/nur";

    # Wallpapers
    wallpapers = {
      url = "gitlab:exorcist365/wallpapers";
      flake = false;
    };

    # Firefox addon from outside the extension store
    bypass-paywalls-clean = {
      # https://gitlab.com/magnolia1234/bpc-uploads/-/commits/master/?ref_type=HEADS
      url = "https://github.com/bpc-clone/bpc_updates/releases/download/latest/bypass_paywalls_clean-latest.xpi";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:

    let

      # Global configuration for my systems
      globals =
        let
          baseName = "drn.ie";
        in
        rec {
          user = "drn";
          fullName = "Darren Meehan";
          gitName = "Darren Meehan";
          gitEmail = "hi@drn.ie";
          # dotfilesRepo = "https://github.com/darrenmeehan/dotfiles";
          hostnames = {
            git = "git.${baseName}";
            paperless = "paper.${baseName}";
            secrets = "vault.${baseName}";
            stream = "stream.${baseName}";
          };
        };

      # Common overlays to always use
      overlays = [
        inputs.nur.overlay
      ];

      # System types to support.
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    rec {
      nixosConfigurations = {
        rocinante = import ./hosts/rocinante { inherit inputs globals overlays; };
        media = import ./hosts/media { inherit inputs globals overlays; };
      };

      # Home-Manager Configurations
      homeConfigurations = {
        rocinante = nixosConfigurations.rocinante.config.home-manager.users.${globals.user}.home;
        "mac@personal" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [ ./home/home.nix ];
        };
      };
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

    };
}
