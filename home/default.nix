{ config, pkgs, ... }:

{
    # FIXME Move into file for non NixOS machines only
#   targets.genericLinux.enable = true;

  programs.zsh.enable = true;

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

#   # Let Home Manager install and manage itself
#   programs.home-manager.enable = true;

  system.stateVersion = "24.05";
  home-manager.users.drn.home = {
    # Home Manager release
    stateVersion = "24.05";

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
      gitleaks # Git repository secrets checker
      htop # Display process information (`top` alternative)
      jq # Command line JSON parser
      neofetch # System information
      nixfmt-classic # Nix formatter
      # nixfmt-rfc-style new RFC 166-style formatter
      niv # Nix dependency management
      nmap # Network exploration
      ripgrep # Fast grep
      ruff # Fast Python linter
      taskwarrior # Task manager
      tig # git text-mode interface
      tldr # Help pages
      tree # Display directory struture

      # Apps
      filezilla # FTP client
      gimp # Image editor
      libreoffice # Office suite
      meld # Diff tools
      vlc # Media player

      # Browsers
      chromium
      firefox

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

      # Node
      nodejs

      terraform

      # Python
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
    ];
  };
  # Allow fontconfig to discover installed fonts and configurations
  fonts.fontconfig.enable = true;



  # Programs and configurations to be installed
  imports = [
    # ./configs/alacritty.nix
    # ./configs/autojump.nix
    # ./configs/bash.nix
    # ./configs/dconf.nix
    # ./configs/direnv.nix
    # ./configs/firefox.nix
    # ./configs/fzf.nix
    # ./configs/gh.nix
    # ./configs/git.nix
    # ./configs/neovim.nix
    # ./configs/polybar.nix
    # ./configs/rofi.nix
    # ./configs/starship.nix
    # ./configs/tmux.nix
    # ./configs/vscodium.nix
    # ./configs/zsh.nix
  ];

}