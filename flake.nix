{
  description = "Nix Configuration, including Home-Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-colors.url = "github:misterio77/nix-colors";

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

    # Install packages in /etc/profiles
    # Necessary to use 'nixos-rebuild build-vm'
    # home-manager.nixosModules.home-manager.useUserPackages = true;
    # Use the global pkgs that is configured via
    # the system level nixpkgs options
    # home-manager.nixosModules.home-manager.useGlobalPkgs = true;

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
      # FIXME I'm not sure how to allow image creation, along with follow up configuration changes
      # rocinante = nixos-generators.nixosGenerate {
      # format = "proxmox";
      rocinante = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/rocinante
          "${nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"
          ./hosts/rocinante/proxmox.nix
          #   ./home/home.nix
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
        specialArgs = {
          # pkgs = pkgs;
          diskSize = 128 * 1024;
          bootSize = 512;
          memorySize = 1024 * 8;
        };
      };
      # Single-node k3s cluster (curam-fitness app) on Proxmox.
      # See hosts/fitness-node/README.md.
      fitness-node = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/fitness-node
          "${nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"
          ./hosts/fitness-node/proxmox.nix
        ];
      };
    };

    # Home-Manager Configurations (standalone — also the way non-NixOS
    # machines like the Fedora laptop are brought under management)
    homeConfigurations = {
      "mac@personal" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./home/home.nix
          {
            home.username = "mac";
            home.homeDirectory = "/home/mac";
          }
        ];
        # extraSpecialArgs = { inherit nix-colors; };
      };
      "drn@dev" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./home/home.nix
          {
            home.username = "drn";
            home.homeDirectory = "/home/drn";
          }
        ];
      };
      "rocinante" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./home/home.nix
          {
            home.username = "drn";
            home.homeDirectory = "/home/drn";
          }
        ];
      };
      # This Fedora laptop (darrenmeehan@fedora)
      "darrenmeehan@fedora" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./home/home.nix
          # Laptop-specific bits: keep the shell env and git auth that this
          # machine already has, instead of throwing them away on switch.
          {
            home.username = "darrenmeehan";
            home.homeDirectory = "/home/darrenmeehan";

            # Preserve the environment the hand-written ~/.bashrc exports
            programs.bash.bashrcExtra = ''
              . /etc/bashrc
              export ANDROID_HOME=/usr/local/android-sdk
              export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
              export PATH=$PATH:$ANDROID_HOME/platform-tools
              export CAPACITOR_ANDROID_STUDIO_PATH=$ANDROID_HOME/cmdline-tools/latest/bin
              export FLYCTL_INSTALL="/home/darrenmeehan/.fly"
              export PATH="$FLYCTL_INSTALL/bin:$PATH"
              . "$HOME/.cargo/env"
              export PODMAN_COMPOSE_WARNING_LOGS=false
              # bun (was in the hand-written ~/.bash_profile)
              export BUN_INSTALL="$HOME/.bun"
              export PATH="$BUN_INSTALL/bin:$PATH"
              export PATH="/home/darrenmeehan/.local/bin:$PATH"
            '';
          }
        ];
      };
    };

    # Formatter Configuration
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
  };
}
