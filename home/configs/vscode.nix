# Taken from https://github.com/timhourigan/nix-config/blob/main/home/configs/vscode.nix

{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    extensions = with pkgs.vscode-extensions; [
      # Search with:
      # https://search.nixos.org/packages?channel=22.05type=packages&query=vscode-extensions
      # Languages
      ms-vscode.makefile-tools # Makefile
      # Markdown
      yzhang.markdown-all-in-one
      bierner.markdown-checkbox
      bierner.markdown-emoji
      # bierner.markdown-preview-github-styles
      # bierner.github-markdown-preview
      bbenoist.nix # Nix
      # Python
      ms-python.python
      ms-python.vscode-pylance
      matklad.rust-analyzer # Rust
      redhat.vscode-yaml # YAML
      # Git
      eamodio.gitlens
      donjayamanne.githistory
      # donjayamanne.git-extension-pack
      codezombiech.gitignore
      # Github
      github.copilot
      github.copilot-chat
      github.vscode-pull-request-github
      github.vscode-github-actions
      # ziyasal.vscode-open-in-github
      # Languages / Syntax

      golang.go
      visualstudioexptteam.vscodeintellicode
      coolbear.systemd-unit-file
      streetsidesoftware.code-spell-checker
      # Editor appearance
      johnpapa.vscode-peacock
      pkief.material-icon-theme
      dracula-theme.theme-dracula
      editorconfig.editorconfig

      # Formatting
      esbenp.prettier-vscode
      redhat.ansible
      # renan-msv.ac3d-syntax
      # maelvalais.autoconf
      mikestead.dotenv
      # Spelling
      streetsidesoftware.code-spell-checker
      # Remote
      ms-vscode-remote.remote-containers
      ms-vscode-remote.remote-ssh
      # ms-vscode-remote.remote-ssh-edit
      # ms-vscode-remote.remote-wsl
      # ms-vscode-remote.vscode-remote-extensionpack
      # Containers
      ms-azuretools.vscode-docker
    ];
    userSettings = {
      # Material Icons
      "workbench.iconTheme" = "material-icon-theme";
      # No startup splashscreen
      "workbench.startupEditor" = "none";
      # Git config
      "git.confirmSync" = false;
      # No confirm on drag and drop
      "explorer.confirmDragAndDrop" = false;
      # No confirm on delete
      "explorer.confirmDelete" = false;
      # Turn off telemetry
      "telemetry.telemetryLevel" = "off";
      # Turn off Redhat telemetry
      "redhat.telemetry.enabled" = false;
      # Turn off auto-updates, let Nix manage
      "update.mode" = "none";
      # Trim newlines at end of file
      "files.trimFinalNewlines" = true;
      # Display trimmed whitespace
      "diffEditor.ignoreTrimWhitespace" = false;
      "files.autoSave" = "afterDelay";
      "[python]" = {
        "editor.formatOnType" = true;
        "editor.formatOnSave" = true;
        "editor.formatOnPaste" = true;
      };
      "cSpell.userWords" = [
        "nixpkgs"
        "nixos"
        "nixpkgs-mozilla"
        "blackbox"
        "cowsay"
        "changeme"
        "darrenmeehan"
        "deadpool"
        "healthcheck"
        "relme"
        "reqwest"
      ];
    };
  };
}
