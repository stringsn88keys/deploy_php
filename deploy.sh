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

# Domains configuration file
DOMAINS_CONFIG_FILE="$SCRIPT_DIR/domains.ini"

# Default domains configuration
DEFAULT_DOMAINS_CONFIG_FILE="$SCRIPT_DIR/domains.ini.example"

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
        
        # Parse INI file properly, skipping section headers
        while IFS='=' read -r key value; do
            # Skip empty lines and comments
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
            
            # Skip section headers
            [[ "$key" =~ ^\[.*\]$ ]] && continue
            
            # Clean up key and value
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Skip empty keys
            [[ -z "$key" ]] && continue
            
            # Export the variable
            export "$key"="$value"
        done < "$CONFIG_FILE"
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
    # Use awk to extract the section content safely
    DOMAIN_CONFIG=$(awk -v section="$SELECTED_DOMAIN" '
        /^\[/ { 
            gsub(/[[:space:]]+$/, "", $0)  # Remove trailing spaces
            in_section = ($0 == "[" section "]") 
        }
        in_section && !/^\[/ && NF > 0 { print }
    ' "$DOMAINS_CONFIG_FILE")
    
    if [ -z "$DOMAIN_CONFIG" ]; then
        echo -e "${RED}Configuration for domain $SELECTED_DOMAIN not found${NC}"
        echo -e "${YELLOW}Available sections in domains.ini:${NC}"
        grep -E '^\[.*\]$' "$DOMAINS_CONFIG_FILE" || echo "No sections found"
        return 1
    fi
    
    # Set domain-specific variables
    while IFS='=' read -r key value; do
        if [ -n "$key" ] && [ -n "$value" ]; then
            # Remove leading/trailing whitespace
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            export "$key"="$value"
        fi
    done <<< "$DOMAIN_CONFIG"
    
    echo -e "${GREEN}Domain configuration loaded for: $SELECTED_DOMAIN${NC}"
    return 0
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
    
    read -p "Web root directory [/var/www/html]: " web_root
    web_root=${web_root:-/var/www/html}
    
    read -p "Enable multi-domain support? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        multi_domain_enabled=true
        echo -e "${GREEN}Multi-domain support enabled${NC}"
        
        # Create domains configuration
        if [ ! -f "$DOMAINS_CONFIG_FILE" ]; then
            cp "$DEFAULT_DOMAINS_CONFIG_FILE" "$DOMAINS_CONFIG_FILE"
            echo -e "${GREEN}Domains configuration template created: $DOMAINS_CONFIG_FILE${NC}"
            echo -e "${YELLOW}Please edit the domains configuration file to add your domains${NC}"
        fi
        
        # Ask for default domain
        read -p "Default domain name [meetingmeter.example.com]: " default_domain
        default_domain=${default_domain:-meetingmeter.example.com}
        
        # Update config file
        sed -i "s/app_name = .*/app_name = $app_name/" "$CONFIG_FILE"
        sed -i "s|web_root = .*|web_root = $web_root|" "$CONFIG_FILE"
        sed -i "s/default_domain = .*/default_domain = $default_domain/" "$CONFIG_FILE"
        sed -i "s/multi_domain_enabled = .*/multi_domain_enabled = true/" "$CONFIG_FILE"
        
        echo -e "${GREEN}Multi-domain configuration saved to: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}Please configure your domains in: $DOMAINS_CONFIG_FILE${NC}"
    else
        multi_domain_enabled=false
        echo -e "${GREEN}Single domain mode enabled${NC}"
        
        # Single domain setup
        read -p "Domain name [meetingmeter.example.com]: " domain
        domain=${domain:-meetingmeter.example.com}
        
        read -p "Application directory [meeting_meter]: " app_dir
        app_dir=${app_dir:-meeting_meter}
        
        # Update config file
        sed -i "s/app_name = .*/app_name = $app_name/" "$CONFIG_FILE"
        sed -i "s|web_root = .*|web_root = $web_root|" "$CONFIG_FILE"
        sed -i "s/default_domain = .*/default_domain = $domain/" "$CONFIG_FILE"
        sed -i "s/multi_domain_enabled = .*/multi_domain_enabled = false/" "$CONFIG_FILE"
        
        # Set single domain variables for backward compatibility
        sed -i "s/domain = .*/domain = $domain/" "$CONFIG_FILE"
        sed -i "s/app_dir = .*/app_dir = $app_dir/" "$CONFIG_FILE"
        
        echo -e "${GREEN}Single domain configuration saved to: $CONFIG_FILE${NC}"
    fi
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
    
    # Create secure configuration directory if specified
    if [ -n "$secure_config_dir" ] && [ "$secure_config_dir" != "$web_root/$app_dir" ]; then
        print_status "Creating secure configuration directory: $secure_config_dir"
        sudo mkdir -p "$secure_config_dir"
        sudo chown www-data:www-data "$secure_config_dir"
        sudo chmod 750 "$secure_config_dir"
    fi
    
    # Create log directory if specified
    if [ -n "$log_dir" ]; then
        print_status "Creating log directory: $log_dir"
        sudo mkdir -p "$log_dir"
        sudo chown www-data:www-data "$log_dir"
        sudo chmod 750 "$log_dir"
        
        # Create log file
        sudo touch "$log_dir/app.log"
        sudo chown www-data:www-data "$log_dir/app.log"
        sudo chmod 640 "$log_dir/app.log"
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
        "$SCRIPT_DIR/config.php.template" | sudo tee "$web_root/$app_dir/config.php" > /dev/null
    
    # Set proper permissions for config file
    sudo chown www-data:www-data "$web_root/$app_dir/config.php"
    sudo chmod 644 "$web_root/$app_dir/config.php"
    
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
    
    # Create application directory with proper permissions
    print_status "Creating application directory: $web_root/$app_dir"
    sudo mkdir -p "$web_root/$app_dir"
    sudo chown www-data:www-data "$web_root/$app_dir"
    sudo chmod 755 "$web_root/$app_dir"
    
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
    
    # Copy application files
    if [ -f "$SOURCE_DIR/index.php" ]; then
        sudo cp "$SOURCE_DIR/"*.php "$web_root/$app_dir/"
        sudo cp "$SOURCE_DIR/README.md" "$web_root/$app_dir/" 2>/dev/null || true
        print_status "Application files copied from: $SOURCE_DIR"
    else
        print_error "Source files not found in: $SOURCE_DIR"
        print_error "Please ensure the source files are available or update the source_dir configuration"
        exit 1
    fi
    
    # Copy .htaccess if it exists
    if [ -f "$SOURCE_DIR/.htaccess" ]; then
        sudo cp "$SOURCE_DIR/.htaccess" "$web_root/$app_dir/"
        print_status ".htaccess copied"
    fi
    
    # Copy snippets.php if it exists
    if [ -f "$SOURCE_DIR/snippets.php" ]; then
        sudo cp "$SOURCE_DIR/snippets.php" "$web_root/$app_dir/"
        print_status "snippets.php copied"
    fi
    
    # Set proper permissions for application files
    print_status "Setting file permissions..."
    sudo chown www-data:www-data "$web_root/$app_dir"/*
    sudo chmod 644 "$web_root/$app_dir"/*.php
    sudo chmod 644 "$web_root/$app_dir"/*.md 2>/dev/null || true
    sudo chmod 644 "$web_root/$app_dir/.htaccess" 2>/dev/null || true
    
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
        print_status "Creating Apache virtual host configuration: $VHOST_CONF"
        sudo tee "$VHOST_CONF" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot $web_root/$app_dir
    
    <Directory $web_root/$app_dir>
        AllowOverride All
        Require all granted
        Options -Indexes +FollowSymLinks
        
        # Basic security headers
        Header always set X-Content-Type-Options nosniff
        Header always set X-Frame-Options DENY
        Header always set X-XSS-Protection "1; mode=block"
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/${app_name}_error.log
    CustomLog \${APACHE_LOG_DIR}/${app_name}_access.log combined
</VirtualHost>
EOF
        print_status "Apache virtual host configuration created"
        
        # Set proper permissions for Apache config
        sudo chmod 644 "$VHOST_CONF"
        sudo chown root:root "$VHOST_CONF"
    fi
    
    # Enable site and required modules
    print_status "Enabling Apache site and modules..."
    sudo a2ensite "$apache_site_name" 2>/dev/null || print_warning "Site may already be enabled"
    sudo a2enmod rewrite headers expires deflate 2>/dev/null || true
    
    # Test Apache configuration
    if sudo apache2ctl configtest; then
        print_status "Apache configuration is valid"
        sudo systemctl reload apache2
        print_status "Apache reloaded successfully"
    else
        print_error "Apache configuration has errors"
        exit 1
    fi
    
    print_status "Apache configuration completed ✓"
}

# Configure Nginx
configure_nginx() {
    print_status "Configuring Nginx..."
    
    # Create Nginx configuration
    NGINX_CONF="$nginx_config_file"
    
    if [ ! -f "$NGINX_CONF" ]; then
        print_status "Creating Nginx configuration: $NGINX_CONF"
        sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name $domain www.$domain;
    root $web_root/$app_dir;
    index index.php;
    
    # Basic security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
    
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
    
    # Deny access to sensitive files
    location ~ \.(log|sh|md)$ {
        deny all;
    }
}
EOF
        print_status "Nginx configuration created"
        
        # Set proper permissions for Nginx config
        sudo chmod 644 "$NGINX_CONF"
        sudo chown root:root "$NGINX_CONF"
    fi
    
    # Enable site
    print_status "Enabling Nginx site..."
    sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    
    # Test and reload Nginx
    if sudo nginx -t; then
        print_status "Nginx configuration is valid"
        sudo systemctl reload nginx
        print_status "Nginx reloaded successfully"
    else
        print_error "Nginx configuration has errors"
        exit 1
    fi
    
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
    
    # Handle multi-domain selection
    if [ "$multi_domain_enabled" = "true" ]; then
        echo -e "${BLUE}=== Multi-Domain Mode ===${NC}"
        
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
