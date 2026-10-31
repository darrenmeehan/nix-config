{ pkgs, ... }:
# pi-bolt comes from the `pi-bolt-nixpkgs` input (see flake.nix), overlaid as
# pkgs.pi-bolt. It shares ~/.pi/agent with pi.
{
  home.packages = [ pkgs.pi-bolt ];
}
