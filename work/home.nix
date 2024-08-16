{ pkgs, ... }:

{
  targets.genericLinux.enable = false;

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
    username = "darren";
    homeDirectory = "/Users/darren";

    # Packages to be installed
    packages = with pkgs; [
      # Utils
      awscli2
      bat # `cat` clone
      bottom # Display process information (`top` alternative)
      caddy # Web server
      curl # I want a newer version than the one provided by Ubuntu
      dive # Docker image explorer
      du-dust # Disk space usage (`du` alternative)
      eza # File listing (`ls` alternative)
      fd # Find files/folders (`find` alternative)
      feh # Command line image viewer
      flarectl # Cloudflare CLI
      gcc # C compiler
      gitleaks # Git repository secrets checker
      htop # Display process information (`top` alternative)
      jq # Command line JSON parser
      just # Command runner
      neofetch # System information
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
      kubernetes-helm
      minikube
      kubectl
      eksctl
      istioctl
      k9s
      obsidian
      vscode-extensions.tim-koehler.helm-intellisense
      vscode-extensions.ms-kubernetes-tools.vscode-kubernetes-tools
      # Apps
      meld # Diff tools

      # Browsers

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

      # FIXME Need this addressed... Using brew for now
      # https://github.com/NixOS/nixpkgs/issues/305868
      podman
      podman-compose

      # Languages
      nodejs
      rustup
      nixd
      nixpkgs-fmt

      ansible-lint
      ansible
    #   (python311.withPackages (ps: with ps; [
    #     packer
    #     pip
    #     tox
    #     podman
    #   ]))
      argocd
      libiconv
      nodePackages.cdktf-cli
      nodePackages_latest.prettier
      terraform
      (python312.withPackages (ps: with ps; [
        pytest
      ]))
      poetry
      spotify
      uv
      vim
    ];
  };
  # Allow fontconfig to discover installed fonts and configurations
  fonts.fontconfig.enable = true;

  # Programs and configurations to be installed
  imports = [
    ../configs/alacritty.nix
    ../configs/autojump.nix
    ../configs/bash.nix
    # ../configs/dconf.nix
    ../configs/direnv.nix
    ../configs/fzf.nix
    ../configs/gh.nix
    ../configs/git.nix
    ../configs/neovim.nix
    ../configs/starship.nix
    ../configs/tmux.nix
    ../configs/vscode.nix
    ../configs/zsh.nix
  ];

}
