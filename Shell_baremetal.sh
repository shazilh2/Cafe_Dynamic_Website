#!/bin/bash
set -e

echo "==========================================="
echo "  Starting Cafe Dynamic Deployment (LAMP)  "
echo "==========================================="

############################################
# Variables
############################################
DEST_DIR="/var/www/html/mompopcafe"
SQL_SCRIPT="$WORKSPACE/mompopdb/create-db.sql"

DB_NAME="mom_pop_db"
DB_APP_USER="msis"
DB_APP_PASSWORD="Msois@123"
DB_HOST="localhost"

APP_PARAMS_FILE="$DEST_DIR/getAppParameters.php"

############################################
# 1. Install LAMP stack
############################################
echo "[1] Installing LAMP packages..."
sudo apt-get update -y
sudo apt-get install -y apache2 mysql-server mysql-client php php-mysql libapache2-mod-php

############################################
# 2. Deploy Application Code
############################################
echo "[2] Deploying application files..."

# Ensure destination directory exists
sudo mkdir -p "$DEST_DIR"

# Remove existing files to avoid stale or empty files
sudo rm -rf "$DEST_DIR"/*

# Copy all files including subfolders
echo "Copying files from $WORKSPACE/mompopcafe → $DEST_DIR"
sudo cp -a "$WORKSPACE/mompopcafe/." "$DEST_DIR/"

# Verify no empty PHP files
EMPTY_PHP=$(find "$DEST_DIR" -type f -name "*.php" -size 0)
if [ -n "$EMPTY_PHP" ]; then
    echo "Error: The following PHP files are empty:"
    echo "$EMPTY_PHP"
    exit 1
fi

# Set correct permissions
sudo chown -R www-data:www-data "$DEST_DIR"
sudo find "$DEST_DIR" -type d -exec chmod 755 {} \;
sudo find "$DEST_DIR" -type f -exec chmod 644 {} \;

echo "Files successfully deployed."

############################################
# 3. Update Apache DocumentRoot
############################################
echo "[3] Updating Apache DocumentRoot..."
sudo sed -E -i \
's|DocumentRoot[[:space:]]+/var/www/html[^[:space:]]*|DocumentRoot /var/www/html/mompopcafe|' \
/etc/apache2/sites-available/000-default.conf

sudo systemctl restart apache2
echo "Apache updated and restarted."

############################################
# 4. MySQL Root-Level Setup
############################################
echo "[4] Creating MySQL DB, user, granting privileges..."
sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;

CREATE USER IF NOT EXISTS '$DB_APP_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_APP_PASSWORD';

GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_APP_USER'@'localhost';

FLUSH PRIVILEGES;
EOF

echo "Database and user configured successfully."

############################################
# 5. Import SQL using App User
############################################
echo "[5] Importing SQL data..."
mysql -u"$DB_APP_USER" -p"$DB_APP_PASSWORD" "$DB_NAME" < "$SQL_SCRIPT"
echo "Database import completed."

############################################
# 6. Create getAppParameters.php dynamically
############################################
echo "[6] Creating getAppParameters.php..."
sudo tee "$APP_PARAMS_FILE" > /dev/null <<EOL
<?php
// Application parameters for DB
\$db_url = "$DB_HOST";
\$db_user = "$DB_APP_USER";
\$db_password = "$DB_APP_PASSWORD";
\$db_name = "$DB_NAME";

// Currency symbol
\$currency = "₹";

// Whether to show server metadata or not
\$showServerInfo = false;
?>
EOL

sudo chmod 644 "$APP_PARAMS_FILE"
sudo chown www-data:www-data "$APP_PARAMS_FILE"
echo "getAppParameters.php created successfully."

############################################
# 7. Restart Apache
############################################
sudo systemctl restart apache2
echo "Apache restarted."

############################################
# 8. Output app URL
############################################
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "Cafe app is accessible at: http://$IP_ADDRESS/mompopcafe"
