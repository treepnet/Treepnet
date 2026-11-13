#!/usr/bin/env bash
# Deploys the chat backend from this folder as git sees it: the files git
# tracks (and new ones not ignored), nothing else, so the server folder
# mirrors the repo instead of drifting (each deploy used to be files copied
# over one by one, with backups and macOS copies piling up next to them).
#
#   oci-backend/chatbackend-src/deploy.sh
#
# On the server: unpacks them, builds the image, runs `npm test` inside it
# (no network), and only then makes ~/treepnet/chatbackend exactly that
# (rsync --delete, keeping node_modules and .env*), rebuilds and waits for the
# health check. ~/chat-deploys.log records the commit, "-dirty" when the
# deployed files weren't committed yet (deployed to be tested, then
# committed). A schema change must be applied first (prisma/manual).
set -euo pipefail

HOST=ubuntu@130.61.138.104
KEY="$HOME/.ssh/arm_key_new"
DIR=oci-backend/chatbackend-src

cd "$(git rev-parse --show-toplevel)/$DIR"
REV=$(git rev-parse --short HEAD)
if ! git diff --quiet HEAD -- . ||
   [ -n "$(git ls-files --others --exclude-standard -- .)" ]; then
  REV="$REV-dirty"
  echo "Note: deploying changes not committed yet ($REV)."
fi
echo "Deploying chat backend at $REV"

git ls-files -co --exclude-standard -- . |
  COPYFILE_DISABLE=1 tar --no-xattrs -c -f - -T - |
  ssh -i "$KEY" "$HOST" "rm -rf ~/chat-deploy/$REV && mkdir -p ~/chat-deploy/$REV && tar -x -C ~/chat-deploy/$REV"

ssh -i "$KEY" "$HOST" bash -s -- "$REV" <<'REMOTE'
set -euo pipefail
REV=$1
STAGE=~/chat-deploy/$REV
trap 'rm -rf "$STAGE"; docker rmi "chat-candidate:$REV" >/dev/null 2>&1 || true' EXIT

docker build -q -t "chat-candidate:$REV" "$STAGE" >/dev/null
echo "Tests (in the new image):"
if out=$(docker run --rm --network none \
    -e DATABASE_URL=postgresql://test@127.0.0.1/test -e CORS_ORIGIN='*' \
    --entrypoint npm "chat-candidate:$REV" test --silent 2>&1); then
  echo "$out" | grep -E '^(# |ℹ )(tests|pass|fail) ' || true
else
  echo "$out" | tail -40
  echo "Tests failed: nothing deployed." >&2
  exit 1
fi

rsync -a --delete --exclude node_modules --exclude '.env*' "$STAGE/" ~/treepnet/chatbackend/
cd ~/treepnet
docker compose up -d --build chatbackend 2>&1 | tail -1
for i in $(seq 40); do
  s=$(docker inspect -f '{{.State.Health.Status}}' treepnet-chatbackend)
  [ "$s" = healthy ] && break
  sleep 3
done
echo "health: $s"
echo "$(date -u +%FT%TZ) $REV $s" >> ~/chat-deploys.log
[ "$s" = healthy ]
REMOTE
