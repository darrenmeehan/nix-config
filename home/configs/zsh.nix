{ config, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 10000;
    };
    shellAliases = {
      diff = "diff --color=auto";
      l = "eza --long --group --git --all";
      c = "code .";
      docker = "podman";
      docker-compose = "podman-compose";

      # Deploy this repo's config to the dev-1 VM over ssh (see
      # hosts/dev-1/README.md). Asks for drn's sudo password on the VM.
      rebuild-dev = "nix run nixpkgs#nixos-rebuild -- switch --flake \"$HOME/code/nix-config#dev-1\" --target-host dev-1 --elevate=sudo --ask-elevate-password";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "robbyrussell";
    };
  };
}
