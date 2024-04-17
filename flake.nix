{
  description = "Nix Configuration, including Home-Manager";

  inputs = {
    # Nixpkgs
    # https://status.nixos.org/
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # FIXME - Others to consider
    # Hardware
    # hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = { nixpkgs, home-manager, ... }@inputs: {

    # Install packages in /etc/profiles
    # Necessary to use 'nixos-rebuild build-vm'
    home-manager.useUserPackages = true;
    # Use the global pkgs that is configured via
    # the system level nixpkgs options
    home-manager.useGlobalPkgs = true;

    # NixOS Configurations
    nixosConfigurations = {
      media = nixpkgs.lib.nixosSystem {
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"
          ./hosts/media/configuration.nix
          ./hosts/media/proxmox.nix
        ];
      };
    };

    # Home-Manager Configurations
    homeConfigurations = {
      "mac@personal" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [ ./home/home.nix ];
      };
    };

    # Formatter Configuration
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
  };
}
