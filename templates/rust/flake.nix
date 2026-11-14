{
  description = "Rust project — declarative toolchain via rust-overlay, loaded by direnv";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rust-overlay }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ (import rust-overlay) ];
      };

      # The version is in rust-toolchain.toml, never here: change that channel
      # and nothing else to move this repo to a different Rust. Each repo gets
      # its own copy of this file, so different projects can sit on different
      # versions at the same time.
      #
      # The pinned rust-overlay rev ships stable 1.29.0+ and nightly back to
      # 2025-01-01 as vendored manifests — picking any of those is offline and
      # needs no coordination. A version outside that range needs
      # `nix flake update rust-overlay` in this repo only (own flake.lock).
      toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        # `rustc`, `cargo`, `rust-analyzer`, `cargo clippy` all come from here —
        # nothing in the global profile provides them.
        nativeBuildInputs = [
          toolchain
          pkgs.pkg-config
        ];
        buildInputs = [
          pkgs.openssl
        ];

        env = {
          RUST_BACKTRACE = "1";
          # rust-analyzer runs `cargo check`/`clippy` in the background and uses
          # this for "go to definition" into the standard library (rust-src).
          RUST_SRC_PATH = "${toolchain}/lib/rustlib/src/rust/library";
        };
      };

      formatter.${system} = pkgs.nixpkgs-fmt;
    };
}
