#!/bin/bash

###########################################
# SIMPLE + FIXED DEPLOY SCRIPT
###########################################

# ===== Install Apache, PHP, MySQL =====
sudo apt-get update -y
sudo apt-get install -y apache2 mysql-server php php-mysql libapache2-mod-php

# ===== Variables =====
DEST_DIR="/var/www/html/mompopcafe"
DB_NAME="mom_pop_db"
DB_USER="msis"
DB_PASS="Msois@123"
SQL_FILE="mompopdb/create-db.sql"

###########################################
# Copy Application Files
###########################################
echo "Copying application files..."
sudo rm -rf $DEST_DIR
sudo mkdir -p $DEST_DIR
sudo cp -r mompopcafe/* $DEST_DIR/

###########################################
# Create getAppParameters.php
###########################################
echo "Creating getAppParameters.php..."
cat <<EOF | sudo tee $DEST_DIR/getAppParameters.php > /dev/null
<?php
\$db_url = "localhost";
\$db_user = "$DB_USER";
\$db_password = "$DB_PASS";
\$db_name = "$DB_NAME";
\$currency = "₹";
\$showServerInfo = false;
?>
EOF

###########################################
# FIXED: Update Apache DocumentRoot
###########################################
echo "Updating Apache DocumentRoot..."

# remove any existing mompopcafe* paths first (safe)
sudo sed -i 's|DocumentRoot .*|DocumentRoot /var/www/html/mompopcafe|' /etc/apache2/sites-available/000-default.conf

sudo systemctl restart apache2

###########################################
# MySQL Setup
###########################################
echo "Setting up MySQL..."

sudo mysql <<EOF
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
CREATE DATABASE IF NOT EXISTS $DB_NAME;
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

###########################################
# Import SQL
###########################################
if [ -f "$SQL_FILE" ]; then
    echo "Importing SQL..."
    mysql -u$DB_USER -p$DB_PASS $DB_NAME < $SQL_FILE
else
    echo "SQL file not found: $SQL_FILE"
fi

###########################################
# Final Output
###########################################
IP=$(hostname -I | awk '{print $1}')
echo "---------------------------------------------------"
echo "Deployment Completed!"
echo "Visit your app at:  http://$IP/mompopcafe/"
echo "---------------------------------------------------"
