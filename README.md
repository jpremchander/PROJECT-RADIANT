# PROJECT-RADIANT

Minimal Docker setup for MISP and Suricata.

## Start

1. Review `.env` and adjust the defaults if needed.
2. Run `scripts/start.sh` to build and start the stack.
3. Run `scripts/test-traffic.sh` to send a request from a disposable curl container that should match the bundled Suricata test rule.

## Layout

- `misp/` holds the MISP image wrapper and config mount point.
- `suricata/` holds the Suricata image wrapper, config, and local rules.
- `logs/` is the shared host-side log directory.