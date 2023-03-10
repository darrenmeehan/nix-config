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
    extraConfig = { credential = { helper = "libsecret"; }; };
  };
}
