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
if sudo test -d "$CERT_PATH"; then
    print_status "Certificate directory found: $CERT_PATH"
    
    # Check if we can read the certificate
    if sudo test -f "$CERT_PATH/fullchain.pem"; then
        print_status "Certificate file accessible"
        
        # Check certificate details
        print_status "Certificate details:"
        sudo openssl x509 -in "$CERT_PATH/fullchain.pem" -text -noout | grep -A 1 "Subject:" 2>/dev/null || print_warning "Could not read certificate subject"
        echo
        
        print_status "Subject Alternative Names:"
        sudo openssl x509 -in "$CERT_PATH/fullchain.pem" -text -noout | grep -A 1 "Subject Alternative Name:" 2>/dev/null || echo "No SAN found"
        echo
        
        print_status "Certificate expiration:"
        sudo openssl x509 -in "$CERT_PATH/fullchain.pem" -dates -noout 2>/dev/null || print_warning "Could not read certificate dates"
        echo
        
        # Check certificate common name
        CERT_CN=$(sudo openssl x509 -in "$CERT_PATH/fullchain.pem" -subject -noout 2>/dev/null | sed 's/.*CN=\([^,]*\).*/\1/' || echo "Unknown")
        print_status "Certificate Common Name: $CERT_CN"
        
        if [ "$CERT_CN" = "$DOMAIN" ]; then
            print_status "✓ Certificate Common Name matches domain"
        else
            print_error "✗ Certificate Common Name ($CERT_CN) does not match domain ($DOMAIN)"
            print_warning "This is likely causing the SSL error"
        fi
        echo
        
    else
        print_error "Certificate files not accessible in: $CERT_PATH"
        echo
    fi
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

# Check IPv4 resolution
DOMAIN_IPV4=$(dig +short A "$DOMAIN" 2>/dev/null || echo "")
if [ -n "$DOMAIN_IPV4" ]; then
    print_status "Domain $DOMAIN (IPv4) resolves to: $DOMAIN_IPV4"
else
    print_warning "No IPv4 (A) record found for $DOMAIN"
fi

# Check IPv6 resolution
DOMAIN_IPV6=$(dig +short AAAA "$DOMAIN" 2>/dev/null || echo "")
if [ -n "$DOMAIN_IPV6" ]; then
    print_status "Domain $DOMAIN (IPv6) resolves to: $DOMAIN_IPV6"
else
    print_warning "No IPv6 (AAAA) record found for $DOMAIN"
fi

# Get server's public IPs
print_status "Server IP addresses:"
SERVER_IPV4=$(curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s ipinfo.io/ip 2>/dev/null || echo "")
SERVER_IPV6=$(curl -6 -s ifconfig.me 2>/dev/null || curl -6 -s ipinfo.io/ip 2>/dev/null || echo "")

if [ -n "$SERVER_IPV4" ]; then
    print_status "Server IPv4: $SERVER_IPV4"
else
    print_warning "Server IPv4: Not available or not accessible"
fi

if [ -n "$SERVER_IPV6" ]; then
    print_status "Server IPv6: $SERVER_IPV6"
else
    print_warning "Server IPv6: Not available or not accessible"
fi

echo
print_status "DNS Validation:"

# Check IPv4 match
if [ -n "$DOMAIN_IPV4" ] && [ -n "$SERVER_IPV4" ] && [ "$DOMAIN_IPV4" = "$SERVER_IPV4" ]; then
    print_status "✓ IPv4 DNS matches server"
    DNS_VALID=true
elif [ -n "$DOMAIN_IPV4" ] && [ -n "$SERVER_IPV4" ]; then
    print_error "✗ IPv4 DNS mismatch: Domain($DOMAIN_IPV4) ≠ Server($SERVER_IPV4)"
    DNS_VALID=false
else
    print_warning "⚠ IPv4 comparison not possible"
    DNS_VALID=false
fi

# Check IPv6 match
if [ -n "$DOMAIN_IPV6" ] && [ -n "$SERVER_IPV6" ] && [ "$DOMAIN_IPV6" = "$SERVER_IPV6" ]; then
    print_status "✓ IPv6 DNS matches server"
    if [ "$DNS_VALID" != "true" ]; then
        DNS_VALID=true
    fi
elif [ -n "$DOMAIN_IPV6" ] && [ -n "$SERVER_IPV6" ]; then
    print_error "✗ IPv6 DNS mismatch: Domain($DOMAIN_IPV6) ≠ Server($SERVER_IPV6)"
    if [ "$DNS_VALID" != "true" ]; then
        DNS_VALID=false
    fi
else
    print_warning "⚠ IPv6 comparison not possible"
fi

if [ "$DNS_VALID" != "true" ]; then
    print_error "⚠ DNS does not point to this server correctly"
    echo
    print_warning "SSL certificate generation will fail with current DNS settings"
    echo
fi

echo
print_status "=== Recommendations ==="

if [ "$DNS_VALID" != "true" ]; then
    print_error "CRITICAL: Fix DNS configuration first!"
    echo
    echo "1. Update DNS records to point to this server:"
    if [ -n "$SERVER_IPV4" ]; then
        echo "   A record: $DOMAIN → $SERVER_IPV4"
    fi
    if [ -n "$SERVER_IPV6" ]; then
        echo "   AAAA record: $DOMAIN → $SERVER_IPV6"
    fi
    echo
    echo "2. Wait for DNS propagation (can take up to 48 hours)"
    echo "   Test with: dig +short $DOMAIN"
    echo
    echo "3. Verify DNS points to server before generating SSL certificate"
    echo
    print_warning "SSL certificates cannot be generated until DNS points to this server!"
    echo
fi

if [ ! -d "$CERT_PATH" ]; then
    echo "Generate SSL certificate for $DOMAIN (after fixing DNS):"
    echo "   sudo certbot certonly --apache -d $DOMAIN --email your-email@example.com"
    echo
fi

echo "Verify certificate matches domain:"
echo "   sudo openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -text -noout | grep -A 5 'Subject Alternative Name'"
echo

echo "Test SSL configuration:"
echo "   sudo apache2ctl configtest"
echo "   sudo systemctl reload apache2"
echo

echo "Test certificate online (after DNS is fixed):"
echo "   https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo

echo "If certificate exists but domain doesn't match, regenerate:"
echo "   sudo certbot delete --cert-name $DOMAIN"
echo "   sudo certbot certonly --apache -d $DOMAIN --email your-email@example.com"
echo

if [ "$DNS_VALID" != "true" ]; then
    print_error "IMPORTANT: SSL certificate generation will fail until DNS is corrected!"
    echo
    echo "Common DNS fixes:"
    if [ -n "$SERVER_IPV4" ]; then
        echo "• Update A record in your DNS provider to point to: $SERVER_IPV4"
    fi
    if [ -n "$SERVER_IPV6" ]; then
        echo "• Add/update AAAA record in your DNS provider to point to: $SERVER_IPV6"
    fi
    echo "• Remove any conflicting DNS records"
    echo "• Wait for DNS propagation and test with: dig +short $DOMAIN"
    echo
    print_warning "Quick fix commands (run after DNS is corrected):"
    echo "  sudo certbot delete --cert-name $DOMAIN"
    echo "  sudo certbot certonly --apache -d $DOMAIN --email your-email@example.com"
    echo "  sudo systemctl reload apache2"
fi

# Check if there's a certificate mismatch
if sudo test -d "$CERT_PATH"; then
    CERT_CN=$(sudo openssl x509 -in "$CERT_PATH/fullchain.pem" -subject -noout 2>/dev/null | sed 's/.*CN=\([^,]*\).*/\1/' || echo "Unknown")
    if [ "$CERT_CN" != "$DOMAIN" ] && [ "$CERT_CN" != "Unknown" ]; then
        echo
        print_error "CERTIFICATE MISMATCH DETECTED!"
        print_error "Certificate is for: $CERT_CN"
        print_error "But you're accessing: $DOMAIN"
        echo
        print_warning "Quick fix for certificate mismatch:"
        echo "  sudo certbot delete --cert-name $DOMAIN"
        echo "  sudo certbot certonly --apache -d $DOMAIN --email your-email@example.com"
        echo "  sudo systemctl reload apache2"
    fi
fi
