#!/usr/bin/env bash
# Full MISP native install for Ubuntu 24.04 — Project RADIANT

set -euo pipefail

# ── Credentials ───────────────────────────────────────────────────────────────
MISP_BASEURL="http://192.168.50.100"
MISP_ORG="RADIANT"
MISP_ADMIN_EMAIL="admin@radiant.local"
MISP_ADMIN_PASS="Rad14nt@2024"
MISP_PATH="/var/www/MISP"
MISP_DB="misp"
MISP_DB_USER="misp"
MISP_DB_PASS="misp_rad14nt_2024"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: run as root — sudo bash scripts/install-misp.sh" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# ── 1. Packages ───────────────────────────────────────────────────────────────
echo "==> [1/9] Installing packages..."
apt-get update -qq
apt-get install -y software-properties-common

# PHP 8.x has a built-in Attribute class that conflicts with MISP's model.
# PHP 7.4 (via ondrej PPA) is required.
echo "==> Adding ondrej PHP PPA for PHP 7.4..."
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
apt-get update -qq

apt-get install -y \
    apache2 mariadb-server redis-server \
    git curl wget openssl \
    php7.4 php7.4-cli php7.4-common php7.4-mysql \
    php7.4-xml php7.4-mbstring php7.4-curl php7.4-intl \
    php7.4-bcmath php7.4-gd php7.4-zip php7.4-json \
    php7.4-redis libapache2-mod-php7.4 \
    python3 python3-pip python3-venv python3-dev \
    libfuzzy-dev ssdeep

# Disable PHP 8.x in Apache, enable 7.4
a2dismod php8.3 2>/dev/null || true
a2dismod php8.2 2>/dev/null || true
a2dismod php8.1 2>/dev/null || true
a2enmod php7.4
update-alternatives --set php /usr/bin/php7.4 2>/dev/null || true

# ── 2. MariaDB ────────────────────────────────────────────────────────────────
echo "==> [2/9] Configuring MariaDB..."
systemctl start mariadb
systemctl enable mariadb
mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${MISP_DB}\`;
CREATE USER IF NOT EXISTS '${MISP_DB_USER}'@'localhost' IDENTIFIED BY '${MISP_DB_PASS}';
GRANT ALL ON \`${MISP_DB}\`.* TO '${MISP_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

# ── 3. Redis ──────────────────────────────────────────────────────────────────
echo "==> [3/9] Enabling Redis..."
systemctl start redis-server
systemctl enable redis-server

# ── 4. Clone MISP (skip if already present) ───────────────────────────────────
echo "==> [4/9] Cloning MISP..."
if [ -d "$MISP_PATH/.git" ]; then
    echo "    MISP already cloned — skipping."
else
    rm -rf "$MISP_PATH"
    git clone -b 2.4 --depth 1 https://github.com/MISP/MISP.git "$MISP_PATH"
fi

git config --global --add safe.directory "$MISP_PATH"
cd "$MISP_PATH"
git submodule update --init --recursive

# ── 5. PHP Composer ───────────────────────────────────────────────────────────
echo "==> [5/9] Installing PHP dependencies (composer)..."
cd "$MISP_PATH/app"
if [ ! -f composer.phar ]; then
    wget -qO composer.phar https://getcomposer.org/download/latest-stable/composer.phar
fi
php -d memory_limit=-1 composer.phar install \
    --no-dev --no-interaction --ignore-platform-reqs

# ── 6. Python deps ────────────────────────────────────────────────────────────
echo "==> [6/9] Installing Python dependencies..."
if [ ! -d "$MISP_PATH/venv" ]; then
    python3 -m venv "$MISP_PATH/venv"
fi
"$MISP_PATH/venv/bin/pip" install -q PyMISP pyzmq redis

# ── 7. Write config files ─────────────────────────────────────────────────────
echo "==> [7/9] Writing MISP config files..."

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
\$config = array(
    'debug' => 0,
    'site_admin_debug' => 0,
    'Security' => array(
        'level'      => 'medium',
        'salt'       => '${SALT}',
        'cipherSeed' => '${CIPHER}',
    ),
    'MISP' => array(
        'baseurl'     => '${MISP_BASEURL}',
        'uuid'        => '${UUID}',
        'org'         => '${MISP_ORG}',
        'host_org_id' => 1,
        'email'       => '${MISP_ADMIN_EMAIL}',
        'live'        => 1,
    ),
    'GnuPG' => array(
        'onlyencrypted'     => false,
        'bodyonlyencrypted' => false,
    ),
    'Proxy' => array(
        'host'     => '',
        'port'     => '',
        'method'   => '',
        'user'     => '',
        'password' => '',
    ),
);
PHP

# ── 8. Permissions + Apache + SSL ─────────────────────────────────────────────
echo "==> [8/9] Permissions, Apache and SSL..."

mkdir -p "$MISP_PATH/app/tmp/logs" \
         "$MISP_PATH/app/tmp/cache/models" \
         "$MISP_PATH/app/tmp/cache/persistent" \
         "$MISP_PATH/app/tmp/cache/views" \
         "$MISP_PATH/app/files/scripts/tmp"

chown -R www-data:www-data "$MISP_PATH"
find "$MISP_PATH" -type d -exec chmod 750 {} \;
chmod -R 770 "$MISP_PATH/app/tmp" "$MISP_PATH/app/files"

cat > /etc/apache2/sites-available/misp.conf <<'CONF'
<VirtualHost *:80>
    ServerName 192.168.50.100
    DocumentRoot /var/www/MISP/app/webroot

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
a2enmod rewrite headers
systemctl restart apache2

# ── 9. DB schema + credentials ────────────────────────────────────────────────
echo "==> [9/9] Initialising database and credentials..."

# Import base schema (creates default admin@admin.test user)
mysql -u "$MISP_DB_USER" -p"$MISP_DB_PASS" "$MISP_DB" \
    < "$MISP_PATH/INSTALL/MYSQL.sql" 2>/dev/null || true

# Generate bcrypt password hash via PHP (bypasses cake/PHP8 Attribute conflict)
HASH=$(php -r "echo password_hash('${MISP_ADMIN_PASS}', PASSWORD_DEFAULT);")

# Set admin email, password and disable forced password change
mysql -u root "$MISP_DB" <<SQL
UPDATE users SET email='${MISP_ADMIN_EMAIL}', password='${HASH}', change_pw=0 WHERE id=1;
SQL

echo "    Admin credentials set: ${MISP_ADMIN_EMAIL} / ${MISP_ADMIN_PASS}"

echo ""
echo "======================================================"
echo "  MISP ready — Project RADIANT"
echo "======================================================"
echo "  URL      : ${MISP_BASEURL}"
echo "  Email    : ${MISP_ADMIN_EMAIL}"
echo "  Password : ${MISP_ADMIN_PASS}"
echo "  Org      : ${MISP_ORG}"
echo "======================================================"
