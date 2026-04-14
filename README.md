# PROJECT-RADIANT

Project RADIANT is a lightweight cyber defense lab stack that combines:

- MISP for threat intelligence collaboration
- Suricata for network detection
- Elasticsearch and Kibana for centralized log analysis (ELK-lite)
- n8n for SOAR-style automation playbooks

This repository is designed for fast deployment in a college VMware vSphere lab using Docker Compose.

## 1. Architecture

### Core Stack

- `misp`:
	- Threat intel platform (containerized)
	- Exposed on port `8080` by default
- `suricata`:
	- IDS engine with a lightweight local rule set
	- Writes alerts to `logs/suricata/eve.json`

### Monitoring Stack

- `elasticsearch`:
	- Search and index backend for Suricata events
	- Exposed on port `9200`
- `kibana`:
	- Web UI for search, dashboards, and visual analytics
	- Exposed on port `5601`
- `fluent-bit`:
	- Ships Suricata `eve.json` events into Elasticsearch
- `n8n`:
	- SOAR-style automation workflows and response playbooks
	- Exposed on port `5678`

## 2. Prerequisites (vSphere VM)

Recommended for a smooth lab deployment:

- Ubuntu Server 22.04 LTS (or equivalent Linux VM)
- 8 vCPU
- 16 GB RAM (12 GB minimum for light use)
- 100 GB disk
- Docker Engine + Docker Compose plugin
- Internet access to pull container images

Optional but recommended:

- Static IP for easier dashboard access
- NTP time sync enabled

## 3. Repository Layout

- `.env`: core stack environment variables
- `docker-compose.yml`: core stack (MISP + Suricata)
- `misp/`: MISP container wrapper and config mount
- `suricata/`: Suricata config and rules
- `logs/`: host-side logs
- `monitoring/docker-compose.monitoring.yml`: monitoring stack
- `monitoring/.env.monitoring.example`: monitoring env template
- `monitoring/fluent-bit/`: log forwarding config
- `scripts/start.sh`: start core stack
- `scripts/test-traffic.sh`: generate test traffic for Suricata rule match
- `scripts/start-monitoring.sh`: start monitoring stack

## 4. Step-by-Step Deployment

### Step 1: Clone and enter project

```bash
git clone <your-repo-url>
cd PROJECT-RADIANT
```

### Step 2: Configure core environment

Edit `.env` and change at minimum:

- `MISP_ADMIN_PASSWORD`
- `MISP_BASEURL` (set to your VM IP/FQDN if remote access is needed)

### Step 3: Start core stack (MISP + Suricata)

```bash
./scripts/start.sh
```

### Step 4: Validate core services

- Open `http://<vm-ip>:8080` for MISP
- Check container status:

```bash
docker compose ps
```

### Step 5: Generate test detection traffic

```bash
./scripts/test-traffic.sh
```

Expected result:

- Suricata should log an alert in `logs/suricata/eve.json` for `/radiant-test`.

## 5. Monitoring + SIEM/SOAR Setup

### Step 1: Prepare monitoring environment file

```bash
cp monitoring/.env.monitoring.example monitoring/.env.monitoring
```

Edit `monitoring/.env.monitoring`:

- Set `ELASTICSEARCH_HOSTS` if you need a custom host mapping
- Set `KIBANA_PUBLIC_BASE_URL` to your VM URL (for example `http://10.10.10.20:5601`)

### Step 2: Start monitoring stack

```bash
./scripts/start-monitoring.sh
```

### Step 3: Access tools

- Kibana: `http://<vm-ip>:5601`
- n8n: `http://<vm-ip>:5678`

Fluent Bit is preconfigured to send Suricata logs into Elasticsearch index `suricata-eve`.

### Step 4: Create Kibana data view

In Kibana UI:

1. Go to `Stack Management` -> `Data Views`
2. Create a data view for `suricata-eve*`
3. Set `timestamp` as the time field
4. Open `Discover` to validate incoming Suricata events

### Step 5: Build basic SOAR workflow in n8n

Example workflow:

1. Trigger: Elasticsearch/Kibana alert webhook
2. Filter: Only high-severity Suricata alerts
3. Actions:
	 - Send alert to Slack/Teams/email
	 - Open incident ticket
	 - Call MISP API to tag or enrich indicator

## 6. vSphere Deployment Notes

- Put VM NIC in bridged/accessible network so dashboards are reachable.
- If using firewall rules, allow inbound ports `8080`, `5601`, and `5678` from your lab network.
- For classes, snapshot the VM after successful deployment to reset quickly between labs.

## 7. Operations

### Start/Stop

Core stack:

```bash
docker compose up -d
docker compose down
```

Monitoring stack:

```bash
docker compose --env-file monitoring/.env.monitoring -f monitoring/docker-compose.monitoring.yml up -d
docker compose --env-file monitoring/.env.monitoring -f monitoring/docker-compose.monitoring.yml down
```

### Logs

```bash
docker compose logs -f misp
docker compose logs -f suricata
docker compose --env-file monitoring/.env.monitoring -f monitoring/docker-compose.monitoring.yml logs -f kibana
```

## 8. Roadmap (Suggested)

1. Add TLS and reverse proxy (Nginx or Traefik)
2. Add role-based access control hardening
3. Add backup/restore scripts for OpenSearch and MongoDB volumes
4. Add MISP-to-Suricata rule feed automation
5. Add prebuilt n8n playbooks for incident response labs