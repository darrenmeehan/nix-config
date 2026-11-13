{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    extensions = with pkgs.vscode-extensions; [
      # Search with:
      # https://search.nixos.org/packages?channel=22.05type=packages&query=vscode-extensions
      # Languages
      wholroyd.jinja # Jinja
      yzhang.markdown-all-in-one # Markdown
      bbenoist.nix # Nix
      ms-python.python # Python
      rust-lang.rust-analyzer # Rust (server from the project devShell, see below)
      mkhl.direnv # loads .envrc into the editor, so rust-analyzer is on PATH
      redhat.vscode-yaml # YAML
      # Git
      eamodio.gitlens
      donjayamanne.githistory
      github.vscode-pull-request-github
      # Editor appearance
      johnpapa.vscode-peacock
      pkief.material-icon-theme
      dracula-theme.theme-dracula
      # Formatting
      esbenp.prettier-vscode
      editorconfig.editorconfig
      # Spelling
      streetsidesoftware.code-spell-checker
      # Dev Environments
      # ms-vscode-remote.remote-containers
      # ms-azuretools.vscode-docker
      # # GitHub
      # GitHub.copilot
      # GitHub.copilot-chat
      # github.vscode-github-actions
    ];
    userSettings = {
      # Rust tooling comes from the project's devShell (direnv), not a global
      # install or the extension's own download. Open the folder, let the direnv
      # extension load .envrc, and this resolves to the flake's rust-analyzer.
      "rust-analyzer.server.path" = "rust-analyzer";
      "rust-analyzer.check.command" = "clippy";
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
    };
  };
}
