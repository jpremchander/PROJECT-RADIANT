#!/usr/bin/env bash
# Reset MISP admin credentials — Project RADIANT

set -euo pipefail

MISP_ADMIN_EMAIL="admin@radiant.lab"
MISP_ADMIN_PASS="admin@1234"
MISP_DB="misp"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: run as root — sudo bash scripts/reset-misp-credentials.sh" >&2
    exit 1
fi

echo "==> Resetting MISP credentials..."

HASH=$(php7.4 -r "echo password_hash('${MISP_ADMIN_PASS}', PASSWORD_DEFAULT);")

mysql -u root "${MISP_DB}" <<SQL
UPDATE users SET email='${MISP_ADMIN_EMAIL}', password='${HASH}', change_pw=0 WHERE id=1;
SQL

echo ""
echo "======================================================"
echo "  MISP Credentials Reset — Project RADIANT"
echo "======================================================"
echo "  URL      : http://192.168.50.100"
echo "  Email    : ${MISP_ADMIN_EMAIL}"
echo "  Password : ${MISP_ADMIN_PASS}"
echo "======================================================"
