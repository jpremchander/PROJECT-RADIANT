#!/usr/bin/env python3
"""
Project RADIANT — AI Alert Classification
Reads Suricata eve.json alerts and classifies each with Claude AI.
"""

import json
import os
import sys
import argparse
import anthropic

EVE_LOG_DEFAULT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "logs", "suricata", "eve.json"
)

SYSTEM_PROMPT = """\
You are a cybersecurity analyst. You receive a Suricata IDS alert in JSON format.
Classify it with:
1. Severity  : CRITICAL / HIGH / MEDIUM / LOW / INFO
2. Category  : e.g. Malware C2, DNS Exfiltration, Port Scan, Brute Force, Benign, etc.
3. Summary   : one sentence describing what happened and why it matters.
4. Action    : recommended immediate response (block, monitor, investigate, ignore).

Reply ONLY as valid JSON with keys: severity, category, summary, action.
"""


def classify_alert(client: anthropic.Anthropic, alert: dict) -> dict:
    alert_text = json.dumps(alert, indent=2)
    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=256,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": alert_text}],
    )
    raw = message.content[0].text.strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"severity": "UNKNOWN", "category": "UNKNOWN", "summary": raw, "action": "review"}


def load_alerts(path: str, event_type: str = "alert", limit: int = 10) -> list[dict]:
    alerts = []
    try:
        with open(path, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                    if obj.get("event_type") == event_type:
                        alerts.append(obj)
                except json.JSONDecodeError:
                    continue
    except FileNotFoundError:
        print(f"[ERROR] eve.json not found at: {path}", file=sys.stderr)
        sys.exit(1)
    return alerts[-limit:]  # most recent N alerts


def main():
    parser = argparse.ArgumentParser(description="AI-powered Suricata alert classifier")
    parser.add_argument("--log", default=EVE_LOG_DEFAULT, help="Path to eve.json")
    parser.add_argument("--limit", type=int, default=10, help="Number of recent alerts to classify")
    parser.add_argument("--api-key", default=os.environ.get("ANTHROPIC_API_KEY"), help="Anthropic API key")
    args = parser.parse_args()

    if not args.api_key:
        print("[ERROR] Set ANTHROPIC_API_KEY environment variable or pass --api-key", file=sys.stderr)
        sys.exit(1)

    client = anthropic.Anthropic(api_key=args.api_key)

    print()
    print("=" * 60)
    print("  PROJECT RADIANT — AI Alert Classification")
    print("=" * 60)
    print(f"  Log  : {args.log}")
    print(f"  Limit: {args.limit} most recent alerts")
    print("=" * 60)

    alerts = load_alerts(args.log, limit=args.limit)
    if not alerts:
        print("\n  No alerts found in eve.json — run complete-radiant.sh first.")
        sys.exit(0)

    print(f"\n  Found {len(alerts)} alert(s). Classifying with Claude AI...\n")

    for i, alert in enumerate(alerts, 1):
        sig = alert.get("alert", {}).get("signature", "unknown")
        src = alert.get("src_ip", "?")
        dst = alert.get("dest_ip", "?")
        proto = alert.get("proto", "?")
        ts = alert.get("timestamp", "")[:19]

        print(f"[{i}/{len(alerts)}] {ts}  {src} → {dst}  ({proto})  |  {sig}")

        classification = classify_alert(client, alert)

        print(f"        Severity : {classification.get('severity', '?')}")
        print(f"        Category : {classification.get('category', '?')}")
        print(f"        Summary  : {classification.get('summary', '?')}")
        print(f"        Action   : {classification.get('action', '?')}")
        print()

    print("=" * 60)
    print("  Classification complete.")
    print("=" * 60)


if __name__ == "__main__":
    main()
