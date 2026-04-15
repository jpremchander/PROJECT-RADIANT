# PROJECT-RADIANT

Project RADIANT is a lab repo for validating Suricata on the real LAN first, then bringing MISP in as a separate stack.

Default path:

- Suricata runs on the Ubuntu host network for real packet capture.
- Local rules and host-side logs are used to validate detection.
- MISP lives in a separate folder so the root stack stays simple.

Optional later work:

- Monitoring and SIEM tooling under `monitoring/`
- Automation and enrichment workflows

## 1. Architecture

### Root Stack

- `suricata`:
  - IDS engine using host networking for LAN capture
  - Writes alerts to `logs/suricata/eve.json` and `logs/suricata/fast.log`

### MISP Stack

- `misp-stack/`:
  - Separate deployment home for the official MISP Docker stack
  - Keeps the root lab isolated from backend complexity

### Optional Monitoring

- `monitoring/`:
  - Optional later monitoring stack
  - Not part of the default deployment path

## 2. Prerequisites

- Ubuntu Server with Docker Engine and Docker Compose plugin
- A bridged or reachable lab network
- The actual Ubuntu NIC name for Suricata capture, such as `ens33`
- A lab subnet that matches `.env`

## 3. Repository Layout

- `.env`: Suricata environment variables
- `docker-compose.yml`: Suricata only
- `suricata/`: Suricata config and rules
- `logs/`: host-side logs
- `misp-stack/`: separate MISP deployment home
- `monitoring/`: optional later monitoring stack
- `scripts/start.sh`: start the root stack
- `scripts/test-traffic.sh`: generate LAN traffic for Suricata rules
- `scripts/tail-alerts.sh`: tail Suricata alert logs

## 4. Start the Root Stack

Edit `.env` if your interface or subnet is different.

```bash
./scripts/start.sh
docker compose ps
```

The root compose is Suricata only. It uses `network_mode: "host"` and the capture interface from `SURICATA_CAPTURE_IFACE`.

## 5. Generate Test Traffic

Use a host on the lab subnet, or the Ubuntu host IP, to generate traffic.

```bash
./scripts/test-traffic.sh 192.168.50.10
./scripts/tail-alerts.sh
```

Expected result:

- ICMP, HTTP, or DNS events appear in `logs/suricata/eve.json`
- Fast alerts appear in `logs/suricata/fast.log`

## 6. Deploy MISP Separately

Use the `misp-stack/` directory for the official MISP Docker stack.

Recommended backend services:

- `misp-core`
- `db`
- `redis`

Keep MISP out of the root compose until the Suricata path is stable.

## 7. Optional Monitoring

Monitoring is optional later work. If you enable it, treat it as a separate add-on path rather than part of the default lab flow.

## 8. Operations

### Start and stop

```bash
docker compose up -d
docker compose down
```

### Logs

```bash
docker compose logs -f suricata
tail -f logs/suricata/eve.json logs/suricata/fast.log
```

## 9. Lab Notes

- If your Ubuntu NIC name is not `ens33`, update `SURICATA_CAPTURE_IFACE` in `.env`.
- If your lab subnet changes, update `SURICATA_HOME_NET` in `.env` and the local rules in `suricata/`.
- Keep MISP deployment changes inside `misp-stack/` so the root stack stays focused on packet capture.
