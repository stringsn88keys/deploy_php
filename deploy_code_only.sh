#!/bin/bash

# Meeting Meter - Code Only Deployment Script
# This script only updates application code without touching configurations
# Use this for quick code updates without affecting existing settings

set -e

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

echo -e "${BLUE}=== Meeting Meter - Code Only Deployment ===${NC}"
echo "This script will update only the application code files."
echo "Configuration files, Apache settings, and system services will NOT be modified."
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Please do not run this script as root. It will use sudo when needed.${NC}"
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

# Check if required files exist
REQUIRED_FILES=("$SCRIPT_DIR/../meeting_meter/index.php" "$SCRIPT_DIR/../meeting_meter/meeting_meter_advanced.php" "$SCRIPT_DIR/../meeting_meter/demo.php")
MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$(basename "$file")")
    fi
done

if [ ${#MISSING_FILES[@]} -ne 0 ]; then
    print_error "Missing required files: ${MISSING_FILES[*]}"
    echo "Please ensure the meeting_meter source files are in the parent directory."
    exit 1
fi

# Check if application directory exists
if [ ! -d "$web_root/$app_dir" ]; then
    print_error "Application directory does not exist: $web_root/$app_dir"
    echo "Please run the full deployment script first, or update the configuration."
    exit 1
fi

# Create backup of current application files
if [ "$enable_backup" = "true" ]; then
    BACKUP_DIR="$backup_dir/$(date +%Y%m%d_%H%M%S)"
    print_status "Creating backup of current application files..."
    sudo mkdir -p "$BACKUP_DIR"
    sudo cp -r "$web_root/$app_dir"/* "$BACKUP_DIR/" 2>/dev/null || echo "No existing files to backup"
    print_status "Backup created at: $BACKUP_DIR"
fi

# Copy application files
print_status "Updating application files..."
sudo cp "$SCRIPT_DIR/../meeting_meter/"*.php "$web_root/$app_dir/"

# Copy README.md if it exists
if [ -f "$SCRIPT_DIR/../meeting_meter/README.md" ]; then
    sudo cp "$SCRIPT_DIR/../meeting_meter/README.md" "$web_root/$app_dir/"
    print_status "README.md updated"
fi

# Copy snippets.php if it exists
if [ -f "$SCRIPT_DIR/../meeting_meter/snippets.php" ]; then
    sudo cp "$SCRIPT_DIR/../meeting_meter/snippets.php" "$web_root/$app_dir/"
    print_status "snippets.php updated"
else
    print_warning "No snippets.php file found in source"
fi

# Copy .htaccess if it exists
if [ -f "$SCRIPT_DIR/../meeting_meter/.htaccess" ]; then
    sudo cp "$SCRIPT_DIR/../meeting_meter/.htaccess" "$web_root/$app_dir/"
    print_status ".htaccess updated"
else
    print_warning "No .htaccess file found in source"
fi

# Set proper permissions for application files
print_status "Setting file permissions..."
sudo chown www-data:www-data "$web_root/$app_dir"/*.php
sudo chmod 644 "$web_root/$app_dir"/*.php

if [ -f "$web_root/$app_dir/.htaccess" ]; then
    sudo chown www-data:www-data "$web_root/$app_dir/.htaccess"
    sudo chmod 644 "$web_root/$app_dir/.htaccess"
fi

if [ -f "$web_root/$app_dir/README.md" ]; then
    sudo chown www-data:www-data "$web_root/$app_dir/README.md"
    sudo chmod 644 "$web_root/$app_dir/README.md"
fi

# Test PHP syntax
print_status "Testing PHP syntax..."
PHP_FILES=("$web_root/$app_dir/index.php" "$web_root/$app_dir/meeting_meter_advanced.php" "$web_root/$app_dir/demo.php")
SYNTAX_ERRORS=0

for file in "${PHP_FILES[@]}"; do
    if sudo php -l "$file" > /dev/null 2>&1; then
        print_status "✓ $(basename "$file") syntax OK"
    else
        print_error "✗ $(basename "$file") syntax error"
        SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
done

if [ $SYNTAX_ERRORS -gt 0 ]; then
    print_error "PHP syntax errors detected! Rolling back to backup..."
    if [ "$enable_backup" = "true" ] && [ -d "$BACKUP_DIR" ]; then
        sudo cp -r "$BACKUP_DIR"/* "$web_root/$app_dir/"
        print_warning "Rolled back to previous version"
    fi
    print_error "Please fix syntax errors and try again"
    exit 1
fi

# Test Apache configuration (if Apache is running)
if systemctl is-active --quiet apache2; then
    print_status "Testing Apache configuration..."
    if sudo apache2ctl configtest > /dev/null 2>&1; then
        print_status "✓ Apache configuration OK"
    else
        print_warning "⚠ Apache configuration has issues (but continuing)"
    fi
else
    print_warning "Apache is not running, skipping configuration test"
fi

# Clean up backup (optional)
if [ "$enable_backup" = "true" ] && [ -d "$BACKUP_DIR" ]; then
    echo
    read -p "Delete backup files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo rm -rf "$BACKUP_DIR"
        print_status "Backup cleaned up"
    else
        print_status "Backup preserved at: $BACKUP_DIR"
    fi
fi

print_status "=== Code Only Deployment Complete! ==="
echo
print_status "Summary:"
echo "✓ Application files updated in: $web_root/$app_dir"
echo "✓ File permissions set correctly"
echo "✓ PHP syntax validated"
if [ "$enable_backup" = "true" ]; then
    echo "✓ Backup created (if not deleted)"
fi
echo
print_status "Updated files:"
echo "• index.php"
echo "• meeting_meter_advanced.php"
echo "• demo.php"
if [ -f "$web_root/$app_dir/snippets.php" ]; then
    echo "• snippets.php"
fi
if [ -f "$web_root/$app_dir/.htaccess" ]; then
    echo "• .htaccess"
fi
if [ -f "$web_root/$app_dir/README.md" ]; then
    echo "• README.md"
fi
echo
print_status "What was NOT changed:"
echo "• Configuration files (config.php)"
echo "• Apache virtual host settings"
echo "• Systemd service files"
echo "• Log rotation settings"
echo "• Environment variables"
echo "• SSL certificates"
echo
print_status "Next steps:"
echo "1. Test your application at: http://$domain"
echo "2. Check application logs if needed"
echo "3. Monitor for any issues"
echo
print_warning "Note: If you need to update configurations, use deploy_production.sh instead."
