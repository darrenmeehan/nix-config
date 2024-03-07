# nix-config

NixOS and Home-Manager configuration.

Assumes use of Nix flakes.

## Adding a new host

The steps refer to this new hosts as "example", rename as you see fit.

```shell
cd <parent-dir>/nix-config
mkdir hosts/example
nix-shell -p nixos-install-tools
nixos-generate-config --dir hosts/example
```

## Update NixOS Configuration

* Build:

```shell
nixos-rebuild build --flake .#<hostname>
```

* Switch (usually requires `sudo`):

```shell
nixos-rebuild switch --flake .#<hostname>
```

## Update Home-Manager Configuration

* Build:

```shell
home-manager build --flake .#<username>@<hostname>
```

* Switch:

```shell
home-manager switch --flake .#<username>@<hostname>
```

## Update flake.lock file

```shell
nix flake update
```
