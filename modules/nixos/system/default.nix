{ config, pkgs, lib, ... }: {

  imports =
    [ ./user.nix ];

  config = lib.mkIf pkgs.stdenv.isLinux {

    # Pin a state version to prevent warnings
    system.stateVersion =
      config.home-manager.users.drn.home.stateVersion;

  };

}
