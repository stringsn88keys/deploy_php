#!/bin/bash

# Meeting Meter PHP Deployment Setup Example
# This script demonstrates how to use the deployment system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Meeting Meter PHP Deployment Setup Example ===${NC}"
echo
echo "This script demonstrates how to use the deployment system."
echo "It will show you the different deployment modes and their use cases."
echo

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

# Check if we're in the right directory
if [ ! -f "deploy.sh" ]; then
    print_error "This script must be run from the deploy_php directory"
    exit 1
fi

# Check if source files exist
if [ ! -d "../meeting_meter" ]; then
    print_error "Source files not found. Please ensure the meeting_meter directory is in the parent directory."
    exit 1
fi

print_status "Source files found ✓"

echo -e "${BLUE}=== Deployment Modes ===${NC}"
echo
echo "1. Interactive Deployment (First-time setup)"
echo "   - Prompts for configuration"
echo "   - Creates deploy.ini file"
echo "   - Basic deployment"
echo
echo "2. Production Deployment (Full production setup)"
echo "   - Uses existing deploy.ini"
echo "   - Security hardening"
echo "   - SSL setup"
echo "   - Systemd service"
echo
echo "3. Code-Only Deployment (Quick updates)"
echo "   - Updates only PHP files"
echo "   - Preserves configurations"
echo "   - Creates backup"
echo

echo -e "${YELLOW}Choose a deployment mode:${NC}"
echo "1) Interactive Deployment"
echo "2) Production Deployment"
echo "3) Code-Only Deployment"
echo "4) Show configuration example"
echo "5) Exit"
echo

read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        print_status "Starting interactive deployment..."
        ./deploy.sh --interactive
        ;;
    2)
        if [ ! -f "deploy.ini" ]; then
            print_warning "Configuration file not found. Running interactive setup first..."
            ./deploy.sh --interactive
        fi
        print_status "Starting production deployment..."
        ./deploy_production.sh
        ;;
    3)
        if [ ! -f "deploy.ini" ]; then
            print_error "Configuration file not found. Please run interactive deployment first."
            exit 1
        fi
        print_status "Starting code-only deployment..."
        ./deploy_code_only.sh
        ;;
    4)
        echo -e "${BLUE}=== Configuration Example ===${NC}"
        echo
        echo "Here's an example of a deploy.ini configuration:"
        echo
        cat << 'EOF'
[general]
app_name = meeting_meter
domain = meetingmeter.example.com
web_root = /var/www/html
app_dir = meeting_meter
backup_dir = /tmp/meeting_meter_backup

[apache]
config_file = /etc/apache2/sites-available/meeting-meter.conf
site_name = meeting-meter
security_headers = true
rate_limiting = true
rate_limit = 400

[security]
secure_config_dir = /etc/meeting_meter
log_dir = /var/log/meeting_meter
config_permissions = 600
dir_permissions = 750

[php]
min_php_version = 7.4
required_extensions = json,session,mbstring
upload_max_filesize = 10M
post_max_size = 10M
max_execution_time = 30
memory_limit = 128M

[ssl]
enable_ssl = false
ssl_email = webmaster@example.com

[systemd]
enable_service = true
service_file = /etc/systemd/system/meeting-meter.service
env_file = /etc/default/meeting-meter

[logrotate]
enable_logrotate = true
logrotate_file = /etc/logrotate.d/meeting-meter
log_retention_days = 52

[backup]
enable_backup = true
backup_retention_days = 7
compress_backup = true
EOF
        echo
        print_status "Configuration example displayed"
        ;;
    5)
        print_status "Exiting..."
        exit 0
        ;;
    *)
        print_error "Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo
print_status "Setup example completed!"
echo
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review the generated configuration file (deploy.ini)"
echo "2. Customize settings as needed"
echo "3. Run the appropriate deployment script"
echo "4. Test your application"
echo
echo -e "${BLUE}Useful commands:${NC}"
echo "• View logs: sudo tail -f /var/log/meeting_meter/app.log"
echo "• Restart Apache: sudo systemctl restart apache2"
echo "• Check status: sudo systemctl status apache2"
echo
