{ pkgs, ... }:

{
  programs.git = {
    package = pkgs.gitAndTools.gitFull;
    enable = true;
    userName = "Darren Meehan";
    userEmail = "darren.meehan@onda.ai";
    aliases = {
      ci = "commit";
      co = "checkout";
      br = "branch";
      st = "status";
    };
    extraConfig = {
        credential = { helper = "libsecret"; };
        push = { autoSetupRemote = true; };
        };
  };
}
