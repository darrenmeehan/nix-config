#!/usr/bin/env bash
# One-time: generate secrets, encrypt with sops.
# Usage: ./scripts/setup-secrets.sh
#
# Prerequisites:
#   - sops installed
#   - age key at ~/.config/sops/age/keys.txt
#   - Public key copied to .sops.yaml

set -euo pipefail

SECRETS_FILE="secrets/curam-secrets.enc.yaml"

if [ -f "$SECRETS_FILE" ]; then
  echo "♻️  Secrets file exists. Regenerate? [y/N]"
  read -r ans
  if [ "$ans" != "y" ]; then
    echo "Aborting."
    exit 0
  fi
fi

echo "==> Generating secrets"

DB_PASSWORD=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -hex 64)
HEVY_WEBHOOK_JWT_SECRET=$(openssl rand -hex 64)
SYNC_API_KEY="cu_$(openssl rand -hex 48)"
DATABASE_URL="postgres://fitness:${DB_PASSWORD}@postgres:5432/fitness"

echo ""
echo "Enter ANTHROPIC_API_KEY (for AI coaching):"
read -r ANTHROPIC_API_KEY
echo "Enter RESEND_API_KEY (optional, for emails):"
read -r RESEND_API_KEY

# Temp file lives in secrets/ so it matches the creation rules in .sops.yaml
# (path_regex: secrets/.*\.yaml) — a /tmp path never matches and sops refuses.
TMP_FILE="secrets/.tmp-curam-secrets.yaml"
cat >"$TMP_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: curam-secrets
  namespace: curam-fitness
type: Opaque
stringData:
  database_url: "$DATABASE_URL"
  db_password: "$DB_PASSWORD"
  jwt_secret: "$JWT_SECRET"
  anthropic_api_key: "$ANTHROPIC_API_KEY"
  resend_api_key: "$RESEND_API_KEY"
  sync_api_key: "$SYNC_API_KEY"
  hevy_webhook_jwt_secret: "$HEVY_WEBHOOK_JWT_SECRET"
EOF

echo "==> Encrypting with sops"
sops --encrypt "$TMP_FILE" >"$SECRETS_FILE"
rm "$TMP_FILE"

echo "✅ Encrypted secrets written to $SECRETS_FILE"
echo ""
echo "To apply: sops --decrypt $SECRETS_FILE | kubectl apply -f -"
