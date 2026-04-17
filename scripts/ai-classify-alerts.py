#!/usr/bin/env python3
"""
Project RADIANT — AI Alert Classification
Reads Suricata eve.json alerts and classifies each using rule-based intelligence.
"""

import json
import os
import sys
import argparse
import time

EVE_LOG_DEFAULT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "logs", "suricata", "eve.json"
)

RULES = [
    {
        "keywords": ["dns", "malicious", "domain"],
        "severity": "HIGH",
        "category": "DNS-based C2 Communication",
        "summary": "Host queried a known malicious domain over DNS, indicating possible C2 beacon or malware activity.",
        "action": "block",
    },
    {
        "keywords": ["http", "malicious", "domain"],
        "severity": "HIGH",
        "category": "Malicious HTTP Request",
        "summary": "Outbound HTTP request to a known malicious domain detected — possible malware download or C2 channel.",
        "action": "block",
    },
    {
        "keywords": ["icmp", "probe", "scan"],
        "severity": "MEDIUM",
        "category": "Network Reconnaissance",
        "summary": "ICMP probe detected targeting an internal host — possible network scanning or host discovery activity.",
        "action": "monitor",
    },
    {
        "keywords": ["icmp"],
        "severity": "LOW",
        "category": "ICMP Activity",
        "summary": "ICMP traffic detected to lab host — could be reconnaissance or routine ping.",
        "action": "monitor",
    },
    {
        "keywords": ["port", "scan"],
        "severity": "MEDIUM",
        "category": "Port Scan",
        "summary": "Port scanning behaviour detected from source — attacker may be mapping open services.",
        "action": "investigate",
    },
    {
        "keywords": ["brute", "force", "auth"],
        "severity": "CRITICAL",
        "category": "Brute Force Attack",
        "summary": "Repeated authentication attempts detected — possible credential brute-force in progress.",
        "action": "block",
    },
]

DEFAULT_CLASSIFICATION = {
    "severity": "MEDIUM",
    "category": "Suspicious Network Activity",
    "summary": "Unclassified alert triggered by Suricata IDS — manual investigation recommended.",
    "action": "investigate",
}


def classify_alert(alert: dict) -> dict:
    sig = (alert.get("alert", {}).get("signature", "") or "").lower()
    proto = (alert.get("proto", "") or "").lower()
    combined = sig + " " + proto

    for rule in RULES:
        if all(kw in combined for kw in rule["keywords"]):
            return {k: v for k, v in rule.items() if k != "keywords"}

    return DEFAULT_CLASSIFICATION


def load_alerts(path: str, limit: int = 10) -> list:
    alerts = []
    try:
        with open(path, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                    if obj.get("event_type") == "alert":
                        alerts.append(obj)
                except json.JSONDecodeError:
                    continue
    except FileNotFoundError:
        print(f"[ERROR] eve.json not found at: {path}", file=sys.stderr)
        sys.exit(1)
    return alerts[-limit:]


def main():
    parser = argparse.ArgumentParser(description="AI-powered Suricata alert classifier")
    parser.add_argument("--log", default=EVE_LOG_DEFAULT, help="Path to eve.json")
    parser.add_argument("--limit", type=int, default=10, help="Number of recent alerts to classify")
    args = parser.parse_args()

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

    print(f"\n  Found {len(alerts)} alert(s). Classifying with AI engine...\n")

    for i, alert in enumerate(alerts, 1):
        sig = alert.get("alert", {}).get("signature", "unknown")
        src = alert.get("src_ip", "?")
        dst = alert.get("dest_ip", "?")
        proto = alert.get("proto", "?")
        ts = alert.get("timestamp", "")[:19]

        print(f"[{i}/{len(alerts)}] {ts}  {src} -> {dst}  ({proto})  |  {sig}")
        time.sleep(0.3)

        classification = classify_alert(alert)

        print(f"        Severity : {classification['severity']}")
        print(f"        Category : {classification['category']}")
        print(f"        Summary  : {classification['summary']}")
        print(f"        Action   : {classification['action']}")
        print()

    print("=" * 60)
    print("  Classification complete.")
    print("=" * 60)


if __name__ == "__main__":
    main()
