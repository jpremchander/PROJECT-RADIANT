# MISP Stack

This folder is reserved for the official MISP Docker stack. The root repository now runs Suricata only, which keeps LAN-capture validation clean and avoids mixing the MISP backend services into the same compose file. Use this folder to stage the upstream MISP Docker files and your MISP-specific environment values, and keep the separate stack centered on `misp-core`, `db`, and `redis`. Do not wire MISP back into the root compose unless you intentionally want to make the lab stack heavier again.
