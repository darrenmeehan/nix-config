{
  programs.bash = {
    enable = true;
    historyControl = [ "erasedups" "ignoredups" "ignorespace" ];
    # Unlimited history
    historyFileSize = -1;
    historySize = -1;
    shellAliases = {
      diff = "diff --color=auto";
      l = "eza --long --group --git --all";
      c = "code .";
      docker = "podman";
      docker-compose = "podman-compose";
      # Switch this machine's Home-Manager config (from anywhere)
      home-switch = "home-manager switch --flake \"$HOME/code/nix-config#\$USER@\$(hostname)\" -b backup";
      hm = "home-switch";

      # Deploy this repo's config to the dev-1 VM over ssh (see
      # hosts/dev-1/README.md). Asks for drn's sudo password on the VM.
      rebuild-dev = "nix run nixpkgs#nixos-rebuild -- switch --flake \"$HOME/code/nix-config#dev-1\" --target-host dev-1 --elevate=sudo --ask-elevate-password";
      # Removed from packages/settings.json for startup cost; load per session
      # with an exact pin so no registry check runs. See
      # docs/pi-bolt-extension-set.md
      pi-lens = "pi-bolt -e npm:pi-lens@4.5.1";
      pi-web = "pi-bolt -e npm:pi-web-access@0.48.0";
      # Pay the cold-transpile cost now instead of on the next session's first
      # prompt. Run after any pi install/remove/update --extensions.
      pi-warm = "pi-bolt -p ping";
    };
  };
}
