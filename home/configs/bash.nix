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
    };
  };
}
