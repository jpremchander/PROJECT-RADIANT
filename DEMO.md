# Advanced Threat Intelligence & Detection — Demonstration Script
## Project RADIANT | MISP + Suricata + AI

> Each section includes what to show on screen, what to say, and commands to run.

---

## Table of Contents

1. [Environment Planning & Readiness](#1-environment-planning--readiness)
2. [Installation & Base Configuration](#2-installation--base-configuration)
3. [Ingestion](#3-ingestion)
4. [Operational Configuration](#4-operational-configuration)
5. [AI Tool Configuration & Integration](#5-ai-tool-configuration--integration)
6. [Dashboards, Reporting & Visualization](#6-dashboards-reporting--visualization)

---

## 1. Environment Planning & Readiness

### What to show on screen
- VMware Workstation with two VMs visible: **Ubuntu** and **Win-11**
- Ubuntu VM system info terminal
- PfSense firewall dashboard (if accessible)

### Talking Points

> "Before we begin the demonstration, let's walk through the environment planning and readiness checks that were completed before deployment."

---

### Supported Operating Systems

| Component    | Platform              | Version        |
|--------------|-----------------------|----------------|
| MISP         | Ubuntu Server         | 24.04 LTS      |
| Suricata IDS | Docker on Ubuntu      | Latest stable  |
| Management   | Windows 11            | 23H2+          |
| Hypervisor   | VMware Workstation    | 17+            |

> "Project RADIANT runs MISP natively on Ubuntu 24.04 — this is intentional. MISP requires PHP 7.4 which we installed via the ondrej PPA, because PHP 8.x ships with a built-in Attribute class that directly conflicts with MISP's CakePHP 2.x model. Suricata runs in Docker for clean isolation and easy portability."

---

### Hardware Requirements

Run on Ubuntu:

```bash
echo "=== CPU ===" && nproc
echo "=== RAM ===" && free -h
echo "=== DISK ===" && df -h /
echo "=== INTERFACE ===" && ip link show ens33
```

> "We validated the following minimum requirements before deployment:"

| Resource          | Minimum   | This Lab     |
|-------------------|-----------|--------------|
| CPU               | 2 cores   | 2+ cores     |
| RAM               | 4 GB      | 4–8 GB       |
| Disk              | 40 GB     | 60 GB        |
| Network Interface | 1 NIC     | ens33        |
| Network           | LAN       | 192.168.50.0/24 |

---

### Required Ports & Protocols

> "These are the ports and protocols we opened in the environment for the platform to function:"

| Port | Protocol | Service               | Direction      |
|------|----------|-----------------------|----------------|
| 80   | TCP      | MISP Web UI (HTTP)    | Inbound        |
| 443  | TCP      | MISP Web UI (HTTPS)   | Inbound        |
| 3306 | TCP      | MariaDB (local only)  | Localhost      |
| 6379 | TCP      | Redis (local only)    | Localhost      |
| Any  | Any      | Suricata (passive)    | Passive sniff  |

> "Suricata does not open any listening ports — it operates in passive IDS mode, sniffing all traffic on the ens33 interface without injecting or blocking packets."

---

### Hypervisor & Container Requirements

> "The deployment uses two virtualization layers:"

- **VMware Workstation 17** — hosts the Ubuntu and Windows VMs
- **Docker Engine** — runs the Suricata container in host network mode
- **Host network mode** means Suricata shares the VM's network stack and sees all traffic on ens33 directly

Verify Docker:

```bash
docker --version
docker compose version
```

---

## 2. Installation & Base Configuration

### What to show on screen
- Ubuntu terminal running the install script
- MISP login page in browser
- MISP dashboard after login
- Docker container status

### Talking Points

> "Now let's walk through the installation and base configuration of the platform."

---

### MISP Installation

> "MISP is installed using a custom bash script — `install-misp.sh` — which performs a full native installation without relying on any external auto-installer. This gives us full control over PHP versions, database configuration, and credentials."

Show the script:

```bash
cat scripts/install-misp.sh
```

> "The script performs nine steps: package installation, MariaDB setup, Redis, MISP clone, Composer dependencies, Python dependencies, config file generation, Apache configuration, and finally credential seeding via a bcrypt hash written directly to MySQL — completely bypassing the CakePHP CLI which has PHP version conflicts."

Run the installer (show it was already done):

```bash
# Already installed — verify it's running
systemctl status apache2 --no-pager
systemctl status mariadb --no-pager
systemctl status redis-server --no-pager
```

---

### Login & Authentication

**Switch to browser — navigate to `http://192.168.50.100`**

> "MISP is now accessible on the internal lab network at 192.168.50.100. Let's log in."

| Field    | Value               |
|----------|---------------------|
| Email    | admin@radiant.lab   |
| Password | admin@1234          |

> "After login, MISP presents the main dashboard. Let's talk about user roles."

---

### User Roles in MISP

> "MISP has a role-based access control system with three primary roles:"

| Role       | Capabilities                                                      |
|------------|-------------------------------------------------------------------|
| Admin      | Full access — manage users, orgs, feeds, system config            |
| Org Admin  | Manage users within their organisation, create/edit events        |
| User       | Create and view events, add attributes, consume threat intel      |
| Read Only  | View-only access to shared events — suitable for SOC analysts     |

> "In this demo we are operating as the Admin user of the RADIANT organisation, which gives us full control over the platform."

**On screen — show:** Administration → List Users

---

### Verify Platform Health

```bash
# Suricata container status
docker compose ps

# Suricata logs — confirm rules loaded
docker compose logs suricata --tail 30

# Verify rules file is loaded
docker compose logs suricata | grep "9000001"
```

> "We can confirm all three core services are running — Apache serving MISP, MariaDB holding the threat database, Redis handling background jobs, and Suricata actively monitoring the network interface."

---

## 3. Ingestion

### What to show on screen
- MISP Feeds configuration page
- External feed being enabled and pulled
- Manual event creation with IOC attribute
- Attribute list showing ingested indicators

### Talking Points

> "Now we move to the intelligence ingestion phase — this is where Project RADIANT receives threat indicators from both external and internal sources."

---

### External Threat Feed Configuration

**On screen — navigate to:** Sync Actions → Feeds

> "MISP supports a wide range of external threat intelligence feeds out of the box. These include CIRCL OSINT, abuse.ch, Botvrij, and many others — all formatted as MISP event collections or simple CSV/text lists."

**Enable a feed:**

1. Click **Load default feed metadata**
2. Find **CIRCL OSINT Feed** (or any enabled feed)
3. Click the toggle to **Enable**
4. Click **Fetch and store all feed data**

> "This pulls structured threat events directly from the CIRCL OSINT feed into our local MISP instance. Each event contains attributes — IOCs like IP addresses, domains, hashes, and URLs — that have been validated by the community."

**Wait for fetch, then show:** Event List populated with feed data

---

### Manual IOC Ingestion

> "Beyond external feeds, analysts can manually create threat events with specific IOCs. This is the internal ingestion method — used when the SOC discovers an indicator that isn't in any public feed yet."

**On screen — navigate to:** Event Actions → Add Event

Fill in:

| Field          | Value                                      |
|----------------|--------------------------------------------|
| Event Info     | Malicious Domain — Command and Control     |
| Threat Level   | High                                       |
| Analysis       | Completed                                  |
| Distribution   | Your Organisation Only                     |

Click **Submit**, then add attribute:

| Field    | Value                  |
|----------|------------------------|
| Category | Network activity       |
| Type     | domain                 |
| Value    | malicious-domain.com   |
| IDS      | Enabled (checked)      |

> "The IDS flag is critical — it marks this IOC for export to detection systems like Suricata. Only IDS-flagged attributes get converted into detection rules."

---

### Validate Ingestion of Indicators

**On screen — navigate to:** Event List → click the event

> "We can see the event has been created with the domain IOC attached. Let's validate this from the database level as well."

```bash
mysql -u root misp -se "SELECT id, type, value, to_ids FROM attributes ORDER BY id DESC LIMIT 10;"
```

> "The database confirms the attribute is stored with to_ids=1 — meaning it is flagged for IDS export. This is the data source our AI rule generation script reads from."

---

### Attributes of Incoming Intel

> "Every attribute in MISP carries a rich set of metadata that describes the intelligence:"

| Attribute Field | Description                                                  |
|-----------------|--------------------------------------------------------------|
| Type            | What kind of indicator — domain, IP, URL, MD5, email, etc.  |
| Category        | Context — Network activity, Payload delivery, Artefact, etc.|
| Value           | The actual IOC value                                         |
| to_ids          | Whether this should be pushed to IDS/detection systems       |
| Timestamp       | When the indicator was added                                 |
| Comment         | Analyst notes or source references                           |
| Distribution    | Sharing level — org only, community, or public               |
| Event ID        | Links the attribute back to its parent threat event          |

---

## 4. Operational Configuration

### What to show on screen
- MISP export options
- Suricata rules file
- MISP search and filter interface

### Talking Points

> "With indicators ingested, we now look at operational configuration — how we export intelligence to detection systems and how analysts search and correlate across the dataset."

---

### Export Mechanisms

**On screen — open the MISP event → click Download**

> "MISP supports multiple export formats. For Project RADIANT, we use two primary export paths:"

| Export Format    | Use Case                                          |
|------------------|---------------------------------------------------|
| Suricata Rules   | Direct export to IDS — generates .rules files     |
| STIX 2.0         | Structured sharing with other platforms           |
| CSV              | Simple flat-file export for SIEM ingestion        |
| JSON             | Full event export for API-based integrations      |
| OpenIOC          | Legacy SIEM and endpoint tool compatibility       |

> "We have automated this export step. Our `complete-radiant.sh` script reads the API key from the database, calls the MISP REST API, and writes the Suricata rules file directly — no manual export needed."

Show rules file:

```bash
cat suricata/rules/local.rules
```

---

### Search, Filtering & Correlation

**On screen — navigate to:** Events → Search Events

> "MISP provides powerful search and correlation capabilities. Analysts can search across all attributes by value, type, category, tag, date range, or threat level."

Demonstrate search:

1. Go to **Events → Search Attributes**
2. Search for `malicious-domain.com`
3. Show the result linking back to the event

> "This correlation view shows every event that references this indicator — critical for understanding whether an IOC has been seen in multiple campaigns or threat actors."

**Also show tag-based filtering:**

1. Navigate to **Event Actions → Add Tag** on the event
2. Assign tag: `tlp:red`
3. Filter events by this tag

> "Tags like TLP — Traffic Light Protocol — control sharing decisions. TLP:RED means this intel stays within the RADIANT organisation only."

---

## 5. AI Tool Configuration & Integration

### What to show on screen
- Terminal running `ai-generate-rules.py`
- Generated rules appended to local.rules
- Terminal running `ai-classify-alerts.py`
- Classification output per alert

### Talking Points

> "Project RADIANT integrates AI-powered tooling at two points in the pipeline — rule generation and alert classification. Both tools are built into the repository and require no external services."

---

### AI Rule Generation — Install & Connect

> "The AI rule generation script reads IOCs directly from the MISP MariaDB database, applies an intelligent rule-building engine that maps each IOC type to the correct Suricata protocol and keyword, and writes production-ready detection rules."

Show the script:

```bash
cat scripts/ai-generate-rules.py
```

Run it:

```bash
sudo python3 scripts/ai-generate-rules.py
```

> "Watch as the AI engine processes each IOC from MISP, selects the correct Suricata alert type — DNS for domains, TCP/UDP for IPs, HTTP for URLs — and assigns unique SID numbers starting from 9001000 to avoid conflicts with our manual rules."

Show generated output in rules file:

```bash
cat suricata/rules/local.rules
```

> "The AI-generated rules follow the same structure as manually written rules but are produced instantly from any number of IOCs. This scales the detection capability directly with the intelligence feed."

Reload Suricata with new rules:

```bash
sudo bash scripts/start.sh
docker compose logs suricata --tail 10
```

---

### AI Alert Classification — Validate & Run

> "The second AI component classifies existing Suricata alerts. It reads the structured eve.json log and applies an intelligent classification engine that assigns severity, threat category, a plain-English summary, and a recommended action to each alert."

Run classification:

```bash
python3 scripts/ai-classify-alerts.py
```

> "Notice the output for each alert — severity ranges from LOW to CRITICAL, categories identify the threat pattern such as DNS-based C2 communication or network reconnaissance, and the action field tells the SOC analyst exactly what to do: block, monitor, or investigate."

> "This transforms raw Suricata alerts — which are just signature matches — into actionable intelligence with context and priority, reducing analyst fatigue and improving response time."

---

### Connectivity & Permissions Validation

```bash
# Confirm eve.json exists and has alert data
ls -lh logs/suricata/eve.json
grep -c '"event_type":"alert"' logs/suricata/eve.json

# Confirm rules file is readable by Suricata
docker compose logs suricata | grep "Loading rule"
```

---

## 6. Dashboards, Reporting & Visualization

### What to show on screen
- MISP event list as a live threat dashboard
- fast.log alerts in terminal
- eve.json alerts with AI classification output
- Historical alert count

### Talking Points

> "Finally, let's look at dashboards, reporting, and visualization — bringing together everything the platform has produced into a coherent intelligence picture."

---

### Live Detection Dashboard — fast.log

> "The fast.log is our real-time detection feed. Every line is a confirmed network alert triggered by a MISP-sourced Suricata rule."

```bash
cat logs/suricata/fast.log | grep "RADIANT"
```

> "We can see alerts for our test IOC — malicious-domain.com — across both DNS and HTTP protocols, with timestamps, source and destination IPs, and protocol information. Each alert maps back directly to a MISP event."

---

### Structured Intelligence — eve.json

> "The eve.json log is the SIEM-ready structured output. Every alert is a complete JSON record containing flow ID, interface, protocol, source, destination, and the full Suricata alert metadata."

```bash
grep '"event_type":"alert"' logs/suricata/eve.json | tail -5 | python3 -m json.tool
```

> "This format integrates directly with platforms like Elastic SIEM, Splunk, or Graylog. In a production environment, a Filebeat or Logstash agent would ship these records to a central SIEM in real time."

---

### AI-Generated Tags, Scores & Insights

> "Our AI classification layer adds the intelligence layer on top of raw detections. Let's run the classifier and review the full output."

```bash
python3 scripts/ai-classify-alerts.py --limit 10
```

> "Each alert now carries:"
> - **Severity score** — from LOW to CRITICAL, prioritising analyst response
> - **Threat category** — identifying the attack pattern (C2, recon, exfiltration)
> - **Plain-English summary** — explaining what happened and why it matters
> - **Recommended action** — block, monitor, or investigate

> "This is the intelligence-driven detection loop complete — a domain IOC entered into MISP, automatically converted into a Suricata rule, detected in live traffic, and classified with AI-generated context and priority."

---

### Historical Trends & Detection Summary

> "Let's look at the full detection history to show trend visibility."

```bash
echo "=== Total Alerts ===" && grep -c '"event_type":"alert"' logs/suricata/eve.json

echo "=== Alerts by Signature ===" && grep '"event_type":"alert"' logs/suricata/eve.json \
  | python3 -c "
import sys, json
from collections import Counter
sigs = []
for line in sys.stdin:
    try:
        obj = json.loads(line)
        sigs.append(obj.get('alert', {}).get('signature', 'unknown'))
    except: pass
for sig, count in Counter(sigs).most_common():
    print(f'  {count:>5}x  {sig}')
"

echo "=== Alerts by Protocol ===" && grep '"event_type":"alert"' logs/suricata/eve.json \
  | python3 -c "
import sys, json
from collections import Counter
protos = []
for line in sys.stdin:
    try:
        obj = json.loads(line)
        protos.append(obj.get('proto', 'unknown'))
    except: pass
for proto, count in Counter(protos).most_common():
    print(f'  {count:>5}x  {proto}')
"
```

> "This gives us a complete picture of detection volume by signature and protocol — showing which rules fired the most and which traffic types were flagged. In a production dashboard like Kibana or Grafana, these would be visualized as bar charts and time-series graphs updating in real time."

---

### MISP Event List — Threat Intelligence Dashboard

**Switch to browser — navigate to:** `http://192.168.50.100/events/index`

> "Back in MISP, the event list serves as our threat intelligence dashboard. Every event here represents a confirmed threat with associated IOCs. We can see the event we created during this demonstration — the malicious domain IOC that drove the entire detection pipeline."

> "To summarise what Project RADIANT has demonstrated:"

| Stage              | What Happened                                              |
|--------------------|------------------------------------------------------------|
| Intel Ingestion    | Domain IOC created in MISP with IDS flag                   |
| Rule Generation    | AI engine converted IOC to Suricata DNS + HTTP rules       |
| Live Detection     | Suricata fired alerts on simulated malicious traffic       |
| AI Classification  | Each alert classified with severity, category, and action  |
| Reporting          | Structured eve.json ready for SIEM, trends analysed        |

> "This is the complete Advanced Threat Intelligence and Detection pipeline — from indicator to detection to classified alert — delivered by Project RADIANT."

---

*Project RADIANT — Developed for educational and demonstration purposes.*
*All IOCs, domains, and IP addresses are simulated lab values.*
