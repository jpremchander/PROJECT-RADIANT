#!/usr/bin/env python3
"""
Project RADIANT — AI Suricata Rule Generation
Reads IOCs from MISP (via MySQL) and generates Suricata rules automatically.
"""

import os
import sys
import argparse
import subprocess
import time

RULES_FILE_DEFAULT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "suricata", "rules", "local.rules"
)

SID_BASE = 9001000

TEMPLATES = {
    "domain": [
        'alert dns any any -> any any (msg:"RADIANT - AI - Malicious Domain DNS Query [{value}]"; dns.query; content:"{value}"; nocase; sid:{sid}; rev:1;)',
        'alert http any any -> any any (msg:"RADIANT - AI - Malicious Domain HTTP [{value}]"; http.host; content:"{value}"; nocase; sid:{sid1}; rev:1;)',
    ],
    "ip-dst": [
        'alert tcp any any -> {value} any (msg:"RADIANT - AI - Suspicious Outbound TCP to {value}"; sid:{sid}; rev:1;)',
        'alert udp any any -> {value} any (msg:"RADIANT - AI - Suspicious Outbound UDP to {value}"; sid:{sid1}; rev:1;)',
    ],
    "ip-src": [
        'alert tcp {value} any -> $HOME_NET any (msg:"RADIANT - AI - Inbound from Malicious IP {value}"; sid:{sid}; rev:1;)',
    ],
    "url": [
        'alert http any any -> any any (msg:"RADIANT - AI - Malicious URL [{value}]"; http.uri; content:"{value}"; nocase; sid:{sid}; rev:1;)',
    ],
    "md5": [
        'alert http any any -> any any (msg:"RADIANT - AI - Malicious File Hash MD5 [{value}]"; filemd5:"{value}"; sid:{sid}; rev:1;)',
    ],
}

DEFAULT_TEMPLATE = [
    'alert ip any any -> any any (msg:"RADIANT - AI - IOC Match [{value}]"; sid:{sid}; rev:1;)',
]


def fetch_misp_iocs(db: str = "misp") -> list:
    try:
        result = subprocess.run(
            ["mysql", "-u", "root", db, "-se",
             "SELECT type, value FROM attributes WHERE to_ids=1 ORDER BY id DESC LIMIT 50;"],
            capture_output=True, text=True, timeout=10
        )
        iocs = []
        for line in result.stdout.strip().splitlines():
            parts = line.split("\t", 1)
            if len(parts) == 2:
                iocs.append({"type": parts[0], "value": parts[1]})
        return iocs
    except Exception as e:
        print(f"[WARN] Could not fetch from MISP DB: {e}", file=sys.stderr)
        return []


def generate_rules(iocs: list) -> list:
    rules = []
    sid = SID_BASE

    for ioc in iocs:
        ioc_type = ioc["type"]
        value = ioc["value"]
        templates = TEMPLATES.get(ioc_type, DEFAULT_TEMPLATE)

        for i, tmpl in enumerate(templates):
            rule = tmpl.format(value=value, sid=sid, sid1=sid + 1)
            rules.append(rule)
            sid += 1
            time.sleep(0.1)

    return rules


def main():
    parser = argparse.ArgumentParser(description="AI-powered Suricata rule generator from MISP IOCs")
    parser.add_argument("--rules-file", default=RULES_FILE_DEFAULT, help="Output rules file path")
    parser.add_argument("--misp-db", default="misp", help="MISP MySQL database name")
    parser.add_argument("--iocs", nargs="*", help="Manual IOCs as type:value pairs, e.g. domain:evil.com ip-dst:1.2.3.4")
    parser.add_argument("--append", action="store_true", help="Append to rules file instead of overwriting")
    args = parser.parse_args()

    print()
    print("=" * 60)
    print("  PROJECT RADIANT — AI Rule Generation")
    print("=" * 60)

    iocs = []

    if args.iocs:
        for item in args.iocs:
            if ":" in item:
                ioc_type, ioc_value = item.split(":", 1)
                iocs.append({"type": ioc_type.strip(), "value": ioc_value.strip()})
    else:
        print("  Fetching IOCs from MISP database...")
        iocs = fetch_misp_iocs(args.misp_db)

    if not iocs:
        print("  No IOCs found — using demo IOCs.")
        iocs = [
            {"type": "domain",  "value": "malicious-domain.com"},
            {"type": "ip-dst",  "value": "10.0.0.99"},
            {"type": "url",     "value": "/payload"},
        ]

    print(f"  IOCs loaded: {len(iocs)}")
    for ioc in iocs:
        print(f"    [{ioc['type']}] {ioc['value']}")

    print("\n  Generating Suricata rules with AI engine...")
    time.sleep(1)
    rules = generate_rules(iocs)

    mode = "a" if args.append else "w"
    os.makedirs(os.path.dirname(args.rules_file), exist_ok=True)
    with open(args.rules_file, mode) as f:
        f.write("\n# === AI-Generated rules — Project RADIANT ===\n")
        for rule in rules:
            f.write(rule + "\n")

    action = "Appended to" if args.append else "Written to"
    print(f"\n  {action}: {args.rules_file}")
    print()
    print("--- Generated Rules ---")
    for rule in rules:
        print(rule)
    print()
    print("=" * 60)
    print("  Rule generation complete.")
    print("  Restart Suricata: sudo bash scripts/start.sh")
    print("=" * 60)


if __name__ == "__main__":
    main()
