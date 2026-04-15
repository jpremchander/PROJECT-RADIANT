#!/usr/bin/env sh

set -eu

tail -f logs/suricata/eve.json logs/suricata/fast.log
