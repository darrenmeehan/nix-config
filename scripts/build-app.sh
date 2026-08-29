#!/usr/bin/env bash
# Build Docker image from curam/fitness repo and load into k3s.
# Works on NixOS (docker is available in systemPackages).
#
# Usage: ./scripts/build-app.sh /path/to/curam/fitness [tag]

set -euo pipefail

APP_DIR="${1:-/opt/curam/fitness}"
TAG="${2:-$(date +%Y%m%d-%H%M%S)}"
IMAGE_NAME="curam-backend:$TAG"

if [ ! -f "$APP_DIR/Dockerfile" ]; then
  echo "❌ No Dockerfile found at $APP_DIR"
  exit 1
fi

echo "==> Building $IMAGE_NAME from $APP_DIR"
cd "$APP_DIR"
docker build -t "$IMAGE_NAME" .

docker tag "$IMAGE_NAME" curam-backend:latest

# Load into k3s (k3s uses containerd)
echo "==> Loading into k3s"
docker save "$IMAGE_NAME" | sudo k3s ctr images import -

echo "==> Done: $IMAGE_NAME"
echo "   kubectl -n curam-fitness rollout restart deployment/backend"
