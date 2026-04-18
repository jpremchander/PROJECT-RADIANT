# Project RADIANT — Live Demo Script
## Simple Speaker Notes & Step-by-Step Commands

---

## Before You Start

Open these side by side before recording:
- **Ubuntu VM** — terminal ready at `~/PROJECT-RADIANT`
- **Browser** — `http://192.168.50.100` (MISP login page)

---

## SECTION 1 — Environment Overview

**Say:**
> "This is Project RADIANT — a Threat Intelligence-Driven Intrusion Detection System. We have two components: MISP running natively on Ubuntu for threat intelligence management, and Suricata running in Docker as our network IDS."

**Show on screen — Ubuntu terminal:**
```bash
# Show system info
uname -a
free -h
ip addr show ens33
```

**Say:**
> "MISP is installed on Ubuntu 24.04 with PHP 7.4 and MariaDB. Suricata runs in Docker using host network mode so it can passively inspect all traffic on this interface."

```bash
# Show services are running
systemctl status apache2 --no-pager -l
systemctl status mariadb --no-pager -l
docker compose ps
```

**Say:**
> "All services are up — Apache serving MISP, MariaDB holding the threat database, and the Suricata container monitoring the network."

---

## SECTION 2 — MISP Login & Platform Tour

**Switch to browser.**

**Say:**
> "Let's log into MISP. The platform is accessible on our lab network at 192.168.50.100."

**Do:**
1. Go to `http://192.168.50.100`
2. Enter email: `admin@radiant.lab`
3. Enter password: `admin@1234`
4. Click Login

**Say:**
> "We're logged in as the Admin user of the RADIANT organisation. MISP has role-based access — Admins manage the full platform, Org Admins manage users within their organisation, and standard users create and consume threat events."

**Show on screen:**
- Click **Administration → List Users** — show the admin account
- Click **Administration → List Organisations** — show RADIANT org

**Say:**
> "One organisation, one admin user — this is a focused lab environment built specifically for this demonstration."

---

## SECTION 3 — External Threat Feed

**Say:**
> "MISP supports external threat intelligence feeds. Let's configure one now."

**Do:**
1. Click **Sync Actions → Feeds**
2. Click **Load default feed metadata**
3. Find **CIRCL OSINT Feed** in the list
4. Toggle it **Enabled**
5. Click **Fetch and store all feed data**

**Say:**
> "This pulls live threat events from the CIRCL OSINT feed — a community-maintained source of malicious IPs, domains, and hashes. MISP stores these as structured events with full IOC attributes."

**Wait for fetch, then:**
- Click **Event List** to show populated events from the feed

**Say:**
> "Each of these events came from the external feed. Every event contains attributes — the actual indicators like domain names, IP addresses, file hashes — that analysts and detection systems can act on."

---

## SECTION 4 — Manual IOC Ingestion

**Say:**
> "Now let's create a threat event manually. This simulates an analyst adding a newly discovered IOC that isn't in any public feed yet."

**Do:**
1. Click **Event Actions → Add Event**
2. Fill in:
   - Event Info: `Malicious Domain — Command and Control`
   - Threat Level: `High`
   - Analysis: `Completed`
   - Distribution: `Your Organisation Only`
3. Click **Submit**

**Say:**
> "The event is created. Now let's add the IOC — the specific indicator we want to detect."

**Do:**
1. Click **Add Attribute**
2. Fill in:
   - Category: `Network activity`
   - Type: `domain`
   - Value: `malicious-domain.com`
   - Check the **IDS** checkbox
3. Click **Submit**

**Say:**
> "The IDS checkbox is critical — it flags this indicator for export to detection systems. Only IDS-flagged attributes get converted into Suricata rules. The attribute is now live in MISP and ready to drive detection."

---

## SECTION 5 — Write Suricata Rules

**Switch to Ubuntu terminal.**

**Say:**
> "With the IOC in MISP, we now write the Suricata detection rules. In a production environment this export is automated. For the demo, we'll show the rules file directly."

```bash
cat suricata/rules/local.rules
```

**Say:**
> "These three rules cover all traffic patterns for our IOC — DNS queries for the malicious domain, HTTP requests to the domain, and ICMP probes on the network. Each rule has a unique SID and a descriptive message prefixed with RADIANT so we can identify our rules instantly in the logs."

---

## SECTION 6 — Start Suricata & Run Full Demo

**Say:**
> "Now we run the complete demo pipeline — this single script starts Suricata, simulates attack traffic, and shows the detections."

```bash
sudo bash scripts/complete-radiant.sh
```

**While it runs, narrate each step:**

- **Step 1** — *"Fetching the MISP API key from the database."*
- **Step 2** — *"Creating a new MISP threat event via the REST API."*
- **Step 2b** — *"Adding the malicious domain as an IOC attribute."*
- **Step 3** — *"Writing the Suricata detection rules to the rules file."*
- **Step 4** — *"Building and starting the Suricata Docker container."*
- **Step 5** — *"Simulating attack traffic — DNS query, HTTP request, and ICMP ping to the malicious domain."*
- **Step 6** — *"And here are the detections — Suricata has fired alerts on every piece of simulated traffic."*

**Say:**
> "We can see the RADIANT rules firing in fast.log and in eve.json. The DNS query to malicious-domain.com was detected, timestamped, and logged with full source and destination information."

---

## SECTION 7 — Show Detection Evidence

**Say:**
> "Let's look at the alert logs in detail."

```bash
# Human-readable alerts
grep "RADIANT" logs/suricata/fast.log
```

**Say:**
> "Every line here is a confirmed detection. The signature name, timestamp, protocol, and source-destination pair are all captured."

```bash
# Structured JSON alerts
grep '"event_type":"alert"' logs/suricata/eve.json | tail -3 | python3 -m json.tool
```

**Say:**
> "The eve.json log gives us the full structured record — this is what a SIEM would ingest. It contains the flow ID, interface, protocol, full IP details, and the alert signature that triggered."

---

## SECTION 8 — Live Alert Feed

**Say:**
> "We can also watch alerts in real time as traffic hits the network."

```bash
sudo bash scripts/tail-alerts.sh
```

**In a second terminal, generate traffic:**
```bash
nslookup malicious-domain.com 8.8.8.8 || true
curl -s --max-time 5 http://malicious-domain.com -o /dev/null || true
```

**Say:**
> "Watch the alerts appear in real time. Every DNS query and HTTP request to the malicious domain triggers an immediate alert — this is live network detection driven by the IOC we added to MISP just minutes ago."

Press `Ctrl+C` to stop tailing.

---

## SECTION 9 — Detection Summary

**Say:**
> "Let's pull a quick summary of everything detected during this demonstration."

```bash
echo "=== Total Alerts Detected ===" && \
grep -c '"event_type":"alert"' logs/suricata/eve.json

echo "" && echo "=== Breakdown by Rule ===" && \
grep '"event_type":"alert"' logs/suricata/eve.json | \
python3 -c "
import sys, json
from collections import Counter
sigs = []
for line in sys.stdin:
    try:
        sigs.append(json.loads(line).get('alert',{}).get('signature','unknown'))
    except: pass
[print(f'  {c:>4}x  {s}') for s, c in Counter(sigs).most_common()]
"
```

**Say:**
> "This confirms our detection count broken down by rule. Every alert maps back to the IOC we ingested from MISP — closing the full loop from threat intelligence to network detection."

---

## SECTION 10 — MISP Evidence — Close the Loop

**Switch to browser.**

**Say:**
> "Finally, let's return to MISP to confirm the full intelligence picture."

**Do:**
1. Go to `http://192.168.50.100/events/index`
2. Click the event: `Malicious Domain — Command and Control`
3. Show the IOC attribute with IDS flag

**Say:**
> "Here in MISP we can see the threat event with the malicious domain IOC — the same indicator that drove the Suricata detections we just witnessed. This is the complete Project RADIANT pipeline:"

> "Threat indicator ingested into MISP → exported as a Suricata detection rule → live traffic inspected → alerts generated → evidence logged in fast.log and eve.json — all from a single IOC."

---

## Quick Reference — Credentials

| System | URL                     | Email               | Password   |
|--------|-------------------------|---------------------|------------|
| MISP   | http://192.168.50.100   | admin@radiant.lab   | admin@1234 |

## Quick Reference — Key Commands

| Action                  | Command                                      |
|-------------------------|----------------------------------------------|
| Start Suricata          | `sudo bash scripts/start.sh`                 |
| Run full demo           | `sudo bash scripts/complete-radiant.sh`      |
| Watch live alerts       | `sudo bash scripts/tail-alerts.sh`           |
| View fast.log           | `grep "RADIANT" logs/suricata/fast.log`      |
| View eve.json           | `tail -f logs/suricata/eve.json`             |
| Check container status  | `docker compose ps`                          |
| Reset MISP password     | `sudo bash scripts/reset-misp-credentials.sh` |

---

*Project RADIANT — Lab environment for educational demonstration purposes.*
