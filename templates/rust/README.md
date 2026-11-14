# Rust devShell template

```bash
nix flake init -t ~/code/nix-config#rust
direnv allow        # or: nix develop
cargo init --name app .
```

`rustc`, `cargo`, `rust-analyzer` and `clippy` come from this flake's devShell —
there is no global Rust toolchain on the machine. Requires `direnv` +
`nix-direnv` (both enabled in `home/configs/direnv.nix`).

## Choosing the Rust version

The version lives in `rust-toolchain.toml` and nowhere else; `flake.nix` reads
it with `rust-bin.fromRustupToolchainFile`. So a version bump is a one-line edit
in the repo that needs it:

```toml
[toolchain]
channel = "1.100.0"          # or "nightly-2026-03-01"
components = [ "rust-src", "rust-analyzer", "clippy", "rustfmt" ]
```

Every repo carries its own copy, so different projects run different toolchains
side by side — direnv swaps `PATH` on `cd`, and nix-direnv caches each one.

What each repo's `flake.lock` pins is the *catalogue* of versions available: the
rust-overlay rev ships stable 1.29.0+ and nightly back to 2025-01-01 as vendored
manifests, so any of those is offline and instant. A version outside that range
(newer than the lock, or older than the catalogue) needs
`nix flake update rust-overlay` in that repo — its own lockfile, so other repos
are untouched.

Docker images can't read a toml at `FROM` time, so an image tag restates the
version; that duplicate needs a check (a test that reads both files) or it will
drift.
