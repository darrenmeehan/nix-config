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
      yzhang.markdown-all-in-one # Markdown
      bbenoist.nix # Nix
      ms-python.python # Python
      matklad.rust-analyzer # Rust
      redhat.vscode-yaml # YAML
      # Git
      eamodio.gitlens
      donjayamanne.githistory
      # Github
      github.copilot
      github.copilot-chat
      github.vscode-pull-request-github
      github.vscode-github-actions
      # Editor appearance
      johnpapa.vscode-peacock
      pkief.material-icon-theme
      dracula-theme.theme-dracula
      # Formatting
      esbenp.prettier-vscode
      editorconfig.editorconfig
      # Spelling
      streetsidesoftware.code-spell-checker
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
    };
  };
}
