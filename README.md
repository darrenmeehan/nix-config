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

Use this for non-NixOS machines

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

## New Proxmox VM setup

These insructions are based on the NixOS which page [Proxmox Virtual Environment](https://nixos.wiki/wiki/Proxmox_Virtual_Environment#Generating_VMA)

1. Create a new configuration for the machine
1. Ensure to change the user password hash
1. Generate the machine image using `nixos-generators` by running

    ```shell
    nix run github:nix-community/nixos-generators -- --format proxmox --configuration hosts/media/configuration.nix
    ```

1. Upload the image to the Proxmox host
1. Restore the image as a running VM

    ```shell
    qmrestore /var/lib/vz/dump/vzdump-qemu-nixos-21.11.git.d41882c7b98M.vma.zst <vmid> --unique true
    ```

    ```shell
    root@proxmox-server:~# qm start <vmid>
    root@proxmox-server:~# qm terminal <vmid>
    ```

### Resources

[Garbage Collection](https://nixos.org/manual/nix/stable/package-management/garbage-collection.html)



nix run --extra-experimental-features nix-command --extra-experimental-features flakes --no-write-lock-file github:nix-community/home-manager/ -- --flake ".#$USER@$HOSTNAME" --extra-experimental-features nix-command --extra-experimental-features flakes switch -b backup
