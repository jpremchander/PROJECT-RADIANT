#!/usr/bin/env sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

mkdir -p "$ROOT_DIR/logs/misp"

cd "$ROOT_DIR/misp-stack"

if docker compose version >/dev/null 2>&1; then
    docker compose up -d "$@"
elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose up -d "$@"
else
    echo "Error: neither 'docker compose' plugin nor 'docker-compose' binary found." >&2
    echo "Install with: apt-get install docker-compose-plugin" >&2
    exit 1
fi
