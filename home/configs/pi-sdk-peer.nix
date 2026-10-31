{ pkgs, ... }:
# Some pi extensions import the Pi SDK by package name, e.g. pi-diff does
# `import("@earendil-works/pi-coding-agent")`. With pi from nixpkgs that
# package is not in the extension npm tree (the SDK lives inside pi's own
# bundle), so the import fails. Link the exact running SDK into that tree so
# the peer resolves. Recreated on every switch; `pi update --extensions` may
# drop it, in which case switch again.
{
  home.file.".pi/agent/npm/node_modules/@earendil-works/pi-coding-agent".source =
    "${pkgs.pi-coding-agent}/lib/node_modules/pi-monorepo";
}
