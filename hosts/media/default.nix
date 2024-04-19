{ globals
, inputs
, overlays
, ...
}:

inputs.nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    globals
    inputs.home-manager.nixosModules.home-manager
    ../../modules/common
    ../../modules/nixos
    "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"
    ./proxmox.nix
    {
      nixpkgs.overlays = overlays;

      networking.hostName = "media";

      # Secrets must be prepared ahead before deploying
      passwordHash = inputs.nixpkgs.lib.fileContents ../../misc/password.sha512;

      services.openssh.enable = true;

    }
  ];
}
