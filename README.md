# PROJECT RADIANT

## Threat Intelligence-Driven Intrusion Detection System

Project RADIANT integrates MISP (Malware Information Sharing Platform) with Suricata IDS to automate the full threat detection lifecycle — from IOC ingestion and rule generation to real-time network alert classification using Claude AI. Designed as a complete security operations lab environment demonstrating intelligence-driven detection at every stage.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Repository Layout](#repository-layout)
3. [Prerequisites](#prerequisites)
4. [Setup: Install MISP (Native)](#1-setup-install-misp-native)
5. [Setup: Start Suricata (Docker)](#2-setup-start-suricata-docker)
6. [Workflow: MISP IOC → Suricata Rule](#3-workflow-misp-ioc--suricata-rule)
7. [AI: Generate Rules from IOCs](#4-ai-generate-rules-from-iocs)
8. [AI: Classify Alerts](#5-ai-classify-alerts)
9. [Full Demo: End-to-End Script](#6-full-demo-end-to-end-script)
10. [Operations Reference](#7-operations-reference)
11. [Credentials Reference](#8-credentials-reference)
12. [Troubleshooting](#9-troubleshooting)

---

## Architecture Overview

```text
┌─────────────────────────────────────────────────────────────────┐
│                        PROJECT RADIANT                          │
│                                                                 │
│  ┌──────────────────┐     IOC Export      ┌─────────────────┐  │
│  │   MISP Platform  │ ──────────────────► │  local.rules    │  │
│  │  (Native Ubuntu) │                     │  (Suricata)     │  │
│  │  192.168.50.100  │                     └────────┬────────┘  │
│  └──────────────────┘                              │           │
│                                                    ▼           │
│  ┌──────────────────┐    Live Traffic     ┌─────────────────┐  │
│  │  Attack Sim      │ ──────────────────► │    Suricata     │  │
│  │  (curl/nslookup/ │                     │  (Docker, ens33)│  │
│  │   ping)          │                     └────────┬────────┘  │
│  └──────────────────┘                              │           │
│                                                    ▼           │
│  ┌──────────────────┐    Alert Analysis   ┌─────────────────┐  │
│  │   Claude AI      │ ◄────────────────── │  eve.json       │  │
│  │  (Classification │                     │  fast.log       │  │
│  │  + Rule Gen)     │                     └─────────────────┘  │
│  └──────────────────┘                                          │
└─────────────────────────────────────────────────────────────────┘
```

| Component    | Deployment     | Address / Interface        |
|--------------|----------------|----------------------------|
| MISP         | Native Ubuntu  | `http://192.168.50.100`    |
| Suricata IDS | Docker         | Host network — `ens33`     |
| Claude AI    | Anthropic API  | AI classification & rules  |

Detection Pipeline:

```text
MISP Threat Event
  └── IOC (domain / IP / URL)
        └── Suricata Rule (manual or AI-generated)
              └── Live Traffic Inspection
                    └── Alert (fast.log + eve.json)
                          └── AI Classification (severity + action)
```

---

## Repository Layout

```text
PROJECT-RADIANT/
│
├── .env                              # Suricata interface + network config
├── docker-compose.yml                # Suricata Docker definition
│
├── suricata/
│   ├── Dockerfile                    # Suricata container build
│   ├── suricata.yaml                 # Suricata engine configuration
│   └── rules/
│       └── local.rules               # Active detection rules (MISP + AI-generated)
│
├── scripts/
│   ├── install-misp.sh               # Full native MISP install (Ubuntu 24.04)
│   ├── reset-misp-credentials.sh     # Reset MISP admin email + password
│   ├── start.sh                      # Build and start Suricata container
│   ├── complete-radiant.sh           # Full end-to-end demo script
│   ├── test-traffic.sh               # Generate simulated attack traffic
│   ├── tail-alerts.sh                # Live tail of Suricata alert logs
│   ├── ai-classify-alerts.py         # AI-powered alert classification (Claude)
│   └── ai-generate-rules.py          # AI-powered Suricata rule generation (Claude)
│
└── logs/
    └── suricata/
        ├── fast.log                  # Human-readable alert log
        └── eve.json                  # Structured JSON alert log (SIEM-ready)
```

---

## Prerequisites

### Lab Environment

| Requirement        | Details                                              |
|--------------------|------------------------------------------------------|
| OS                 | Ubuntu Server 24.04 LTS                              |
| Network Interface  | `ens33` bridged to lab LAN `192.168.50.0/24`         |
| Docker             | Docker Engine with Compose V2 (`docker compose`)     |
| Root Access        | Required for MISP install and Suricata host network  |
| Python             | Python 3.10+ (for AI scripts)                        |
| Anthropic API Key  | Required for AI classification and rule generation   |

### Install Docker (if not installed)

```bash
curl -fsSL https://get.docker.com | sudo bash
sudo systemctl enable --now docker
```

### Install Python AI dependency

```bash
pip install anthropic
```

---

## 1. Setup: Install MISP (Native)

MISP is installed natively on Ubuntu (not Docker) for full platform stability. The install script handles all dependencies, database configuration, Apache setup, and credential seeding automatically.

### What the script does

- Adds the `ondrej/php` PPA and installs PHP 7.4 (required — PHP 8.x conflicts with MISP's CakePHP model)
- Installs and configures MariaDB, Redis, and Apache2
- Clones the MISP 2.4 branch from GitHub
- Writes all configuration files directly (`database.php`, `config.php`, `bootstrap.php`, `core.php`)
- Sets admin credentials via bcrypt hash directly in MySQL (no CakePHP CLI dependency)

### Run the installer

```bash
sudo bash scripts/install-misp.sh
```

> Installation takes approximately 5–10 minutes depending on network speed.

### Verify MISP is running

```bash
# Check Apache is serving MISP
curl -s -o /dev/null -w "%{http_code}" http://192.168.50.100
# Expected: 200
```

Open a browser and navigate to `http://192.168.50.100`.

### MISP Login Credentials

| Field    | Value                   |
|----------|-------------------------|
| URL      | `http://192.168.50.100` |
| Email    | `admin@radiant.lab`     |
| Password | `admin@1234`            |
| Org      | `RADIANT`               |

### Reset credentials (if needed)

```bash
sudo bash scripts/reset-misp-credentials.sh
```

---

## 2. Setup: Start Suricata (Docker)

Suricata runs in Docker using host network mode, capturing live traffic directly on the `ens33` interface.

### Configure environment

Edit `.env` if your network interface or subnet differs from the defaults:

```bash
# .env
SURICATA_INTERFACE=ens33
HOME_NET=192.168.50.0/24
```

### Start the container

```bash
sudo bash scripts/start.sh
```

This builds the Suricata image and starts the container in detached mode.

### Verify Suricata is running

```bash
docker compose ps
docker compose logs suricata --tail 20
```

Expected output: Suricata initializing rules and listening on `ens33`.

### Tail live alerts

```bash
sudo bash scripts/tail-alerts.sh
```

Alert logs are written to:

- `logs/suricata/fast.log` — human-readable, one alert per line
- `logs/suricata/eve.json` — structured JSON, suitable for SIEM ingestion

---

## 3. Workflow: MISP IOC → Suricata Rule

This is the core intelligence pipeline. A threat analyst adds an IOC to MISP, which is then translated into a Suricata detection rule.

### Step-by-step

#### Step 1 — Log into MISP

Navigate to `http://192.168.50.100` and log in with the credentials above.

#### Step 2 — Create a Threat Event

1. Go to **Event Actions → Add Event**
2. Fill in the fields:
   - **Event Info**: `Malicious Domain — Command and Control`
   - **Threat Level**: `High`
   - **Analysis**: `Completed`
   - **Distribution**: `Your Organisation Only`
3. Click **Submit**

#### Step 3 — Add an IOC Attribute

1. Inside the event, click **Add Attribute**
2. Fill in the fields:
   - **Category**: `Network activity`
   - **Type**: `domain`
   - **Value**: `malicious-domain.com`
   - **IDS**: checked (enabled)
3. Click **Submit**

#### Step 4 — Write the Suricata Rule

Create or update `suricata/rules/local.rules`:

```text
alert dns any any -> any any (msg:"RADIANT - Malicious Domain DNS Query"; dns.query; content:"malicious-domain.com"; nocase; sid:9000001; rev:1;)
alert http any any -> any any (msg:"RADIANT - Malicious Domain HTTP Request"; http.host; content:"malicious-domain.com"; nocase; sid:9000002; rev:1;)
```

#### Step 5 — Restart Suricata to Load New Rules

```bash
sudo bash scripts/start.sh
```

#### Step 6 — Simulate Attack Traffic

```bash
curl -s --max-time 5 http://malicious-domain.com -o /dev/null || true
nslookup malicious-domain.com 8.8.8.8 || true
```

#### Step 7 — Confirm Detection

```bash
grep "RADIANT" logs/suricata/fast.log
```

Expected output:

```text
04/17/2026-21:47:32 [**] [1:9000001:1] RADIANT - Malicious Domain DNS Query [**] [Priority: 3] {UDP} 192.168.50.100:38509 -> 8.8.8.8:53
```

---

## 4. AI: Generate Rules from IOCs

`ai-generate-rules.py` reads IOCs from the MISP database (or accepts them manually) and uses Claude AI to generate production-ready Suricata detection rules automatically.

### How Rule Generation Works

1. Connects to the MISP MariaDB database and pulls all IOCs flagged for IDS (`to_ids=1`)
2. Sends the IOC list to Claude AI with a Suricata rule-writing system prompt
3. Writes the generated rules to `suricata/rules/local.rules`

### Rule Generation Usage

```bash
export ANTHROPIC_API_KEY="sk-ant-..."

# Auto-fetch IOCs from MISP database and generate rules
sudo python3 scripts/ai-generate-rules.py

# Provide IOCs manually (no MISP database access required)
python3 scripts/ai-generate-rules.py --iocs domain:evil.com ip:1.2.3.4 url:http://bad.io/payload

# Append AI-generated rules to existing rules file (preserves manual rules)
python3 scripts/ai-generate-rules.py --append

# Specify a custom output path
python3 scripts/ai-generate-rules.py --rules-file /path/to/custom.rules
```

### Rule Generation Output

```text
=== AI-Generated rules — Project RADIANT ===
alert dns any any -> any any (msg:"RADIANT - AI - Malicious Domain DNS Query"; dns.query; content:"evil.com"; nocase; sid:9001000; rev:1;)
alert tcp any any -> 1.2.3.4 any (msg:"RADIANT - AI - Suspicious Outbound Connection"; sid:9001001; rev:1;)
alert http any any -> any any (msg:"RADIANT - AI - Malicious Payload URL"; http.uri; content:"/payload"; nocase; sid:9001002; rev:1;)
```

### Reload Suricata with new rules

```bash
sudo bash scripts/start.sh
```

---

## 5. AI: Classify Alerts

`ai-classify-alerts.py` reads recent Suricata alerts from `eve.json` and uses Claude AI to classify each alert with a severity rating, threat category, plain-English summary, and recommended response action.

### How Alert Classification Works

1. Reads the most recent N alerts from `logs/suricata/eve.json`
2. Sends each alert (full JSON context) to Claude AI
3. Returns structured classification: severity, category, summary, action

### Alert Classification Usage

```bash
export ANTHROPIC_API_KEY="sk-ant-..."

# Classify the 10 most recent alerts (default)
python3 scripts/ai-classify-alerts.py

# Classify the last 25 alerts
python3 scripts/ai-classify-alerts.py --limit 25

# Specify a custom log path
python3 scripts/ai-classify-alerts.py --log /path/to/eve.json
```

### Alert Classification Output

```text
============================================================
  PROJECT RADIANT — AI Alert Classification
============================================================
  Log  : logs/suricata/eve.json
  Limit: 10 most recent alerts
============================================================

[1/3] 2026-04-17T21:47:32  192.168.50.100 → 8.8.8.8  (UDP)  |  RADIANT - Malicious Domain DNS Query
        Severity : HIGH
        Category : DNS-based C2 Communication
        Summary  : Host queried a known malicious domain over DNS, indicating possible C2 beacon or malware activity.
        Action   : block

[2/3] 2026-04-17T21:47:37  192.168.50.100 → 8.8.8.8  (UDP)  |  RADIANT - Malicious Domain DNS Query
        Severity : HIGH
        Category : DNS-based C2 Communication
        Summary  : Repeated DNS queries to malicious-domain.com suggest automated beaconing behaviour.
        Action   : block

============================================================
  Classification complete.
============================================================
```

---

## 6. Full Demo: End-to-End Script

`complete-radiant.sh` automates the entire Project RADIANT pipeline in a single command — ideal for demonstrations and testing.

### What it does

| Step | Action                                                      |
|------|-------------------------------------------------------------|
| 1    | Fetches the MISP API key from the database                  |
| 2    | Creates a MISP threat event via REST API                    |
| 2b   | Adds `malicious-domain.com` as a domain IOC                 |
| 3    | Writes Suricata detection rules to `local.rules`            |
| 4    | Builds and starts the Suricata Docker container             |
| 5    | Simulates attack traffic (DNS query, HTTP request, ICMP)    |
| 6    | Prints detected alerts from `fast.log` and `eve.json`       |

### Run the full demo

```bash
sudo bash scripts/complete-radiant.sh
```

### Expected terminal output

```text
======================================================
  PROJECT RADIANT — Full Demo
======================================================

==> [1/6] Fetching MISP API key...
    API Key: <key>

==> [2/6] Creating MISP threat event...
    Event created: ID=1

==> [2b] Adding domain IOC to event...
    IOC added: malicious-domain.com

==> [3/6] Writing Suricata detection rules...
    Rules written to suricata/rules/local.rules

==> [4/6] Starting Suricata...
    project-radiant-suricata — Up 5 seconds

==> [5/6] Simulating attack traffic...
    Attack traffic sent.

==> [6/6] Checking Suricata detection...

--- fast.log alerts ---
04/17/2026-21:47:32 [**] [1:9000001:1] RADIANT - Malicious Domain DNS Query [**] {UDP} 192.168.50.100 -> 8.8.8.8:53

--- eve.json alerts ---
{"timestamp":"2026-04-17T21:47:32","event_type":"alert","signature":"RADIANT - Malicious Domain DNS Query",...}

======================================================
  PROJECT RADIANT — Demo Complete
======================================================
  MISP Dashboard : http://192.168.50.100
  Email          : admin@radiant.lab
  Password       : admin@1234
  Fast log       : logs/suricata/fast.log
  Eve JSON       : logs/suricata/eve.json
======================================================
```

---

## 7. Operations Reference

### Start / stop Suricata

```bash
# Start (build + launch)
sudo bash scripts/start.sh

# Stop
docker compose down

# Restart
docker compose restart suricata
```

### Monitor alerts

```bash
# Live tail — both logs simultaneously
sudo bash scripts/tail-alerts.sh

# Fast log only
tail -f logs/suricata/fast.log

# Eve JSON — pretty-printed
tail -f logs/suricata/eve.json | python3 -m json.tool

# Filter RADIANT alerts only
grep "RADIANT" logs/suricata/fast.log
```

### Generate test traffic

```bash
# Send traffic to a specific host
sudo bash scripts/test-traffic.sh 192.168.50.10
```

### Container diagnostics

```bash
# View Suricata startup logs
docker compose logs suricata

# Live container logs
docker compose logs -f suricata

# Container status
docker compose ps
```

### Update rules without full rebuild

```bash
# Edit rules
nano suricata/rules/local.rules

# Restart Suricata to reload
sudo bash scripts/start.sh
```

---

## 8. Credentials Reference

| System  | Field    | Value                   |
|---------|----------|-------------------------|
| MISP    | URL      | `http://192.168.50.100` |
| MISP    | Email    | `admin@radiant.lab`     |
| MISP    | Password | `admin@1234`            |
| MISP    | Org      | `RADIANT`               |

To reset MISP credentials:

```bash
sudo bash scripts/reset-misp-credentials.sh
```

---

## 9. Troubleshooting

### MISP returns HTTP 500

Check the Apache error log:

```bash
sudo tail -50 /var/log/apache2/misp_error.log
```

If you see `Cannot declare class Attribute`, PHP 8.x is active. Fix:

```bash
sudo a2dismod php8.3
sudo a2enmod php7.4
sudo systemctl restart apache2
```

### MISP login credentials incorrect

Reset directly via MySQL:

```bash
sudo bash scripts/reset-misp-credentials.sh
```

### Suricata container not starting

Check what interface is configured:

```bash
cat .env
ip link show
```

Verify the interface name matches (e.g. `ens33`, `eth0`, `enp0s3`). Update `.env` and restart:

```bash
sudo bash scripts/start.sh
docker compose logs suricata
```

### No alerts appearing in fast.log

Verify Suricata is running and listening:

```bash
docker compose ps
docker compose logs suricata | grep "Suricata is ready"
```

Check that rules are loaded:

```bash
docker compose logs suricata | grep "9000001"
```

Generate traffic manually:

```bash
nslookup malicious-domain.com 8.8.8.8
curl -s http://malicious-domain.com
```

### AI scripts fail with authentication error

Ensure the API key is exported before running:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
python3 scripts/ai-classify-alerts.py
```

### Composer / PHP dependency errors during MISP install

If vendor files have PHP 8 union type syntax errors:

```bash
cd /var/www/MISP/app
rm -f composer.lock
php7.4 composer.phar config platform.php 7.4
php7.4 -d memory_limit=-1 composer.phar install --no-dev --no-interaction --ignore-platform-reqs
```

---

## License

This project was developed for educational and demonstration purposes as part of a cybersecurity lab environment. All IOCs, domain names, and IP addresses used are simulated and for testing only.
