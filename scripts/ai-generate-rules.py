#!/usr/bin/env python3
"""
Project RADIANT — AI Suricata Rule Generation
Reads IOCs from MISP (via MySQL or manual input) and generates Suricata rules with Claude AI.
"""

import json
import os
import sys
import argparse
import subprocess
import anthropic

RULES_FILE_DEFAULT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "suricata", "rules", "local.rules"
)

SYSTEM_PROMPT = """\
You are a Suricata IDS rule expert. Given a list of threat IOCs (Indicators of Compromise),
generate valid Suricata 7.x detection rules.

Rules MUST:
- Use correct Suricata syntax
- Include appropriate protocol (dns, http, tcp, icmp)
- Set msg with prefix "RADIANT - AI - "
- Use sid numbers starting from 9001000 incrementing by 1
- Include rev:1
- Be production-ready (no placeholders)

Reply ONLY with the raw Suricata rules, one per line. No explanation, no markdown fences.
"""


def fetch_misp_iocs(db: str = "misp") -> list[dict]:
    """Pull IOCs from MISP MySQL database."""
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


def generate_rules(client: anthropic.Anthropic, iocs: list[dict]) -> str:
    ioc_text = "\n".join(f"- type={ioc['type']} value={ioc['value']}" for ioc in iocs)
    prompt = f"Generate Suricata detection rules for these IOCs:\n\n{ioc_text}"

    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=1024,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text.strip()


def main():
    parser = argparse.ArgumentParser(description="AI-powered Suricata rule generator from MISP IOCs")
    parser.add_argument("--rules-file", default=RULES_FILE_DEFAULT, help="Output rules file path")
    parser.add_argument("--misp-db", default="misp", help="MISP MySQL database name")
    parser.add_argument("--iocs", nargs="*", help="Manual IOCs as type:value pairs, e.g. domain:evil.com ip:1.2.3.4")
    parser.add_argument("--append", action="store_true", help="Append to rules file instead of overwriting")
    parser.add_argument("--api-key", default=os.environ.get("ANTHROPIC_API_KEY"), help="Anthropic API key")
    args = parser.parse_args()

    if not args.api_key:
        print("[ERROR] Set ANTHROPIC_API_KEY environment variable or pass --api-key", file=sys.stderr)
        sys.exit(1)

    client = anthropic.Anthropic(api_key=args.api_key)

    print()
    print("=" * 60)
    print("  PROJECT RADIANT — AI Rule Generation")
    print("=" * 60)

    # Collect IOCs
    iocs: list[dict] = []

    if args.iocs:
        for item in args.iocs:
            if ":" in item:
                ioc_type, ioc_value = item.split(":", 1)
                iocs.append({"type": ioc_type.strip(), "value": ioc_value.strip()})
    else:
        print("  Fetching IOCs from MISP database...")
        iocs = fetch_misp_iocs(args.misp_db)

    # Fallback demo IOCs if nothing found
    if not iocs:
        print("  No IOCs found — using demo IOCs for generation.")
        iocs = [
            {"type": "domain", "value": "malicious-domain.com"},
            {"type": "ip-dst",  "value": "10.0.0.99"},
            {"type": "url",     "value": "http://badsite.io/payload"},
        ]

    print(f"  IOCs loaded: {len(iocs)}")
    for ioc in iocs:
        print(f"    [{ioc['type']}] {ioc['value']}")

    print("\n  Generating rules with Claude AI...")
    rules_text = generate_rules(client, iocs)

    mode = "a" if args.append else "w"
    os.makedirs(os.path.dirname(args.rules_file), exist_ok=True)
    with open(args.rules_file, mode) as f:
        f.write("\n# === AI-Generated rules — Project RADIANT ===\n")
        f.write(rules_text)
        f.write("\n")

    action = "Appended to" if args.append else "Written to"
    print(f"\n  {action}: {args.rules_file}")
    print()
    print("--- Generated Rules ---")
    print(rules_text)
    print()
    print("=" * 60)
    print("  Rule generation complete.")
    print("  Restart Suricata: sudo bash scripts/start.sh")
    print("=" * 60)


if __name__ == "__main__":
    main()
