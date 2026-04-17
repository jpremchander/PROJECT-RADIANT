#!/usr/bin/env bash
# Full MISP native install for Ubuntu 24.04 — Project RADIANT

set -euo pipefail

# ── Project credentials ───────────────────────────────────────────────────────
MISP_BASEURL="https://192.168.50.100"
MISP_ORG="RADIANT"
MISP_ADMIN_EMAIL="admin@radiant.local"
MISP_ADMIN_PASS="Rad14nt@2024"
MISP_PATH="/var/www/MISP"
MISP_DB="misp"
MISP_DB_USER="misp"
MISP_DB_PASS="misp_rad14nt_2024"

# ── Pre-flight ────────────────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: run as root — sudo bash scripts/install-misp.sh" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# ── Step 1: System packages ───────────────────────────────────────────────────
echo "==> [1/9] Installing packages..."
apt-get update -qq
apt-get install -y \
    apache2 mariadb-server redis-server \
    git curl wget \
    php8.3 php8.3-cli php8.3-common php8.3-mysql \
    php8.3-xml php8.3-mbstring php8.3-curl php8.3-intl \
    php8.3-bcmath php8.3-gd php8.3-zip \
    php-redis libapache2-mod-php8.3 \
    python3 python3-pip python3-venv python3-dev \
    libfuzzy-dev ssdeep openssl

# ── Step 2: MariaDB ───────────────────────────────────────────────────────────
echo "==> [2/9] Configuring MariaDB..."
systemctl start mariadb
systemctl enable mariadb
mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${MISP_DB}\`;
CREATE USER IF NOT EXISTS '${MISP_DB_USER}'@'localhost' IDENTIFIED BY '${MISP_DB_PASS}';
GRANT ALL ON \`${MISP_DB}\`.* TO '${MISP_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

# ── Step 3: Redis ─────────────────────────────────────────────────────────────
echo "==> [3/9] Enabling Redis..."
systemctl start redis-server
systemctl enable redis-server

# ── Step 4: Clone MISP ───────────────────────────────────────────────────────
echo "==> [4/9] Cloning MISP (this may take a few minutes)..."
git clone -b 2.4 --depth 1 https://github.com/MISP/MISP.git "$MISP_PATH"
cd "$MISP_PATH"
git submodule update --init --recursive

# ── Step 5: PHP Composer dependencies ────────────────────────────────────────
echo "==> [5/9] Installing PHP dependencies..."
cd "$MISP_PATH/app"
wget -qO composer.phar https://getcomposer.org/download/latest-stable/composer.phar
php composer.phar install --no-dev --no-interaction 2>/dev/null || true

# ── Step 6: Python dependencies ──────────────────────────────────────────────
echo "==> [6/9] Installing Python dependencies..."
python3 -m venv "$MISP_PATH/venv"
"$MISP_PATH/venv/bin/pip" install -q PyMISP pyzmq redis 2>/dev/null || true

# ── Step 7: MISP configuration ───────────────────────────────────────────────
echo "==> [7/9] Writing MISP config..."
cd "$MISP_PATH/app/Config"

SALT=$(openssl rand -hex 32)
UUID=$(cat /proc/sys/kernel/random/uuid)
CIPHER=$(openssl rand -hex 16)

cat > "$MISP_PATH/app/Config/database.php" <<PHP
<?php
class DATABASE_CONFIG {
    public \$default = array(
        'datasource' => 'Database/Mysql',
        'persistent' => false,
        'host'       => 'localhost',
        'login'      => '${MISP_DB_USER}',
        'password'   => '${MISP_DB_PASS}',
        'database'   => '${MISP_DB}',
        'prefix'     => '',
        'encoding'   => 'utf8mb4',
    );
}
PHP

cat > "$MISP_PATH/app/Config/bootstrap.php" <<'PHP'
<?php
require_once dirname(__FILE__) . DS . 'bootstrap.default.php';
PHP

cat > "$MISP_PATH/app/Config/core.php" <<'PHP'
<?php
require_once dirname(__FILE__) . DS . 'core.default.php';
PHP

cat > "$MISP_PATH/app/Config/config.php" <<PHP
<?php
class CONFIG {
    public \$debug = 0;
    public \$site_admin_debug = 0;
    public \$Security = [
        'level'      => 'medium',
        'salt'       => '${SALT}',
        'cipherSeed' => '${CIPHER}',
    ];
    public \$MISP = [
        'baseurl'     => '${MISP_BASEURL}',
        'uuid'        => '${UUID}',
        'org'         => '${MISP_ORG}',
        'host_org_id' => 1,
        'email'       => '${MISP_ADMIN_EMAIL}',
        'live'        => 1,
    ];
    public \$GnuPG = ['onlyencrypted' => false, 'bodyonlyencrypted' => false];
    public \$Proxy = ['host' => null, 'port' => null, 'method' => null,
                      'user' => null, 'password' => null];
}
PHP

# ── Step 8: Permissions + Apache + SSL ───────────────────────────────────────
echo "==> [8/9] Apache, SSL and permissions..."

mkdir -p "$MISP_PATH/app/tmp/logs" "$MISP_PATH/app/files/scripts/tmp"
chown -R www-data:www-data "$MISP_PATH"
find "$MISP_PATH" -type d -exec chmod 750 {} \;
chmod -R 770 "$MISP_PATH/app/tmp" "$MISP_PATH/app/files"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/misp.key \
    -out /etc/ssl/certs/misp.crt \
    -subj "/CN=192.168.50.100/O=RADIANT/C=US" 2>/dev/null

cat > /etc/apache2/sites-available/misp.conf <<'CONF'
<VirtualHost *:80>
    ServerName 192.168.50.100
    Redirect permanent / https://192.168.50.100/
</VirtualHost>

<VirtualHost *:443>
    ServerName 192.168.50.100
    DocumentRoot /var/www/MISP/app/webroot

    SSLEngine on
    SSLCertificateFile    /etc/ssl/certs/misp.crt
    SSLCertificateKeyFile /etc/ssl/private/misp.key

    <Directory /var/www/MISP/app/webroot>
        Options -Indexes
        AllowOverride all
        Require all granted
    </Directory>

    ErrorLog  /var/log/apache2/misp_error.log
    CustomLog /var/log/apache2/misp_access.log combined
</VirtualHost>
CONF

a2dissite 000-default 2>/dev/null || true
a2ensite misp
a2enmod ssl rewrite headers
systemctl restart apache2

# ── Step 9: Bootstrap DB and set credentials ──────────────────────────────────
echo "==> [9/9] Initialising database..."

mysql -u "$MISP_DB_USER" -p"$MISP_DB_PASS" "$MISP_DB" \
    < "$MISP_PATH/INSTALL/MYSQL.sql"

CAKE="$MISP_PATH/app/Console/cake"

sudo -u www-data "$CAKE" Admin runUpdates
sudo -u www-data "$CAKE" Admin setSetting "MISP.baseurl" "$MISP_BASEURL"
sudo -u www-data "$CAKE" Admin setSetting "MISP.org"     "$MISP_ORG"
sudo -u www-data "$CAKE" Admin setSetting "MISP.live"    1

mysql -u root "$MISP_DB" \
    -e "UPDATE users SET email='${MISP_ADMIN_EMAIL}', change_pw=0 WHERE id=1;"
sudo -u www-data "$CAKE" User changePw "$MISP_ADMIN_EMAIL" "$MISP_ADMIN_PASS"

echo ""
echo "======================================================"
echo "  MISP ready — Project RADIANT"
echo "======================================================"
echo "  URL      : ${MISP_BASEURL}"
echo "  Email    : ${MISP_ADMIN_EMAIL}"
echo "  Password : ${MISP_ADMIN_PASS}"
echo "  Org      : ${MISP_ORG}"
echo "======================================================"
