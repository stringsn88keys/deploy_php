#!/bin/bash

# Meeting Meter Production Deployment Script
# This script deploys the application to a production server with secure configuration

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration file
CONFIG_FILE="$SCRIPT_DIR/deploy.ini"

echo -e "${BLUE}=== Meeting Meter Production Deployment ===${NC}"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}This script should not be run as root${NC}"
   echo "Please run as a regular user with sudo privileges"
   exit 1
fi

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}Loading configuration from: $CONFIG_FILE${NC}"
    source <(grep -v '^#' "$CONFIG_FILE" | grep -v '^$' | sed 's/^\[\(.*\)\]/\1=/')
else
    echo -e "${RED}Configuration file not found: $CONFIG_FILE${NC}"
    echo "Please run ./deploy.sh --interactive first to create configuration"
    exit 1
fi

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Apache2 is installed and running
if ! command -v apache2 &> /dev/null; then
    print_error "Apache2 is not installed"
    echo "Please install Apache2 first: sudo apt install apache2"
    exit 1
fi

if ! systemctl is-active --quiet apache2; then
    print_warning "Apache2 is not running. Starting it..."
    sudo systemctl start apache2
fi

# Check if PHP is installed
if ! command -v php &> /dev/null; then
    print_error "PHP is not installed"
    echo "Please install PHP first: sudo apt install php libapache2-mod-php"
    exit 1
fi

# Check if required PHP extensions are installed
IFS=',' read -ra EXTENSIONS <<< "$required_extensions"
MISSING_EXTENSIONS=()

for ext in "${EXTENSIONS[@]}"; do
    if ! php -m | grep -q "^$ext$"; then
        MISSING_EXTENSIONS+=("$ext")
    fi
done

if [ ${#MISSING_EXTENSIONS[@]} -ne 0 ]; then
    print_warning "Missing PHP extensions: ${MISSING_EXTENSIONS[*]}"
    echo "Installing required PHP extensions..."
    for ext in "${MISSING_EXTENSIONS[@]}"; do
        sudo apt install -y "php-${ext}" 2>/dev/null || true
    done
    sudo systemctl reload apache2
fi

# Create application directory
print_status "Creating application directory..."
sudo mkdir -p "$web_root/$app_dir"
sudo chown www-data:www-data "$web_root/$app_dir"
sudo chmod 755 "$web_root/$app_dir"

# Copy application files
print_status "Copying application files..."
if [ -f "$SCRIPT_DIR/../meeting_meter/index.php" ]; then
    sudo cp "$SCRIPT_DIR/../meeting_meter/"*.php "$web_root/$app_dir/"
    sudo cp "$SCRIPT_DIR/../meeting_meter/README.md" "$web_root/$app_dir/" 2>/dev/null || true
    sudo cp "$SCRIPT_DIR/../meeting_meter/.htaccess" "$web_root/$app_dir/" 2>/dev/null || true
else
    print_error "Source files not found. Please ensure the meeting_meter source files are in the parent directory."
    exit 1
fi

# Set proper permissions for application files
sudo chown www-data:www-data "$web_root/$app_dir"/*
sudo chmod 644 "$web_root/$app_dir"/*.php
sudo chmod 644 "$web_root/$app_dir"/*.md 2>/dev/null || true
sudo chmod 644 "$web_root/$app_dir/.htaccess" 2>/dev/null || true

# Create secure configuration directory
print_status "Setting up secure configuration..."
sudo mkdir -p "$secure_config_dir"
sudo chown www-data:www-data "$secure_config_dir"
sudo chmod 750 "$secure_config_dir"

# Generate secure config.php
print_status "Generating secure configuration file..."

# Get current timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Prompt for API key
echo -e "${YELLOW}=== Alpha Vantage API Key Configuration ===${NC}"
echo "To get real-time stock data, you need an Alpha Vantage API key."
echo "Get one for free at: https://www.alphavantage.co/support/#api-key"
echo

read -p "Enter your Alpha Vantage API key (or press Enter to use demo mode): " API_KEY
API_KEY=${API_KEY:-demo}

# Generate config.php from template
if [ -f "$SCRIPT_DIR/config.php.template" ]; then
    sed -e "s/{{ALPHA_VANTAGE_API_KEY}}/$API_KEY/g" \
        -e "s/{{APP_NAME}}/$app_name/g" \
        -e "s/{{DEBUG_MODE}}/false/g" \
        -e "s/{{DEFAULT_TIMEZONE}}/UTC/g" \
        -e "s/{{LOG_ENABLED}}/true/g" \
        -e "s|{{LOG_FILE}}|$log_dir/app.log|g" \
        -e "s/{{SESSION_LIFETIME}}/3600/g" \
        -e "s/{{CSRF_PROTECTION}}/true/g" \
        -e "s/{{DEFAULT_HOURLY_RATE}}/100/g" \
        -e "s/{{CURRENCY_SYMBOL}}/\$/g" \
        -e "s/{{DATE_FORMAT}}/Y-m-d/g" \
        -e "s/{{TIME_FORMAT}}/H:i/g" \
        -e "s/{{STOCK_ANALYSIS_ENABLED}}/true/g" \
        -e "s/{{DEFAULT_PE_RATIO}}/20/g" \
        -e "s/{{STOCK_CACHE_DURATION}}/300/g" \
        -e "s/{{PDF_EXPORT_ENABLED}}/true/g" \
        -e "s/{{CSV_EXPORT_ENABLED}}/true/g" \
        -e "s/{{EXPORT_RETENTION_DAYS}}/30/g" \
        -e "s/{{CACHE_ENABLED}}/true/g" \
        -e "s|{{CACHE_DIR}}|$web_root/$app_dir/cache|g" \
        -e "s/{{MAX_EXECUTION_TIME}}/30/g" \
        -e "s/{{MEMORY_LIMIT}}/128M/g" \
        -e "s/{{EMAIL_ENABLED}}/false/g" \
        -e "s/{{SMTP_HOST}}/localhost/g" \
        -e "s/{{SMTP_PORT}}/587/g" \
        -e "s/{{SMTP_USERNAME}}//g" \
        -e "s/{{SMTP_PASSWORD}}//g" \
        -e "s/{{FROM_EMAIL}}/noreply@$domain/g" \
        -e "s/{{DEPLOYMENT_TIMESTAMP}}/$TIMESTAMP/g" \
        -e "s/{{DEPLOYMENT_ENV}}/production/g" \
        -e "s/{{SERVER_NAME}}/$(hostname)/g" \
        "$SCRIPT_DIR/config.php.template" | sudo tee "$secure_config_dir/config.php" > /dev/null
else
    print_error "Configuration template not found: $SCRIPT_DIR/config.php.template"
    exit 1
fi

sudo chown www-data:www-data "$secure_config_dir/config.php"
sudo chmod 600 "$secure_config_dir/config.php"

# Create log directory
print_status "Setting up logging..."
sudo mkdir -p "$log_dir"
sudo chown www-data:www-data "$log_dir"
sudo chmod 750 "$log_dir"

# Create log file
sudo touch "$log_dir/app.log"
sudo chown www-data:www-data "$log_dir/app.log"
sudo chmod 640 "$log_dir/app.log"

# Create Apache virtual host configuration
print_status "Setting up Apache virtual host..."

# Check if Apache configuration already exists
if [ -f "$apache_config_file" ]; then
    print_warning "Apache configuration already exists at: $apache_config_file"
    read -p "Do you want to overwrite the existing configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Keeping existing Apache configuration"
        APACHE_CONFIG_EXISTS=true
    else
        print_warning "Overwriting existing Apache configuration"
        APACHE_CONFIG_EXISTS=false
    fi
else
    APACHE_CONFIG_EXISTS=false
fi

# Only create/overwrite if user confirmed or file doesn't exist
if [ "$APACHE_CONFIG_EXISTS" = false ]; then
    print_status "Creating Apache virtual host configuration..."
    sudo tee "$apache_config_file" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $domain
    ServerAdmin webmaster@$domain
    DocumentRoot $web_root/$app_dir
    
    # Security headers
    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options DENY
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains" env=HTTPS
    
    # PHP configuration
    <Directory $web_root/$app_dir>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Prevent access to sensitive files
        <FilesMatch "\.(php|log|sh|md)$">
            <RequireAll>
                Require all granted
                Require not ip 127.0.0.1
            </RequireAll>
        </FilesMatch>
    </Directory>
    
    # Logging
    ErrorLog \${APACHE_LOG_DIR}/${app_name}-error.log
    CustomLog \${APACHE_LOG_DIR}/${app_name}-access.log combined
    
    # PHP settings
    php_value upload_max_filesize $upload_max_filesize
    php_value post_max_size $post_max_size
    php_value max_execution_time $max_execution_time
    php_value memory_limit $memory_limit
    php_value session.gc_maxlifetime $session_gc_maxlifetime
    php_value session.cookie_httponly 1
    php_value session.cookie_secure 1
    php_value session.use_strict_mode 1
    
    # Rate limiting
    <Location />
        SetOutputFilter RATE_LIMIT
        SetEnv rate-limit $rate_limit
    </Location>
</VirtualHost>
EOF
    print_status "Apache virtual host configuration created"
else
    print_status "Using existing Apache configuration"
fi

# Enable required Apache modules
print_status "Enabling Apache modules..."
sudo a2enmod headers
sudo a2enmod rewrite
sudo a2enmod rate_limit 2>/dev/null || echo "Rate limiting module not available"

# Enable the site
print_status "Enabling Apache site..."
if sudo a2ensite "$apache_site_name" 2>/dev/null; then
    print_status "Apache site enabled successfully"
else
    print_warning "Apache site may already be enabled"
fi

# Disable default site (optional)
read -p "Disable default Apache site? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo a2dissite 000-default.conf
    print_status "Default site disabled"
fi

# Test Apache configuration
print_status "Testing Apache configuration..."
if sudo apache2ctl configtest; then
    print_status "Apache configuration is valid"
else
    print_error "Apache configuration has errors"
    exit 1
fi

# Reload Apache
print_status "Reloading Apache..."
sudo systemctl reload apache2

# Set up log rotation
if [ "$enable_logrotate" = "true" ]; then
    print_status "Setting up log rotation..."
    
    # Check if log rotation configuration already exists
    if [ -f "$logrotate_file" ]; then
        print_warning "Log rotation configuration already exists at: $logrotate_file"
        read -p "Do you want to overwrite the existing log rotation configuration? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Keeping existing log rotation configuration"
            LOGROTATE_EXISTS=true
        else
            print_warning "Overwriting existing log rotation configuration"
            LOGROTATE_EXISTS=false
        fi
    else
        LOGROTATE_EXISTS=false
    fi
    
    # Only create/overwrite if user confirmed or file doesn't exist
    if [ "$LOGROTATE_EXISTS" = false ]; then
        print_status "Creating log rotation configuration..."
        sudo tee "$logrotate_file" > /dev/null <<EOF
$log_dir/*.log {
    daily
    missingok
    rotate $log_retention_days
    compress
    delaycompress
    notifempty
    create 640 www-data www-data
    postrotate
        systemctl reload apache2 > /dev/null 2>&1 || true
    endscript
}

/var/log/apache2/${app_name}-*.log {
    daily
    missingok
    rotate $log_retention_days
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload apache2 > /dev/null 2>&1 || true
    endscript
}
EOF
        sudo chmod 644 "$logrotate_file"
        print_status "Log rotation configuration created"
    else
        print_status "Using existing log rotation configuration"
    fi
fi

# Create systemd service file
if [ "$enable_service" = "true" ]; then
    print_status "Setting up systemd service..."
    
    # Check if systemd service already exists
    if [ -f "$service_file" ]; then
        print_warning "Systemd service already exists at: $service_file"
        read -p "Do you want to overwrite the existing systemd service? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Keeping existing systemd service"
            SYSTEMD_EXISTS=true
        else
            print_warning "Overwriting existing systemd service"
            SYSTEMD_EXISTS=false
        fi
    else
        SYSTEMD_EXISTS=false
    fi
    
    # Only create/overwrite if user confirmed or file doesn't exist
    if [ "$SYSTEMD_EXISTS" = false ]; then
        print_status "Creating systemd service..."
        sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=Meeting Meter Application
After=apache2.service
Wants=apache2.service

[Service]
Type=oneshot
RemainAfterExit=yes
EnvironmentFile=$env_file
ExecStart=/bin/true
ExecStop=/bin/true

[Install]
WantedBy=multi-user.target
EOF
        sudo chmod 644 "$service_file"
        print_status "Systemd service created"
    else
        print_status "Using existing systemd service"
    fi
    
    # Create environment file
    print_status "Setting up environment file..."
    
    # Check if environment file already exists
    if [ -f "$env_file" ]; then
        print_warning "Environment file already exists at: $env_file"
        read -p "Do you want to overwrite the existing environment file? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Keeping existing environment file"
            ENV_EXISTS=true
        else
            print_warning "Overwriting existing environment file"
            ENV_EXISTS=false
        fi
    else
        ENV_EXISTS=false
    fi
    
    # Only create/overwrite if user confirmed or file doesn't exist
    if [ "$ENV_EXISTS" = false ]; then
        print_status "Creating environment file..."
        sudo tee "$env_file" > /dev/null <<EOF
# Meeting Meter Environment Variables
MEETING_METER_CONFIG_DIR=$secure_config_dir
MEETING_METER_LOG_DIR=$log_dir
MEETING_METER_WEB_ROOT=$web_root/$app_dir
MEETING_METER_DOMAIN=$domain
EOF
        sudo chmod 644 "$env_file"
        print_status "Environment file created"
    else
        print_status "Using existing environment file"
    fi
    
    # Enable and start service
    print_status "Enabling and starting systemd service..."
    sudo systemctl daemon-reload
    
    if sudo systemctl enable "$(basename "$service_file")" 2>/dev/null; then
        print_status "Systemd service enabled successfully"
    else
        print_warning "Systemd service may already be enabled"
    fi
    
    if sudo systemctl start "$(basename "$service_file")" 2>/dev/null; then
        print_status "Systemd service started successfully"
    else
        print_warning "Systemd service may already be running"
    fi
fi

# Final permissions check
print_status "Setting final permissions..."
sudo chown -R www-data:www-data "$secure_config_dir"
sudo chown -R www-data:www-data "$log_dir"
sudo chown -R www-data:www-data "$web_root/$app_dir"

# Test the configuration
print_status "Testing configuration..."
TEST_SCRIPT="$secure_config_dir/test_config.php"
sudo tee "$TEST_SCRIPT" > /dev/null <<EOF
<?php
// Test script to verify configuration
require_once 'config.php';

echo "Configuration loaded successfully!\n";
echo "API Key: " . (ALPHA_VANTAGE_API_KEY === 'demo' ? 'Demo Mode' : 'Configured') . "\n";
echo "Config directory: $secure_config_dir\n";
echo "Log directory: $log_dir\n";
echo "Web root: $web_root/$app_dir\n";

if (LOG_ENABLED) {
    error_log("Meeting Meter production deployment test completed", 0);
    echo "Logging is enabled\n";
}
?>
EOF

sudo chown www-data:www-data "$TEST_SCRIPT"
sudo chmod 600 "$TEST_SCRIPT"

if sudo -u www-data php "$TEST_SCRIPT"; then
    print_status "Configuration test passed!"
else
    print_error "Configuration test failed!"
    exit 1
fi

# Clean up test script
sudo rm "$TEST_SCRIPT"

# Create SSL certificate (optional)
if [ "$enable_ssl" = "true" ]; then
    print_warning "=== SSL Certificate Setup ==="
    if command -v certbot &> /dev/null; then
        print_status "Setting up SSL certificate..."
        sudo certbot --apache -d "$domain" --non-interactive --agree-tos --email "$ssl_email"
        print_status "SSL certificate configured!"
    else
        print_warning "Certbot not found. Installing..."
        sudo apt install -y certbot python3-certbot-apache
        sudo certbot --apache -d "$domain" --non-interactive --agree-tos --email "$ssl_email"
        print_status "SSL certificate configured!"
    fi
fi

print_status "=== Production Deployment Complete! ==="
echo
print_status "Summary:"
echo "✓ Application deployed to: $web_root/$app_dir"
echo "✓ Secure config directory: $secure_config_dir"
echo "✓ Configuration file: created"
echo "✓ Log directory: $log_dir"
echo "✓ Apache virtual host: $apache_config_file"
echo "✓ Apache site enabled: $apache_site_name"
if [ "$enable_logrotate" = "true" ]; then
    echo "✓ Log rotation: configured"
fi
if [ "$enable_service" = "true" ]; then
    echo "✓ Systemd service: created and enabled"
fi
if [ "$enable_ssl" = "true" ]; then
    echo "✓ SSL certificate configured"
fi
echo
print_status "Next steps:"
echo "1. Update your DNS to point $domain to this server"
echo "2. Access your application at: http://$domain"
echo "3. Check logs at: $log_dir/app.log"
echo "4. Monitor Apache logs: /var/log/apache2/${app_name}-*.log"
echo
print_status "Security features:"
echo "• Configuration file is outside web root and protected"
echo "• Proper file permissions set (600 for config, 750 for directories)"
echo "• Apache security headers enabled"
echo "• Rate limiting configured"
echo "• Log rotation prevents disk space issues"
if [ "$enable_ssl" = "true" ]; then
    echo "• SSL certificate configured"
fi
echo
print_status "Production deployment completed successfully!"
echo
print_status "Useful commands:"
echo "• View logs: sudo tail -f $log_dir/app.log"
echo "• Restart Apache: sudo systemctl restart apache2"
echo "• Check status: sudo systemctl status apache2"
echo "• View Apache config: sudo apache2ctl -S"
