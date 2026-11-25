{ pkgs, ... }:
# home-manager side of dev-1: only the two pi files, so they are declared rather
# than hand-edited on the box. pi-bolt itself is a systemPackage (the remote
# control unit points at /run/current-system/sw/bin/pi-bolt), so it is not
# installed again here.
let
  # Same shared config as the laptop, with pi-curam-security left out.
  piConfig = import ../../pkgs/pi-bolt/pi-config.nix {
    inherit pkgs;
    pi-curam-security = false;
  };
  # Remote control on: the phone drives sessions on this box, and a store-path
  # settings file cannot be edited by `pi-bolt remote-control enable`, so it has
  # to be declared here. The laptop leaves it off.
  settings = piConfig.settings // {
    remoteControl = {
      enabled = true;
    };
  };
in
{
  home.file.".pi/agent/settings.json" = {
    source = (pkgs.formats.json { }).generate "settings.json" settings;
    force = true;
  };

  home.file.".pi/agent/extensions/guardrails.json" = {
    source = (pkgs.formats.json { }).generate "guardrails.json" piConfig.guardrails;
    force = true;
  };
}
