#!/usr/bin/env bash
# À lancer sur le VPS avec l'utilisateur debian, après récupération de main.
set -euo pipefail
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
INFRA=/opt/clubika/deploy
AUTO="$HOME/deploy/auto-deploy.sh"
STATE="$HOME/deploy/state"

docker info >/dev/null
docker network inspect clubika_internal >/dev/null
test -f "$INFRA/Caddyfile"
test -f "$AUTO"
test -z "$(git -C "$REPO" status --porcelain)" || {
  echo 'Le dépôt doit être committé et propre avant installation.' >&2; exit 1;
}
test "$(git -C "$REPO" rev-parse HEAD)" = "$(git -C "$REPO" rev-parse origin/main)" || {
  echo 'Récupérer origin/main avant installation.' >&2; exit 1;
}
mkdir -p "$STATE" "$HOME/deploy/backups"
exec 9>"$HOME/deploy/.lock"
flock -w 120 9

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export DISTANCE_REPO="$REPO" DISTANCE_AUTO="$AUTO" DISTANCE_WORK="$WORK"
python3 - <<'PY'
import os
from pathlib import Path
repo = Path(os.environ['DISTANCE_REPO'])
work = Path(os.environ['DISTANCE_WORK'])
auto = Path(os.environ['DISTANCE_AUTO']).read_text()
apps = next(line for line in auto.splitlines() if line.startswith('APPS="'))
if 'distanceCalc' not in apps.removeprefix('APPS="').removesuffix('"').split():
    auto = auto.replace(apps, apps[:-1] + ' distanceCalc"', 1)
health = '''  if [ "$1" = distancecalc-web ]; then
    for _ in $(seq 1 30); do
      docker exec distancecalc-web wget -qO- http://127.0.0.1:8080/healthz 2>/dev/null | grep -qx ok && return 0
      sleep 2
    done
    return 1
  fi
'''
if 'if [ "$1" = distancecalc-web ]; then' not in auto:
    anchor = '  if [ "$1" = fr-api ]; then'
    if auto.count(anchor) != 1:
        raise SystemExit('Fonction healthy inconnue : intégration automatique interrompue.')
    auto = auto.replace(anchor, health + anchor, 1)
deployment = '''  if [ "$1" = distanceCalc ]; then
    (cd "$ROOT/distanceCalc/server" && timeout 1200 docker compose --progress quiet up -d --build >> "$LOG" 2>&1) && healthy distancecalc-web
    return
  fi
'''
if 'if [ "$1" = distanceCalc ]; then' not in auto:
    anchor = '  if [ "$1" = fr ]; then'
    if auto.count(anchor) != 1:
        raise SystemExit('Fonction deploy inconnue : intégration automatique interrompue.')
    auto = auto.replace(anchor, deployment + anchor, 1)
(work / 'auto-deploy.sh').write_text(auto)
current = Path('/opt/clubika/deploy/Caddyfile').read_text()
site = (repo / 'deploy/distance.caddy').read_text()
if 'distance.clubika.com' in current and site.strip() not in current:
    raise SystemExit('Une autre configuration existe déjà pour distance.clubika.com.')
(work / 'Caddyfile').write_text(current if site.strip() in current else current.rstrip() + '\n\n' + site)
PY
bash -n "$WORK/auto-deploy.sh"
docker compose -f "$REPO/server/docker-compose.yml" config --quiet
docker compose -f "$REPO/server/docker-compose.yml" up -d --build --wait --wait-timeout 90
docker compose -f "$INFRA/docker-compose.yml" exec -T caddy \
  caddy validate --config /dev/stdin --adapter caddyfile < "$WORK/Caddyfile"

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
cp "$INFRA/Caddyfile" "$HOME/deploy/backups/Caddyfile.distance.$STAMP"
cp "$AUTO" "$HOME/deploy/backups/auto-deploy.distance.$STAMP.sh"
write_caddy() {
  # Préserve l'inode du fichier monté dans le conteneur Caddy existant.
  if [ -w "$INFRA/Caddyfile" ]; then
    cat "$1" > "$INFRA/Caddyfile"
  else
    sudo tee "$INFRA/Caddyfile" < "$1" >/dev/null
  fi
}
write_caddy "$WORK/Caddyfile"
if ! docker compose -f "$INFRA/docker-compose.yml" exec -T caddy \
  caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile; then
  write_caddy "$HOME/deploy/backups/Caddyfile.distance.$STAMP"
  docker compose -f "$INFRA/docker-compose.yml" exec -T caddy \
    caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
  exit 1
fi

curl --fail --silent --show-error --retry 12 --retry-delay 5 --retry-all-errors \
  --connect-timeout 5 --max-time 10 https://distance.clubika.com/healthz | grep -qx ok
curl --fail --silent --show-error --connect-timeout 5 --max-time 15 \
  https://distance.clubika.com/ | grep -q 'Distance Transports'
# N'active les mises à jour qu'après validation de l'application et du HTTPS.
cat "$WORK/auto-deploy.sh" > "$AUTO"
git -C "$REPO" rev-parse HEAD > "$STATE/distanceCalc.deployed"
rm -f "$STATE/distanceCalc.bad"
echo 'Distance Transports disponible : https://distance.clubika.com'
