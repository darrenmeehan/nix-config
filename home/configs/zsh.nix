{ config, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 10000;
      path = "/home/mac/.history";
    };
    shellAliases = {
      diff = "diff --color=auto";
      l = "eza --long --group --git --all";
      c = "code .";
      docker = "podman";
      docker-compose = "podman-compose";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "robbyrussell";
    };
  };
}
