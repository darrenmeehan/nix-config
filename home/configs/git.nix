{ pkgs, ... }:

{
  programs.git = {
    package = pkgs.gitFull;
    enable = true;
    # 2026 home-manager: settings is the one source of truth
    # (aliases/userName/userEmail/extraConfig were merged into it).
    settings = {
      user = {
        name = "Darren Meehan";
        email = "hi@drn.ie";
      };
      alias = {
        ci = "commit";
        co = "checkout";
        br = "branch";
        st = "status";
      };
      # GitHub/Gist credential auth is handled by programs.gh (see gh.nix);
      # libsecret stays as the general helper for other hosts.
      credential = { helper = "libsecret"; };
    };
  };
}
