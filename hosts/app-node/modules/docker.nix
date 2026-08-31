{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.virtualisation.docker.enable or false) {
    virtualisation.docker = {
      autoPrune.enable = true;
      autoPrune.dates = "weekly";
      liveRestore = false;
    };

    environment.systemPackages = [ pkgs.docker ];
  };
}