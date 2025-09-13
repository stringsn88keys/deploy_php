#!/bin/bash

# Meeting Meter PHP Deployment Script
# This script deploys the Meeting Meter application with configurable settings

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

# Default configuration
DEFAULT_CONFIG_FILE="$SCRIPT_DIR/deploy.ini.example"

echo -e "${BLUE}=== Meeting Meter PHP Deployment Script ===${NC}"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}This script should not be run as root${NC}"
   echo "Please run as a regular user with sudo privileges"
   exit 1
fi

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}Loading configuration from: $CONFIG_FILE${NC}"
        source <(grep -v '^#' "$CONFIG_FILE" | grep -v '^$' | sed 's/^\[\(.*\)\]/\1=/')
    else
        echo -e "${YELLOW}Configuration file not found: $CONFIG_FILE${NC}"
        echo -e "${BLUE}Creating configuration from template...${NC}"
        
        if [ -f "$DEFAULT_CONFIG_FILE" ]; then
            cp "$DEFAULT_CONFIG_FILE" "$CONFIG_FILE"
            echo -e "${GREEN}Configuration file created: $CONFIG_FILE${NC}"
            echo -e "${YELLOW}Please edit the configuration file and run the script again${NC}"
            echo -e "${BLUE}Or run: ./deploy.sh --interactive${NC}"
            exit 0
        else
            echo -e "${RED}Default configuration template not found: $DEFAULT_CONFIG_FILE${NC}"
            exit 1
        fi
    fi
}

# Interactive configuration setup
interactive_config() {
    echo -e "${BLUE}=== Interactive Configuration Setup ===${NC}"
    
    # Create config file from template
    cp "$DEFAULT_CONFIG_FILE" "$CONFIG_FILE"
    
    echo -e "${YELLOW}Please provide the following information:${NC}"
    echo
    
    # General settings
    read -p "Application name [meeting_meter]: " app_name
    app_name=${app_name:-meeting_meter}
    
    read -p "Domain name [meetingmeter.example.com]: " domain
    domain=${domain:-meetingmeter.example.com}
    
    read -p "Web root directory [/var/www/html]: " web_root
    web_root=${web_root:-/var/www/html}
    
    read -p "Application directory [meeting_meter]: " app_dir
    app_dir=${app_dir:-meeting_meter}
    
    # Update config file
    sed -i "s/app_name = .*/app_name = $app_name/" "$CONFIG_FILE"
    sed -i "s/domain = .*/domain = $domain/" "$CONFIG_FILE"
    sed -i "s|web_root = .*|web_root = $web_root|" "$CONFIG_FILE"
    sed -i "s/app_dir = .*/app_dir = $app_dir/" "$CONFIG_FILE"
    
    echo -e "${GREEN}Configuration saved to: $CONFIG_FILE${NC}"
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

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if PHP is installed
    if ! command -v php &> /dev/null; then
        print_error "PHP is not installed. Please install PHP 7.4 or higher."
        exit 1
    fi
    
    # Check PHP version
    PHP_VERSION=$(php -r "echo PHP_VERSION;" | cut -d. -f1,2)
    REQUIRED_VERSION="7.4"
    
    if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PHP_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
        print_error "PHP version $PHP_VERSION is too old. Required: $REQUIRED_VERSION or higher."
        exit 1
    fi
    
    print_status "PHP version $PHP_VERSION detected ✓"
    
    # Check if web server directory exists
    if [ ! -d "$web_root" ]; then
        print_warning "Web root directory $web_root does not exist."
        read -p "Create it? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo mkdir -p "$web_root"
            sudo chown $USER:$USER "$web_root"
        else
            print_error "Cannot proceed without web root directory."
            exit 1
        fi
    fi
    
    print_status "Prerequisites check completed ✓"
}

# Generate config.php from template
generate_config() {
    print_status "Generating configuration file..."
    
    # Check if config.php.template exists
    if [ ! -f "$SCRIPT_DIR/config.php.template" ]; then
        print_error "Configuration template not found: $SCRIPT_DIR/config.php.template"
        exit 1
    fi
    
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
        "$SCRIPT_DIR/config.php.template" > "$web_root/$app_dir/config.php"
    
    print_status "Configuration file generated ✓"
}

# Create backup
create_backup() {
    if [ "$enable_backup" = "true" ] && [ -d "$web_root/$app_dir" ]; then
        print_status "Creating backup of existing installation..."
        mkdir -p "$backup_dir"
        BACKUP_NAME="${app_name}_${TIMESTAMP}"
        cp -r "$web_root/$app_dir" "$backup_dir/$BACKUP_NAME"
        print_status "Backup created at $backup_dir/$BACKUP_NAME"
    fi
}

# Deploy application
deploy_app() {
    print_status "Deploying $app_name..."
    
    # Create application directory
    mkdir -p "$web_root/$app_dir"
    
    # Copy application files (assuming they're in the same directory as this script)
    if [ -f "$SCRIPT_DIR/../meeting_meter/index.php" ]; then
        cp "$SCRIPT_DIR/../meeting_meter/"*.php "$web_root/$app_dir/"
        cp "$SCRIPT_DIR/../meeting_meter/README.md" "$web_root/$app_dir/" 2>/dev/null || true
    else
        print_error "Source files not found. Please ensure the meeting_meter source files are in the parent directory."
        exit 1
    fi
    
    # Copy .htaccess if it exists
    if [ -f "$SCRIPT_DIR/../meeting_meter/.htaccess" ]; then
        cp "$SCRIPT_DIR/../meeting_meter/.htaccess" "$web_root/$app_dir/"
    fi
    
    # Set proper permissions
    chmod 644 "$web_root/$app_dir"/*.php
    chmod 644 "$web_root/$app_dir"/*.md 2>/dev/null || true
    chmod 644 "$web_root/$app_dir/.htaccess" 2>/dev/null || true
    
    print_status "Application files deployed ✓"
}

# Configure web server
configure_web_server() {
    print_status "Configuring web server..."
    
    # Check if Apache is running
    if systemctl is-active --quiet apache2; then
        configure_apache
    elif systemctl is-active --quiet nginx; then
        configure_nginx
    else
        print_warning "No web server detected. Please configure manually."
    fi
}

# Configure Apache
configure_apache() {
    print_status "Configuring Apache..."
    
    # Create Apache virtual host configuration
    VHOST_CONF="$apache_config_file"
    
    if [ ! -f "$VHOST_CONF" ]; then
        sudo tee "$VHOST_CONF" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot $web_root/$app_dir
    
    <Directory $web_root/$app_dir>
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/${app_name}_error.log
    CustomLog \${APACHE_LOG_DIR}/${app_name}_access.log combined
</VirtualHost>
EOF
        print_status "Apache virtual host configuration created"
    fi
    
    # Enable site and required modules
    sudo a2ensite "$apache_site_name"
    sudo a2enmod rewrite headers expires deflate
    sudo systemctl reload apache2
    
    print_status "Apache configuration completed ✓"
}

# Configure Nginx
configure_nginx() {
    print_status "Configuring Nginx..."
    
    # Create Nginx configuration
    NGINX_CONF="$nginx_config_file"
    
    if [ ! -f "$NGINX_CONF" ]; then
        sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name $domain www.$domain;
    root $web_root/$app_dir;
    index index.php;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$(php -r "echo PHP_VERSION;" | cut -d. -f1,2)-fpm.sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF
        print_status "Nginx configuration created"
    fi
    
    # Enable site
    sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
    
    print_status "Nginx configuration completed ✓"
}

# Test deployment
test_deployment() {
    print_status "Testing deployment..."
    
    # Test PHP files
    if php -l "$web_root/$app_dir/index.php" > /dev/null 2>&1; then
        print_status "PHP syntax check passed ✓"
    else
        print_error "PHP syntax check failed"
        exit 1
    fi
    
    # Test if files are accessible
    if [ -f "$web_root/$app_dir/index.php" ]; then
        print_status "Application files accessible ✓"
    else
        print_error "Application files not accessible"
        exit 1
    fi
    
    print_status "Deployment test completed ✓"
}

# Main deployment process
main() {
    echo
    print_status "Starting deployment process..."
    
    # Check for interactive mode
    if [ "$1" = "--interactive" ]; then
        interactive_config
        load_config
    else
        load_config
    fi
    
    check_prerequisites
    create_backup
    deploy_app
    generate_config
    configure_web_server
    test_deployment
    
    echo
    print_status "🎉 Deployment completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Configure DNS to point $domain to this server"
    echo "2. Set up SSL certificate (recommended)"
    echo "3. Access your application at: http://$domain"
    echo "4. Check configuration at: $web_root/$app_dir/config.php"
    echo
    echo "For SSL setup, consider using Let's Encrypt:"
    echo "sudo apt install certbot python3-certbot-apache"
    echo "sudo certbot --apache -d $domain"
    echo
}

# Run main function
main "$@"
