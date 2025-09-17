#!/bin/bash

# Meeting Meter Domain Management Utility
# This script helps manage multiple domain configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration files
CONFIG_FILE="$SCRIPT_DIR/deploy.ini"
DOMAINS_CONFIG_FILE="$SCRIPT_DIR/domains.ini"
DEFAULT_DOMAINS_CONFIG_FILE="$SCRIPT_DIR/domains.ini.example"

echo -e "${BLUE}=== Meeting Meter Domain Management ===${NC}"

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

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source <(grep -v '^#' "$CONFIG_FILE" | grep -v '^$' | sed 's/^\[\(.*\)\]/\1=/')
    else
        print_error "Configuration file not found: $CONFIG_FILE"
        echo "Please run ./deploy.sh --interactive first to create configuration"
        exit 1
    fi
}

# List all domains
list_domains() {
    if [ ! -f "$DOMAINS_CONFIG_FILE" ]; then
        print_error "Domains configuration file not found: $DOMAINS_CONFIG_FILE"
        return 1
    fi
    
    echo -e "${BLUE}Configured domains:${NC}"
    echo
    
    # Extract domain names from the configuration file
    DOMAINS=($(grep -E '^\[.*\]$' "$DOMAINS_CONFIG_FILE" | sed 's/\[\(.*\)\]/\1/' | grep -v '^$'))
    
    if [ ${#DOMAINS[@]} -eq 0 ]; then
        echo "No domains configured."
        return 0
    fi
    
    for i in "${!DOMAINS[@]}"; do
        echo "$((i+1)). ${DOMAINS[i]}"
        
        # Show domain details
        DOMAIN_SECTION="[${DOMAINS[i]}]"
        DOMAIN_CONFIG=$(awk "/^$DOMAIN_SECTION$/,/^\[/" "$DOMAINS_CONFIG_FILE" | grep -v "^$DOMAIN_SECTION$" | grep -v "^\[" | grep -v "^$")
        
        while IFS='=' read -r key value; do
            if [ -n "$key" ] && [ -n "$value" ]; then
                key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                case "$key" in
                    "domain") echo "   Domain: $value" ;;
                    "app_name") echo "   App Name: $value" ;;
                    "app_dir") echo "   App Directory: $value" ;;
                    "source_dir") echo "   Source Directory: $value" ;;
                    "enable_ssl") echo "   SSL Enabled: $value" ;;
                esac
            fi
        done <<< "$DOMAIN_CONFIG"
        echo
    done
}

# Add a new domain
add_domain() {
    echo -e "${BLUE}=== Add New Domain ===${NC}"
    
    # Check if domains config exists
    if [ ! -f "$DOMAINS_CONFIG_FILE" ]; then
        if [ -f "$DEFAULT_DOMAINS_CONFIG_FILE" ]; then
            cp "$DEFAULT_DOMAINS_CONFIG_FILE" "$DOMAINS_CONFIG_FILE"
            print_status "Created domains configuration file from template"
        else
            print_error "Default domains configuration template not found"
            return 1
        fi
    fi
    
    # Get domain information
    read -p "Domain name (e.g., example.com): " domain_name
    if [ -z "$domain_name" ]; then
        print_error "Domain name cannot be empty"
        return 1
    fi
    
    # Check if domain already exists
    if grep -q "^\[$domain_name\]" "$DOMAINS_CONFIG_FILE"; then
        print_error "Domain $domain_name already exists"
        return 1
    fi
    
    read -p "Application name [$domain_name]: " app_name
    app_name=${app_name:-$domain_name}
    
    read -p "Application directory [${domain_name//./_}]: " app_dir
    app_dir=${app_dir:-${domain_name//./_}}
    
    read -p "Source directory [../meeting_meter]: " source_dir
    source_dir=${source_dir:-../meeting_meter}
    
    read -p "Enable SSL? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        enable_ssl=true
        read -p "SSL email address: " ssl_email
    else
        enable_ssl=false
        ssl_email=""
    fi
    
    # Add domain configuration
    cat >> "$DOMAINS_CONFIG_FILE" << EOF

[$domain_name]
# Domain-specific settings
domain = $domain_name
app_name = $app_name
web_root = $web_root
app_dir = $app_dir

# Source directory (relative to deploy_php directory)
source_dir = $source_dir

# Apache configuration
apache_config_file = /etc/apache2/sites-available/${app_name}.conf
apache_site_name = $app_name

# Security settings
secure_config_dir = /etc/$app_name
log_dir = /var/log/$app_name

# SSL settings
enable_ssl = $enable_ssl
ssl_email = $ssl_email
ssl_alt_domains = www.$domain_name

# Backup settings
backup_dir = /tmp/${app_name}_backup
EOF
    
    print_status "Domain $domain_name added successfully"
    print_status "Configuration saved to: $DOMAINS_CONFIG_FILE"
}

# Remove a domain
remove_domain() {
    echo -e "${BLUE}=== Remove Domain ===${NC}"
    
    if [ ! -f "$DOMAINS_CONFIG_FILE" ]; then
        print_error "Domains configuration file not found"
        return 1
    fi
    
    # List domains
    list_domains
    
    DOMAINS=($(grep -E '^\[.*\]$' "$DOMAINS_CONFIG_FILE" | sed 's/\[\(.*\)\]/\1/' | grep -v '^$'))
    
    if [ ${#DOMAINS[@]} -eq 0 ]; then
        print_warning "No domains to remove"
        return 0
    fi
    
    read -p "Enter domain name to remove: " domain_to_remove
    
    if [ -z "$domain_to_remove" ]; then
        print_error "Domain name cannot be empty"
        return 1
    fi
    
    if ! grep -q "^\[$domain_to_remove\]" "$DOMAINS_CONFIG_FILE"; then
        print_error "Domain $domain_to_remove not found"
        return 1
    fi
    
    read -p "Are you sure you want to remove domain $domain_to_remove? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove domain section
        sed -i "/^\[$domain_to_remove\]$/,/^\[/ { /^\[$domain_to_remove\]$/d; /^\[/!d; }" "$DOMAINS_CONFIG_FILE"
        print_status "Domain $domain_to_remove removed successfully"
    else
        print_status "Domain removal cancelled"
    fi
}

# Edit domain configuration
edit_domain() {
    echo -e "${BLUE}=== Edit Domain Configuration ===${NC}"
    
    if [ ! -f "$DOMAINS_CONFIG_FILE" ]; then
        print_error "Domains configuration file not found"
        return 1
    fi
    
    # List domains
    list_domains
    
    DOMAINS=($(grep -E '^\[.*\]$' "$DOMAINS_CONFIG_FILE" | sed 's/\[\(.*\)\]/\1/' | grep -v '^$'))
    
    if [ ${#DOMAINS[@]} -eq 0 ]; then
        print_warning "No domains to edit"
        return 0
    fi
    
    read -p "Enter domain name to edit: " domain_to_edit
    
    if [ -z "$domain_to_edit" ]; then
        print_error "Domain name cannot be empty"
        return 1
    fi
    
    if ! grep -q "^\[$domain_to_edit\]" "$DOMAINS_CONFIG_FILE"; then
        print_error "Domain $domain_to_edit not found"
        return 1
    fi
    
    print_status "Opening domain configuration for editing..."
    print_warning "Please edit the configuration carefully and save when done"
    
    # Open in editor (prefer nano, fallback to vi)
    if command -v nano &> /dev/null; then
        nano "$DOMAINS_CONFIG_FILE"
    elif command -v vi &> /dev/null; then
        vi "$DOMAINS_CONFIG_FILE"
    else
        print_error "No text editor found. Please edit $DOMAINS_CONFIG_FILE manually"
        return 1
    fi
    
    print_status "Domain configuration updated"
}

# Validate domain configuration
validate_domains() {
    echo -e "${BLUE}=== Validate Domain Configuration ===${NC}"
    
    if [ ! -f "$DOMAINS_CONFIG_FILE" ]; then
        print_error "Domains configuration file not found"
        return 1
    fi
    
    DOMAINS=($(grep -E '^\[.*\]$' "$DOMAINS_CONFIG_FILE" | sed 's/\[\(.*\)\]/\1/' | grep -v '^$'))
    
    if [ ${#DOMAINS[@]} -eq 0 ]; then
        print_warning "No domains configured"
        return 0
    fi
    
    VALIDATION_ERRORS=0
    
    for domain in "${DOMAINS[@]}"; do
        echo -e "${YELLOW}Validating domain: $domain${NC}"
        
        DOMAIN_SECTION="[$domain]"
        DOMAIN_CONFIG=$(awk "/^$DOMAIN_SECTION$/,/^\[/" "$DOMAINS_CONFIG_FILE" | grep -v "^$DOMAIN_SECTION$" | grep -v "^\[" | grep -v "^$")
        
        # Check required fields
        REQUIRED_FIELDS=("domain" "app_name" "app_dir" "web_root")
        for field in "${REQUIRED_FIELDS[@]}"; do
            if ! echo "$DOMAIN_CONFIG" | grep -q "^$field ="; then
                print_error "Missing required field: $field"
                VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
            fi
        done
        
        # Check source directory
        source_dir=$(echo "$DOMAIN_CONFIG" | grep "^source_dir =" | cut -d'=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$source_dir" ]; then
            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            FULL_SOURCE_PATH="$SCRIPT_DIR/$source_dir"
            if [ ! -d "$FULL_SOURCE_PATH" ]; then
                print_warning "Source directory does not exist: $FULL_SOURCE_PATH"
            else
                if [ ! -f "$FULL_SOURCE_PATH/index.php" ]; then
                    print_warning "Source directory exists but index.php not found: $FULL_SOURCE_PATH"
                fi
            fi
        else
            print_warning "No source directory specified for domain: $domain"
        fi
        
        # Check for duplicate app directories
        app_dir=$(echo "$DOMAIN_CONFIG" | grep "^app_dir =" | cut -d'=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "$app_dir" ]; then
            duplicate_count=$(grep -c "^app_dir = $app_dir" "$DOMAINS_CONFIG_FILE" || true)
            if [ "$duplicate_count" -gt 1 ]; then
                print_warning "Duplicate app directory: $app_dir"
            fi
        fi
        
        echo "✓ Domain $domain validation completed"
        echo
    done
    
    if [ $VALIDATION_ERRORS -eq 0 ]; then
        print_status "All domains validated successfully"
    else
        print_error "Found $VALIDATION_ERRORS validation errors"
        return 1
    fi
}

# Show help
show_help() {
    echo -e "${BLUE}Meeting Meter Domain Management Utility${NC}"
    echo
    echo "Usage: $0 [command]"
    echo
    echo "Commands:"
    echo "  list       List all configured domains"
    echo "  add        Add a new domain"
    echo "  remove     Remove a domain"
    echo "  edit       Edit domain configuration"
    echo "  validate   Validate domain configuration"
    echo "  help       Show this help message"
    echo
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 add"
    echo "  $0 remove"
    echo "  $0 edit"
    echo "  $0 validate"
}

# Main function
main() {
    # Load configuration
    load_config
    
    case "${1:-help}" in
        "list")
            list_domains
            ;;
        "add")
            add_domain
            ;;
        "remove")
            remove_domain
            ;;
        "edit")
            edit_domain
            ;;
        "validate")
            validate_domains
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function
main "$@"
