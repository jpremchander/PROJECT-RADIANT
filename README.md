# PROJECT RADIANT

Threat Intelligence-Driven IDS — MISP generates Suricata detection rules for real-time network monitoring.

## Architecture

```text
MISP (native on Ubuntu)
  └── exports Suricata rules
        └── Suricata (Docker, host network)
              └── logs/suricata/eve.json + fast.log
```

| Component | Deployment  | Address                    |
|-----------|-------------|----------------------------|
| MISP      | Native      | `https://192.168.50.100`   |
| Suricata  | Docker      | host network, iface ens33  |

---

## Repository Layout

```text
PROJECT-RADIANT/
├── .env                      # Suricata environment variables
├── docker-compose.yml        # Suricata container
├── suricata/
│   ├── Dockerfile
│   ├── suricata.yaml
│   └── rules/local.rules
├── scripts/
│   ├── install-misp.sh       # Native MISP install + RADIANT credentials
│   ├── start.sh              # Start Suricata container
│   ├── test-traffic.sh       # Generate test LAN traffic
│   └── tail-alerts.sh        # Tail Suricata alert logs
└── logs/
    └── suricata/             # Suricata alert output (host-mounted)
```

---

## Prerequisites

- Ubuntu Server 22.04 with Docker Engine installed
- Interface `ens33` bridged to lab LAN `192.168.50.0/24`
- Root access for MISP native installation

---

## 1. Install MISP (native)

```bash
sudo bash scripts/install-misp.sh
```

This downloads and runs the official MISP installer then applies Project RADIANT credentials automatically.

**Login credentials:**

| Field    | Value                      |
|----------|----------------------------|
| URL      | `https://192.168.50.100`   |
| Email    | `admin@radiant.local`      |
| Password | `Rad14nt@2024`             |
| Org      | `RADIANT`                  |

---

## 2. Start Suricata

Edit `.env` if your interface or subnet differs, then:

```bash
./scripts/start.sh
docker compose ps
```

Suricata runs in host network mode and captures live traffic on `ens33`.

---

## 3. Test Detection

Generate traffic and watch for alerts:

```bash
./scripts/test-traffic.sh 192.168.50.10
./scripts/tail-alerts.sh
```

Alerts appear in `logs/suricata/fast.log` and `logs/suricata/eve.json`.

---

## 4. MISP → Suricata Workflow

1. Log into MISP at `https://192.168.50.100`
2. Create an Event with threat IOCs (IP, domain, hash)
3. Export → Suricata rules
4. Copy rules to `suricata/rules/local.rules`
5. Restart Suricata: `./scripts/start.sh`
6. Simulate traffic and confirm alerts fire

---

## Operations

```bash
# Start / stop Suricata
./scripts/start.sh
docker compose down

# Live alert feed
./scripts/tail-alerts.sh

# Suricata container logs
docker compose logs -f suricata
```
