#!/usr/bin/env sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

cd "$ROOT_DIR"

NETWORK_NAME=${COMPOSE_PROJECT_NAME:-project-radiant}_radiant
TEST_URL=http://misp/radiant-test?source=project-radiant

printf 'Sending test request to %s\n' "$TEST_URL"

docker run --rm --network "$NETWORK_NAME" curlimages/curl:8.10.1 -fsS "$TEST_URL" >/dev/null

printf 'Test traffic sent. Check Suricata logs in logs/suricata/eve.json for the alert.\n'