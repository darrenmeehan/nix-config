# Backup + Restore

Two independent backup systems: Postgres data and k3s cluster state.

## Postgres backups

Automated via CronJob — runs every Sunday at 3am, writes to
`/var/backups/curam/` on the VM host. Keeps last 4 backups.

### Manual backup

```bash
kubectl exec -n curam-fitness deploy/postgres -- \
  pg_dump -U fitness | gzip > ~/curam-manual-$(date +%Y%m%d).sql.gz
```

### Restore

```bash
# 1. Stop the backend
kubectl -n curam-fitness scale deploy/backend --replicas=0

# 2. Restore from a dump file
gunzip -c /var/backups/curam/curam-20260101.sql.gz | \
  kubectl exec -n curam-fitness -i deploy/postgres -- \
  psql -U fitness

# 3. Restart the backend
kubectl -n curam-fitness scale deploy/backend --replicas=1
```

## k3s cluster state

```bash
# Snapshot (all k8s resources, not volume data)
sudo k3s etcd-snapshot save

# Snapshots stored at:
# /var/lib/rancher/k3s/server/db/snapshots/
# Automated every 12h by default.
```

## Config backup (already in git)

Every piece of configuration is in this repo:

- NixOS flake: `flake.nix` + `hosts/fitness-node/`
- K8s manifests: `manifests/curam-fitness/`
- Encrypted secrets: `secrets/curam-secrets.enc.yaml`

**The only things NOT in git** are the age private key
(`~/.config/sops/age/keys.txt`) and API keys
(Anthropic, Resend). Store those in your password manager.

## Full disaster recovery

| Loss | Restore from | Time |
| --- | --- | --- |
| Postgres data gone | Latest `.sql.gz` from `/var/backups/curam/` | 5 min |
| VM dies (disk intact) | New VM + k3s install + mount old disk + restore DB | 15 min |
| VM dies (disk gone) | Git clone + k3s snapshot + DB dump from backup | 30 min |
| Everything | Create VM, install NixOS, clone repos, restore DB, rebuild image | 1 hour |
