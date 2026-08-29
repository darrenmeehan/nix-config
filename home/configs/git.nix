{ pkgs, ... }:

{
  programs.git = {
    package = pkgs.gitAndTools.gitFull;
    enable = true;
    userName = "Darren Meehan";
    userEmail = "hi@drn.ie";
    aliases = {
      ci = "commit";
      co = "checkout";
      br = "branch";
      st = "status";
    };
    # GitHub/Gist credential auth is handled by programs.gh (see gh.nix);
    # libsecret stays as the general helper for other hosts.
    extraConfig = { credential = { helper = "libsecret"; }; };
  };
}
