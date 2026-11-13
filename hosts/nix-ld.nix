# nix-ld: lets unpatched, dynamically linked binaries run on NixOS — the
# pre-built releases from `cargo binstall`, npm, pip wheels, and language
# servers that expect a normal FHS loader. Imported by every NixOS host.
{ pkgs, ... }:

{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
      curl
      libuv
      icu
    ];
  };
}
