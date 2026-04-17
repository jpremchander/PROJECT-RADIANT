#!/usr/bin/env bash
# Install MISP natively on Ubuntu and configure for Project RADIANT

set -euo pipefail

# ── Project credentials ───────────────────────────────────────────────────────
MISP_BASEURL="https://192.168.50.100"
MISP_ORG="RADIANT"
MISP_ADMIN_EMAIL="admin@radiant.local"
MISP_ADMIN_PASS="Rad14nt@2024"

# ── Pre-flight ────────────────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: run as root — sudo bash scripts/install-misp.sh" >&2
    exit 1
fi

echo "==> Downloading MISP installer..."
wget -qO /tmp/INSTALL.sh \
    https://raw.githubusercontent.com/MISP/MISP/main/INSTALL/INSTALL.sh
chmod +x /tmp/INSTALL.sh

echo "==> Running MISP installer (~20 minutes)..."
MISP_BASEURL="$MISP_BASEURL" bash /tmp/INSTALL.sh -A

# ── Post-install: apply Project RADIANT settings ──────────────────────────────
CAKE="/var/www/MISP/app/Console/cake"
echo "==> Applying Project RADIANT configuration..."

sudo -u www-data "$CAKE" Admin setSetting "MISP.baseurl" "$MISP_BASEURL"
sudo -u www-data "$CAKE" Admin setSetting "MISP.org"     "$MISP_ORG"
sudo -u www-data "$CAKE" Admin setSetting "MISP.email"   "$MISP_ADMIN_EMAIL"

# Set admin password and email directly in DB to avoid change_pw prompt
mysql -u root misp -e "
    UPDATE users
    SET email='$MISP_ADMIN_EMAIL', change_pw=0
    WHERE id=1;
"
sudo -u www-data "$CAKE" User changePw "$MISP_ADMIN_EMAIL" "$MISP_ADMIN_PASS"

echo ""
echo "======================================================"
echo "  MISP — Project RADIANT"
echo "======================================================"
echo "  URL      : $MISP_BASEURL"
echo "  Email    : $MISP_ADMIN_EMAIL"
echo "  Password : $MISP_ADMIN_PASS"
echo "  Org      : $MISP_ORG"
echo "======================================================"
