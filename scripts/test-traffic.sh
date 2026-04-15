#!/usr/bin/env sh

set -eu

TARGET_IP="${1:-192.168.50.10}"

printf 'Pinging %s to generate ICMP traffic...\n' "$TARGET_IP"
ping -c 4 "$TARGET_IP" || true

printf 'Sending HTTP test request to http://%s:8080/radiant-test ...\n' "$TARGET_IP"
curl -fsS "http://$TARGET_IP:8080/radiant-test?source=project-radiant" >/dev/null || true

printf 'Generating DNS traffic...\n'
nslookup example.com >/dev/null 2>&1 || true

printf 'Done. Check logs/suricata/eve.json and logs/suricata/fast.log\n'
