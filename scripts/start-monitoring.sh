#!/usr/bin/env sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

cd "$ROOT_DIR"

if [ ! -f "monitoring/.env.monitoring" ]; then
  cp monitoring/.env.monitoring.example monitoring/.env.monitoring
  printf 'Created monitoring/.env.monitoring from template. Update secrets before production use.\n'
fi

docker compose --env-file monitoring/.env.monitoring -f monitoring/docker-compose.monitoring.yml up -d