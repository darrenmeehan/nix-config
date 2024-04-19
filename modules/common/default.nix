{ config, lib, pkgs, ... }: {

  imports =
    [ ./shell ];

  options = {
    user = lib.mkOption {
      type = lib.types.str;
      description = "Primary user of the system";
    };
    fullName = lib.mkOption {
      type = lib.types.str;
      description = "Human readable name of the user";
    };
    userDirs = {
      # Required to prevent infinite recursion when referenced by himalaya
      download = lib.mkOption {
        type = lib.types.str;
        description = "XDG directory for downloads";
        default =
          if pkgs.stdenv.isDarwin then "$HOME/Downloads" else "$HOME/downloads";
      };
    };
    identityFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to existing private key file.";
      default = "/etc/ssh/ssh_host_ed25519_key";
    };
    unfreePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of unfree packages to allow.";
      default = [ ];
    };
    hostnames = {
      git = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for git server (Gitea).";
      };
      metrics = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for metrics server.";
      };
      minecraft = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for Minecraft server.";
      };
      paperless = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for document server (paperless-ngx).";
      };
      prometheus = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for Prometheus server.";
      };
      influxdb = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for InfluxDB2 server.";
      };
      secrets = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for passwords and secrets (Vaultwarden).";
      };
      stream = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for video/media library (Jellyfin).";
      };
      content = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for personal content system (Nextcloud).";
      };
      books = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for books library (Calibre-Web).";
      };
      download = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for download services.";
      };
      irc = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for IRC services.";
      };
      transmission = lib.mkOption {
        type = lib.types.str;
        description = "Hostname for peer2peer downloads (Transmission).";
      };
    };
  };

  config =
    let stateVersion = "24.05";
    in {

      # Basic common system packages for all devices
      environment.systemPackages = with pkgs; [ git vim wget curl ];

      home-manager = {
        # Use the system-level nixpkgs instead of Home Manager's
        useGlobalPkgs = true;

        # Install packages to /etc/profiles instead of ~/.nix-profile, useful when
        # using multiple profiles for one user
        useUserPackages = true;
        # Pin a state version to prevent warnings
        users.drn.home.stateVersion = stateVersion;
        users.root.home.stateVersion = stateVersion;
      };

      # Allow specified unfree packages (identified elsewhere)
      # Retrieves package object based on string name
      nixpkgs.config.allowUnfreePredicate = pkg:
        builtins.elem (lib.getName pkg) config.unfreePackages;

    };

}
