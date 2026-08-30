# Kubernetes

> **⚠️ Obsolete.** This directory is leftover from an earlier k0s experiment and
> is **not wired into the flake** (`hosts/kube` isn't referenced by
> `flake.nix`). The current cluster is the single-node k3s on the
> `fitness-node` VM — see `hosts/fitness-node/README.md` and
> `docs/architecture.md`. Content below is historical only.

Only running a single node cluster at the moment.

Setup `k0s` - need to get into IaaC

Added 2nd and 3rd network interface in Proxmox UI.

```shell
[nix-shell:~]$ sudo cat /etc/netplan/00-installer-config.yaml 
# This is the network config written by 'subiquity'
network:
  ethernets:
    ens18:
      dhcp4: true
    ens19:
      dhcp4: true
  version: 2
```
