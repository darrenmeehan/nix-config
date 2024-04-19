{
  description = "Nix Configuration, including Home-Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { self, nixpkgs, home-manager, nixos-generators, ... }@inputs: {

    # # Install packages in /etc/profiles
    # # Necessary to use 'nixos-rebuild build-vm'
    # home-manager.useUserPackages = true;
    # # Use the global pkgs that is configured via
    # # the system level nixpkgs options
    # home-manager.useGlobalPkgs = true;

    # NixOS Configurations
    nixosConfigurations = {
      media = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"
          ./hosts/media
          ./hosts/media/proxmox.nix
          {
            nixpkgs.hostPlatform = "x86_64-linux";
          }
        ];
      };
      # FIXME Not working
      # rocinante = nixos-generators.nixosGenerate {

        rocinante = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/rocinante
          "${nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"
          ./hosts/rocinante/proxmox.nix
          ./home
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.drn = { pkgs, ... }: {
                home.homeDirectory = "/home/drn";
                home = {
                  username = "drn";
                  stateVersion = "24.05";
                };
              };
            };
          }
        ];
        # format = "proxmox";
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
