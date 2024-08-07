{ pkgs, ... }:

{
  targets.genericLinux.enable = true;

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  home = {
    # Home Manager release
    stateVersion = "24.05";

    # User info
    username = "mac";
    homeDirectory = "/home/mac";

    # Packages to be installed
    packages = with pkgs; [
      # Utils
      awscli2
      bat # `cat` clone
      bitwarden # Password Manager
      bottom # Display process information (`top` alternative)
      caddy # Web server
      curl # I want a newer version than the one provided by Ubuntu
      dive # Docker image explorer
      du-dust # Disk space usage (`du` alternative)
      eza # File listing (`ls` alternative)
      fd # Find files/folders (`find` alternative)
      feh # Command line image viewer
      flyctl # Fly.io CLI
      gcc # C compiler
      gitleaks # Git repository secrets checker
      htop # Display process information (`top` alternative)
      jq # Command line JSON parser
      just # Command runner
      loco-cli # Loco CLI
      sea-orm-cli # Sea ORM CLI
      neofetch # System information
      nemo # File manager
      nixfmt-classic # Nix formatter
      # nixfmt-rfc-style new RFC 166-style formatter
      niv # Nix dependency management
      nmap # Network exploration
      ripgrep # Fast grep
      ruff # Fast Python linter
      taskwarrior # Task manager
      tig # git text-mode interface
      tcpdump # Network packet analyzer
      tldr # Help pages
      tree # Display directory struture
      wget # Download files

      # For scones.ie
      postgresql_16 # I just want to install libpq - waiting on https://github.com/NixOS/nixpkgs/issues/61580
      libpqxx # C++ library for PostgreSQL. Needed for scones.ie for some reason
      # shell doesnt seem to work
      diesel-cli
      # Apps
      tailscale # VPN
      filezilla # FTP client
      gimp # Image editor
      libreoffice # Office suite
      meld # Diff tools
      vlc # Media player
      yt-dlp # Download videos from YouTube

      # Browsers
      chromium
      # firefox

      # Fonts
      (nerdfonts.override {
        fonts = [
          "DejaVuSansMono"
          "DroidSansMono"
          "FiraCode"
          "Hack"
          "JetBrainsMono"
          "LiberationMono"
          "Terminus"
        ];
      })
      twitter-color-emoji
      noto-fonts-emoji
      powerline-fonts

      podman
      podman-compose

      # Languages
      nodejs
      rustup
      nixd
      nixpkgs-fmt

      ansible-lint
      ansible
      (python311.withPackages (ps: with ps; [
        packer
        pip
        tox
        podman
        podman-compose
        podman-desktop
      ]))

      # FIXME How to add this to menus, with icon?
      signal-desktop # Encryted messaging
      spotify
      vim
      wireshark-cli
      wireguard-go
      zola
    ];
  };
  # Allow fontconfig to discover installed fonts and configurations
  fonts.fontconfig.enable = true;

  # Programs and configurations to be installed
  imports = [
    ./configs/alacritty.nix
    ./configs/autojump.nix
    ./configs/bash.nix
    # ./configs/dconf.nix
    ./configs/direnv.nix
    ./configs/firefox.nix
    ./configs/fzf.nix
    ./configs/gh.nix
    ./configs/git.nix
    ./configs/neovim.nix
    ./configs/polybar.nix
    ./configs/rofi.nix
    ./configs/starship.nix
    ./configs/tmux.nix
    ./configs/vscode.nix
    ./configs/zsh.nix
  ];

  systemd.user.services.polybar = {
    Install.WantedBy = [ "graphical-session.target" ];
  };

}
