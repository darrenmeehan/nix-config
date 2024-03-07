{
  description = "Nix Configuration, including Home-Manager";

  inputs = {
    # Nixpkgs
    # https://status.nixos.org/
    nixpkgs.url = "github:nixos/nixpkgs/58ae79ea707579c40102ddf62d84b902a987c58b";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # FIXME - Others to consider
    # Hardware
    # hardware.url = "github:nixos/nixos-hardware";
  };

  outputs = { nixpkgs, home-manager, ... }@inputs: {
    # NixOS Configurations
    nixosConfigurations = {
      x1c = nixpkgs.lib.nixosSystem {
        modules = [ ./hosts/x1c/configuration.nix ];
      };
      x13 = nixpkgs.lib.nixosSystem {
        modules = [ ./hosts/x13/configuration.nix ];
      };
    };

    # Home-Manager Configurations
    homeConfigurations = {
      "mac@personal" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [ ./home/home.nix ];
      };
      "timh@x1c" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [ ./home/home.nix ];
      };
      "timh@x13" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [ ./home/home.nix ];
      };
    };

    # Formatter Configuration
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
  };
}
