#!/bin/bash

# SSL Certificate Debug Script
# This script helps diagnose SSL certificate issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo -e "${BLUE}=== SSL Certificate Debug Tool ===${NC}"
echo

# Get domain from user
read -p "Enter the domain name having SSL issues: " DOMAIN
if [ -z "$DOMAIN" ]; then
    print_error "Domain name cannot be empty"
    exit 1
fi

echo
print_status "Diagnosing SSL certificate for: $DOMAIN"
echo

# Check if certificate exists
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
if [ -d "$CERT_PATH" ]; then
    print_status "Certificate directory found: $CERT_PATH"
    
    # Check certificate details
    print_status "Certificate details:"
    sudo openssl x509 -in "$CERT_PATH/fullchain.pem" -text -noout | grep -A 1 "Subject:"
    echo
    
    print_status "Subject Alternative Names:"
    sudo openssl x509 -in "$CERT_PATH/fullchain.pem" -text -noout | grep -A 1 "Subject Alternative Name:" || echo "No SAN found"
    echo
    
    print_status "Certificate expiration:"
    sudo openssl x509 -in "$CERT_PATH/fullchain.pem" -dates -noout
    echo
    
else
    print_error "Certificate directory not found: $CERT_PATH"
    echo
fi

# Check available certificates
print_status "All available Let's Encrypt certificates:"
sudo certbot certificates 2>/dev/null || print_warning "Certbot not available or no certificates found"
echo

# Check Apache configuration
print_status "Checking Apache SSL configuration..."
APACHE_CONFIGS=$(find /etc/apache2/sites-available/ -name "*.conf" 2>/dev/null | grep -E "(${DOMAIN//./\\.}|$(echo $DOMAIN | sed 's/[.-]/_/g'))" || true)

if [ -n "$APACHE_CONFIGS" ]; then
    for config in $APACHE_CONFIGS; do
        print_status "Found Apache config: $config"
        echo "SSL Certificate paths in config:"
        grep -E "SSLCertificate(File|KeyFile)" "$config" 2>/dev/null || echo "No SSL certificate paths found"
        echo
        echo "ServerName and ServerAlias:"
        grep -E "ServerName|ServerAlias" "$config" 2>/dev/null || echo "No ServerName/ServerAlias found"
        echo
    done
else
    print_warning "No Apache configuration found for domain: $DOMAIN"
fi

# Check if domain resolves to this server
print_status "DNS resolution check:"
DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null || echo "DNS lookup failed")
if [ -n "$DOMAIN_IP" ] && [ "$DOMAIN_IP" != "DNS lookup failed" ]; then
    print_status "Domain $DOMAIN resolves to: $DOMAIN_IP"
    
    # Get server's public IP
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "Unable to determine server IP")
    if [ "$DOMAIN_IP" = "$SERVER_IP" ]; then
        print_status "✓ Domain points to this server"
    else
        print_warning "⚠ Domain points to $DOMAIN_IP, but this server is $SERVER_IP"
    fi
else
    print_error "✗ Domain does not resolve or DNS lookup failed"
fi

echo
print_status "=== Recommendations ==="

if [ ! -d "$CERT_PATH" ]; then
    echo "1. Generate SSL certificate for $DOMAIN:"
    echo "   sudo certbot certonly --apache -d $DOMAIN --email your-email@example.com"
    echo
fi

echo "2. Verify certificate matches domain:"
echo "   sudo openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -text -noout | grep -A 5 'Subject Alternative Name'"
echo

echo "3. Test SSL configuration:"
echo "   sudo apache2ctl configtest"
echo "   sudo systemctl reload apache2"
echo

echo "4. Test certificate online:"
echo "   https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo

echo "5. If certificate exists but domain doesn't match, regenerate:"
echo "   sudo certbot delete --cert-name $DOMAIN"
echo "   sudo certbot certonly --apache -d $DOMAIN --email your-email@example.com"
echo
