# Rust devShell template

```bash
nix flake init -t ~/code/nix-config#rust
direnv allow        # or: nix develop
cargo init --name app .
```

`rustc`, `cargo`, `rust-analyzer` and `clippy` come from this flake's devShell —
there is no global Rust toolchain on the machine. Requires `direnv` +
`nix-direnv` (both enabled in `home/configs/direnv.nix`).

Pinning a specific version instead of `stable.latest`:

```nix
toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
```

with a `rust-toolchain.toml` such as:

```toml
[toolchain]
channel = "1.96.0"
components = [ "rust-src", "rust-analyzer", "clippy" ]
```
