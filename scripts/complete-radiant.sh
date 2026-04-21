#!/usr/bin/env bash
# Project RADIANT — Full demo: MISP IOC → Suricata rule → Attack simulation → Detection

set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MISP_URL="http://192.168.10.100"
MISP_DB="misp"
RULES_FILE="$ROOT_DIR/suricata/rules/local.rules"
FAST_LOG="$ROOT_DIR/logs/suricata/fast.log"
EVE_LOG="$ROOT_DIR/logs/suricata/eve.json"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: run as root — sudo bash scripts/complete-radiant.sh" >&2
    exit 1
fi

echo ""
echo "======================================================"
echo "  PROJECT RADIANT — Full Demo"
echo "======================================================"

# ── Step 1: Get MISP API key ──────────────────────────────────────────────────
echo ""
echo "==> [1/6] Fetching MISP API key..."
AUTHKEY=$(mysql -u root "$MISP_DB" -se "SELECT authkey FROM users WHERE id=1;")
echo "    API Key: $AUTHKEY"

# ── Step 2: Create MISP event with IOC ───────────────────────────────────────
echo ""
echo "==> [2/6] Creating MISP threat event..."
EVENT=$(curl -s -X POST "$MISP_URL/events" \
    -H "Authorization: $AUTHKEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d '{
        "Event": {
            "info":             "Project RADIANT — Malicious Domain IOC",
            "threat_level_id":  "1",
            "analysis":         "2",
            "distribution":     "0"
        }
    }')

EVENT_ID=$(echo "$EVENT" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['Event']['id'])" 2>/dev/null || echo "")

if [ -z "$EVENT_ID" ]; then
    echo "    Warning: could not create event via API — create it manually in MISP dashboard."
else
    echo "    Event created: ID=$EVENT_ID"

    echo "==> [2b] Adding domain IOC to event..."
    curl -s -X POST "$MISP_URL/attributes" \
        -H "Authorization: $AUTHKEY" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "{
            \"Attribute\": {
                \"event_id\": \"$EVENT_ID\",
                \"type\":     \"domain\",
                \"category\": \"Network activity\",
                \"value\":    \"malicious-domain.com\",
                \"to_ids\":   true
            }
        }" > /dev/null
    echo "    IOC added: malicious-domain.com"
fi

# ── Step 3: Write Suricata rules ──────────────────────────────────────────────
echo ""
echo "==> [3/6] Writing Suricata detection rules..."
cat > "$RULES_FILE" << 'RULES'
# Project RADIANT — MISP-driven detection rules
alert dns  any any -> any any (msg:"RADIANT - Malicious Domain DNS Query"; dns.query; content:"malicious-domain.com"; nocase; sid:9000001; rev:1;)
alert http any any -> any any (msg:"RADIANT - Malicious Domain HTTP Request"; http.host; content:"malicious-domain.com"; nocase; sid:9000002; rev:1;)
alert icmp any any -> $HOME_NET any (msg:"RADIANT - ICMP Probe Detected"; sid:9000003; rev:1;)
RULES
echo "    Rules written to $RULES_FILE"

# ── Step 4: Start Suricata ────────────────────────────────────────────────────
echo ""
echo "==> [4/6] Starting Suricata..."
cd "$ROOT_DIR"
if docker compose version >/dev/null 2>&1; then
    docker compose up -d --build
elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose up -d --build
fi
sleep 5
echo "    Suricata status:"
docker ps --filter name=project-radiant-suricata --format "    {{.Names}} — {{.Status}}"

# ── Step 5: Simulate attack ───────────────────────────────────────────────────
echo ""
echo "==> [5/6] Simulating attack traffic..."
sleep 3
curl -s --max-time 5 http://malicious-domain.com -o /dev/null || true
nslookup malicious-domain.com 8.8.8.8 || true
ping -c 3 192.168.10.100 || true
echo "    Attack traffic sent."

# ── Step 6: Show detection evidence ──────────────────────────────────────────
echo ""
echo "==> [6/6] Checking Suricata detection..."
sleep 5

echo ""
echo "--- fast.log alerts ---"
if [ -f "$FAST_LOG" ] && grep -q "RADIANT" "$FAST_LOG" 2>/dev/null; then
    grep "RADIANT" "$FAST_LOG"
else
    echo "    (no alerts yet — run: tail -f $FAST_LOG)"
fi

echo ""
echo "--- eve.json alerts ---"
if [ -f "$EVE_LOG" ] && grep -q "malicious-domain\|RADIANT" "$EVE_LOG" 2>/dev/null; then
    grep "malicious-domain\|RADIANT" "$EVE_LOG" | tail -5
else
    echo "    (no JSON alerts yet — run: tail -f $EVE_LOG)"
fi

echo ""
echo "======================================================"
echo "  PROJECT RADIANT — Demo Complete"
echo "======================================================"
echo "  MISP Dashboard : http://192.168.10.100"
echo "  Email          : admin@radiant.lab"
echo "  Password       : admin@1234"
echo "  Fast log       : $FAST_LOG"
echo "  Eve JSON       : $EVE_LOG"
echo "======================================================"
