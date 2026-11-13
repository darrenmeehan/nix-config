{
  # Per-project environments: a repo with a flake.nix + .envrc gets its
  # toolchain (rustc, cargo, rust-analyzer, …) from that flake instead of a
  # global install. nix-direnv keeps the GC roots so re-entry is instant.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    # No wall of "direnv: loading…" on every cd; failures still print.
    silent = true;
    config.global.hide_env_diff = true;
  };
}
