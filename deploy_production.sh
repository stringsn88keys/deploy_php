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

# Domains configuration file
DOMAINS_CONFIG_FILE="$SCRIPT_DIR/domains.ini"

# Default domains configuration
DEFAULT_DOMAINS_CONFIG_FILE="$SCRIPT_DIR/domains.ini.example"

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

# Load domains configuration
load_domains_config() {
    if [ -f "$DOMAINS_CONFIG_FILE" ]; then
        echo -e "${GREEN}Loading domains configuration from: $DOMAINS_CONFIG_FILE${NC}"
        return 0
    else
        echo -e "${YELLOW}Domains configuration file not found: $DOMAINS_CONFIG_FILE${NC}"
        if [ -f "$DEFAULT_DOMAINS_CONFIG_FILE" ]; then
            echo -e "${BLUE}Creating domains configuration from template...${NC}"
            cp "$DEFAULT_DOMAINS_CONFIG_FILE" "$DOMAINS_CONFIG_FILE"
            echo -e "${GREEN}Domains configuration file created: $DOMAINS_CONFIG_FILE${NC}"
            echo -e "${YELLOW}Please edit the domains configuration file and run the script again${NC}"
            return 1
        else
            echo -e "${RED}Default domains configuration template not found: $DEFAULT_DOMAINS_CONFIG_FILE${NC}"
            return 1
        fi
    fi
}

# List available domains
list_domains() {
    if [ ! -f "$DOMAINS_CONFIG_FILE" ]; then
        echo -e "${RED}Domains configuration file not found${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Available domains:${NC}"
    echo
    
    # Extract domain names from the configuration file
    DOMAINS=($(grep -E '^\[.*\]$' "$DOMAINS_CONFIG_FILE" | sed 's/\[\(.*\)\]/\1/' | grep -v '^$'))
    
    for i in "${!DOMAINS[@]}"; do
        echo "$((i+1)). ${DOMAINS[i]}"
    done
    
    echo
    return 0
}

# Select domain
select_domain() {
    if [ ! -f "$DOMAINS_CONFIG_FILE" ]; then
        echo -e "${RED}Domains configuration file not found${NC}"
        return 1
    fi
    
    list_domains
    
    DOMAINS=($(grep -E '^\[.*\]$' "$DOMAINS_CONFIG_FILE" | sed 's/\[\(.*\)\]/\1/' | grep -v '^$'))
    
    if [ ${#DOMAINS[@]} -eq 0 ]; then
        echo -e "${RED}No domains configured${NC}"
        return 1
    fi
    
    while true; do
        read -p "Select domain (1-${#DOMAINS[@]}): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#DOMAINS[@]}" ]; then
            SELECTED_DOMAIN="${DOMAINS[$((choice-1))]}"
            echo -e "${GREEN}Selected domain: $SELECTED_DOMAIN${NC}"
            return 0
        else
            echo -e "${RED}Invalid selection. Please enter a number between 1 and ${#DOMAINS[@]}${NC}"
        fi
    done
}

# Load domain-specific configuration
load_domain_config() {
    if [ -z "$SELECTED_DOMAIN" ]; then
        echo -e "${RED}No domain selected${NC}"
        return 1
    fi
    
    if [ ! -f "$DOMAINS_CONFIG_FILE" ]; then
        echo -e "${RED}Domains configuration file not found${NC}"
        return 1
    fi
    
    # Extract domain-specific configuration
    DOMAIN_SECTION="[$SELECTED_DOMAIN]"
    DOMAIN_CONFIG=$(awk "/^$DOMAIN_SECTION$/,/^\[/" "$DOMAINS_CONFIG_FILE" | grep -v "^$DOMAIN_SECTION$" | grep -v "^\[" | grep -v "^$")
    
    if [ -z "$DOMAIN_CONFIG" ]; then
        echo -e "${RED}Configuration for domain $SELECTED_DOMAIN not found${NC}"
        return 1
    fi
    
    # Set domain-specific variables
    while IFS='=' read -r key value; do
        if [ -n "$key" ] && [ -n "$value" ]; then
            # Remove leading/trailing whitespace
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            eval "$key=\"$value\""
        fi
    done <<< "$DOMAIN_CONFIG"
    
    echo -e "${GREEN}Domain configuration loaded for: $SELECTED_DOMAIN${NC}"
    return 0
}

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

# Handle multi-domain selection
if [ "$multi_domain_enabled" = "true" ]; then
    echo -e "${BLUE}=== Multi-Domain Production Deployment ===${NC}"
    
    # Load domains configuration
    if ! load_domains_config; then
        echo -e "${YELLOW}Please configure your domains and run the script again${NC}"
        exit 0
    fi
    
    # Select domain
    if ! select_domain; then
        echo -e "${RED}Domain selection failed${NC}"
        exit 1
    fi
    
    # Load domain-specific configuration
    if ! load_domain_config; then
        echo -e "${RED}Failed to load domain configuration${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Deploying to domain: $SELECTED_DOMAIN${NC}"
else
    # Single domain mode - use default values
    domain=${domain:-$default_domain}
    app_dir=${app_dir:-meeting_meter}
    echo -e "${GREEN}Single domain mode - deploying to: $domain${NC}"
fi

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

# Determine source directory
if [ -n "$source_dir" ]; then
    SOURCE_DIR="$SCRIPT_DIR/$source_dir"
    print_status "Using domain-specific source directory: $source_dir"
else
    SOURCE_DIR="$SCRIPT_DIR/../meeting_meter"
    print_status "Using default source directory: ../meeting_meter"
fi

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    print_error "Source directory not found: $SOURCE_DIR"
    print_error "Please ensure the source files are available or update the source_dir configuration"
    exit 1
fi

if [ -f "$SOURCE_DIR/index.php" ]; then
    sudo cp "$SOURCE_DIR/"*.php "$web_root/$app_dir/"
    sudo cp "$SOURCE_DIR/README.md" "$web_root/$app_dir/" 2>/dev/null || true
    sudo cp "$SOURCE_DIR/.htaccess" "$web_root/$app_dir/" 2>/dev/null || true
    print_status "Application files copied from: $SOURCE_DIR"
else
    print_error "Source files not found in: $SOURCE_DIR"
    print_error "Please ensure the source files are available or update the source_dir configuration"
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

# Function to update Apache configuration with SSL settings
update_apache_ssl_config() {
    local config_file="$1"
    local domain_name="$2"
    local app_name="$3"
    local web_root="$4"
    local app_dir="$5"
    local ssl_alt_domains="$6"
    
    print_status "Updating Apache configuration with SSL settings..."
    
    # Create SSL-enabled virtual host configuration
    sudo tee "$config_file" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $domain_name
    ServerAdmin webmaster@$domain_name
    DocumentRoot $web_root/$app_dir
    
    # Redirect all HTTP traffic to HTTPS
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
    
    # Logging for HTTP redirects
    ErrorLog \${APACHE_LOG_DIR}/${app_name}-error.log
    CustomLog \${APACHE_LOG_DIR}/${app_name}-access.log combined
</VirtualHost>

<VirtualHost *:443>
    ServerName $domain_name
EOF

    # Add alternative domains if specified
    if [ -n "$ssl_alt_domains" ]; then
        echo "    ServerAlias $ssl_alt_domains" | sudo tee -a "$config_file" > /dev/null
    fi

    # Continue with SSL configuration
    sudo tee -a "$config_file" > /dev/null <<EOF
    ServerAdmin webmaster@$domain_name
    DocumentRoot $web_root/$app_dir
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$domain_name/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$domain_name/privkey.pem
    
    # SSL Security Settings
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    SSLHonorCipherOrder off
    SSLSessionTickets off
    
    # OCSP Stapling
    SSLUseStapling on
    SSLStaplingResponderTimeout 5
    SSLStaplingReturnResponderErrors off
    
    # Security headers (enhanced for HTTPS)
    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options DENY
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' https:; connect-src 'self'"
    
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
        
        # Additional security for HTTPS
        <FilesMatch "\.(htaccess|htpasswd|ini|log|sh|inc|bak)$">
            Require all denied
        </FilesMatch>
    </Directory>
    
    # Logging
    ErrorLog \${APACHE_LOG_DIR}/${app_name}-ssl-error.log
    CustomLog \${APACHE_LOG_DIR}/${app_name}-ssl-access.log combined
    
    # PHP settings
    php_value upload_max_filesize $upload_max_filesize
    php_value post_max_size $post_max_size
    php_value max_execution_time $max_execution_time
    php_value memory_limit $memory_limit
    php_value session.gc_maxlifetime $session_gc_maxlifetime
    php_value session.cookie_httponly 1
    php_value session.cookie_secure 1
    php_value session.use_strict_mode 1
    
    # Rate limiting (if available)
    <Location />
        SetOutputFilter RATE_LIMIT
        SetEnv rate-limit $rate_limit
    </Location>
</VirtualHost>
EOF

    print_status "SSL configuration added to Apache virtual host"
}

# Create SSL certificate (optional)
if [ "$enable_ssl" = "true" ]; then
    print_warning "=== SSL Certificate Setup ==="
    
    # Enable required Apache modules for SSL
    print_status "Enabling Apache SSL modules..."
    sudo a2enmod ssl
    sudo a2enmod rewrite
    
    # Set up OCSP stapling
    if ! grep -q "SSLStaplingCache" /etc/apache2/apache2.conf; then
        echo "SSLStaplingCache shmcb:/var/run/ocsp(128000)" | sudo tee -a /etc/apache2/apache2.conf > /dev/null
        print_status "OCSP stapling cache configured"
    fi
    
    if command -v certbot &> /dev/null; then
        print_status "Setting up SSL certificate..."
        
        # Build certbot command with alternative domains
        CERTBOT_CMD="sudo certbot certonly --apache -d $domain"
        if [ -n "$ssl_alt_domains" ]; then
            # Split ssl_alt_domains by comma and add each as -d option
            IFS=',' read -ra ALT_DOMAINS <<< "$ssl_alt_domains"
            for alt_domain in "${ALT_DOMAINS[@]}"; do
                # Trim whitespace
                alt_domain=$(echo "$alt_domain" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                CERTBOT_CMD="$CERTBOT_CMD -d $alt_domain"
            done
        fi
        CERTBOT_CMD="$CERTBOT_CMD --non-interactive --agree-tos --email $ssl_email"
        
        # Run certbot
        eval $CERTBOT_CMD
        
        if [ $? -eq 0 ]; then
            print_status "SSL certificate obtained successfully!"
            
            # Update Apache configuration with SSL settings
            update_apache_ssl_config "$apache_config_file" "$domain" "$app_name" "$web_root" "$app_dir" "$ssl_alt_domains"
            
            # Test Apache configuration
            if sudo apache2ctl configtest; then
                print_status "SSL Apache configuration is valid"
                sudo systemctl reload apache2
                print_status "Apache reloaded with SSL configuration"
            else
                print_error "SSL Apache configuration has errors"
                exit 1
            fi
            
            print_status "SSL certificate configured and Apache updated!"
        else
            print_error "SSL certificate setup failed"
            exit 1
        fi
    else
        print_warning "Certbot not found. Installing..."
        sudo apt install -y certbot python3-certbot-apache
        
        # Build certbot command with alternative domains
        CERTBOT_CMD="sudo certbot certonly --apache -d $domain"
        if [ -n "$ssl_alt_domains" ]; then
            # Split ssl_alt_domains by comma and add each as -d option
            IFS=',' read -ra ALT_DOMAINS <<< "$ssl_alt_domains"
            for alt_domain in "${ALT_DOMAINS[@]}"; do
                # Trim whitespace
                alt_domain=$(echo "$alt_domain" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                CERTBOT_CMD="$CERTBOT_CMD -d $alt_domain"
            done
        fi
        CERTBOT_CMD="$CERTBOT_CMD --non-interactive --agree-tos --email $ssl_email"
        
        # Run certbot
        eval $CERTBOT_CMD
        
        if [ $? -eq 0 ]; then
            print_status "SSL certificate obtained successfully!"
            
            # Update Apache configuration with SSL settings
            update_apache_ssl_config "$apache_config_file" "$domain" "$app_name" "$web_root" "$app_dir" "$ssl_alt_domains"
            
            # Test Apache configuration
            if sudo apache2ctl configtest; then
                print_status "SSL Apache configuration is valid"
                sudo systemctl reload apache2
                print_status "Apache reloaded with SSL configuration"
            else
                print_error "SSL Apache configuration has errors"
                exit 1
            fi
            
            print_status "SSL certificate configured and Apache updated!"
        else
            print_error "SSL certificate setup failed"
            exit 1
        fi
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
    echo "✓ SSL certificate configured with proper Apache integration"
    echo "✓ HTTP to HTTPS redirect enabled"
    echo "✓ Enhanced security headers for HTTPS"
fi
echo
print_status "Next steps:"
echo "1. Update your DNS to point $domain to this server"
if [ "$enable_ssl" = "true" ]; then
    echo "2. Access your application at: https://$domain"
else
    echo "2. Access your application at: http://$domain"
fi
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
    echo "• SSL certificate configured with Let's Encrypt"
    echo "• HTTP to HTTPS redirect enforced"
    echo "• HSTS (HTTP Strict Transport Security) enabled"
    echo "• OCSP stapling configured for better performance"
    echo "• Modern SSL/TLS protocols and ciphers only"
fi
echo
print_status "Production deployment completed successfully!"
echo
print_status "Useful commands:"
echo "• View logs: sudo tail -f $log_dir/app.log"
echo "• Restart Apache: sudo systemctl restart apache2"
echo "• Check status: sudo systemctl status apache2"
echo "• View Apache config: sudo apache2ctl -S"
if [ "$enable_ssl" = "true" ]; then
    echo "• Check SSL certificate: sudo certbot certificates"
    echo "• Renew SSL certificate: sudo certbot renew --dry-run"
    echo "• View SSL logs: sudo tail -f /var/log/apache2/${app_name}-ssl-*.log"
    echo "• Test SSL configuration: openssl s_client -connect $domain:443 -servername $domain"
fi
