#!/usr/bin/env sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

mkdir -p "$ROOT_DIR/logs/misp"

cd "$ROOT_DIR/misp-stack"

docker compose up -d "$@"
