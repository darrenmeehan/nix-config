{
  description = "Rust project — declarative toolchain via rust-overlay, loaded by direnv";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ (import rust-overlay) ];
      };

      # Pin the toolchain in the flake, or — if you already keep a
      # rust-toolchain.toml (from rustup projects) — switch to:
      #   toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
      # which honours channel/components/targets in that file.
      toolchain = pkgs.rust-bin.stable.latest.default.override {
        extensions = [
          "rust-src" # needed by rust-analyzer for std sources
          "rust-analyzer"
          "clippy"
        ];
      };
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

        # rust-analyzer runs `cargo check`/`clippy` in the background; keep the
        # target dir out of the repo and off the GC-radar of nix-direnv.
        env = {
          RUST_BACKTRACE = "1";
          # Point rust-analyzer at the overlay's std sources for "go to
          # definition" into the standard library.
          RUST_SRC_PATH = "${toolchain}/lib/rustlib/src/rust/library";
        };
      };
    };
}
