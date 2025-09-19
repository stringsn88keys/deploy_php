# Meeting Meter Multi-Domain Deployment Guide

This guide explains how to use the multi-domain deployment feature of the Meeting Meter PHP application.

## Overview

The multi-domain feature allows you to deploy the Meeting Meter application to multiple domains on the same server, each with its own configuration, SSL certificates, application directories, and even different source code versions.

## Features

- **Multiple Domain Support**: Deploy to multiple domains with separate configurations
- **Domain Management**: Easy-to-use domain management utility
- **Isolated Configurations**: Each domain has its own app directory, config, and logs
- **Source Directory Support**: Each domain can use different source code directories
- **SSL Support**: Individual SSL certificates for each domain
- **Backward Compatibility**: Single domain mode still supported

## Quick Start

### 1. Initial Setup

Run the interactive setup to enable multi-domain support:

```bash
./deploy.sh --interactive
```

When prompted, choose "y" to enable multi-domain support.

### 2. Configure Domains

Use the domain management utility to add your domains:

```bash
./manage_domains.sh add
```

### 3. Deploy

Deploy to a specific domain:

```bash
./deploy_production.sh
```

The script will prompt you to select which domain to deploy to.

## Configuration Files

### deploy.ini

Main configuration file with multi-domain settings:

```ini
[general]
app_name = meeting_meter
default_domain = meetingmeter.example.com
web_root = /var/www/html
app_dir = meeting_meter
backup_dir = /tmp/meeting_meter_backup

# Enable multi-domain support
multi_domain_enabled = true

# Domains configuration file
domains_config = domains.ini
```

### domains.ini

Domain-specific configurations:

```ini
[meetingmeter.example.com]
domain = meetingmeter.example.com
app_name = meeting_meter
web_root = /var/www/html
app_dir = meeting_meter
source_dir = ../meeting_meter
apache_config_file = /etc/apache2/sites-available/meeting-meter.conf
apache_site_name = meeting-meter
secure_config_dir = /etc/meeting_meter
log_dir = /var/log/meeting_meter
enable_ssl = false
ssl_email = webmaster@meetingmeter.example.com
ssl_alt_domains =
backup_dir = /tmp/meeting_meter_backup

[meetingmeter2.example.com]
domain = meetingmeter2.example.com
app_name = meeting_meter_2
web_root = /var/www/html
app_dir = meeting_meter_2
source_dir = ../meeting_meter_v2
apache_config_file = /etc/apache2/sites-available/meeting-meter-2.conf
apache_site_name = meeting-meter-2
secure_config_dir = /etc/meeting_meter_2
log_dir = /var/log/meeting_meter_2
enable_ssl = false
ssl_email = webmaster@meetingmeter2.example.com
ssl_alt_domains =
backup_dir = /tmp/meeting_meter_2_backup
```

## Domain Management

### Available Commands

```bash
# List all configured domains
./manage_domains.sh list

# Add a new domain
./manage_domains.sh add

# Remove a domain
./manage_domains.sh remove

# Edit domain configuration
./manage_domains.sh edit

# Validate domain configuration
./manage_domains.sh validate

# Show help
./manage_domains.sh help
```

### Adding a Domain

1. Run `./manage_domains.sh add`
2. Enter the domain name (e.g., `example.com`)
3. Enter application name (defaults to domain name)
4. Enter application directory (defaults to sanitized domain name)
5. Enter source directory (defaults to ../meeting_meter)
6. Choose whether to enable SSL
7. If SSL enabled, enter SSL email address
8. If SSL enabled, optionally enter additional SSL domains (leave empty for main domain only)

### Domain Configuration Fields

Each domain configuration includes:

- **domain**: The domain name
- **app_name**: Application name for this domain
- **app_dir**: Directory name for this domain's files
- **source_dir**: Source code directory (relative to deploy_php directory)
- **web_root**: Web server root directory
- **apache_config_file**: Apache virtual host configuration file
- **apache_site_name**: Apache site name
- **secure_config_dir**: Secure configuration directory
- **log_dir**: Log directory for this domain
- **enable_ssl**: Whether SSL is enabled
- **ssl_email**: Email for SSL certificate
- **ssl_alt_domains**: Additional domains for SSL certificate (optional, comma-separated)
- **backup_dir**: Backup directory for this domain

## Source Directory Support

Each domain can use a different source code directory, allowing you to:

- **Deploy different versions**: Use v1.0 for domain1 and v2.0 for domain2
- **Customize applications**: Each domain can have its own customized version
- **Test new features**: Deploy experimental versions to test domains
- **Maintain separate codebases**: Keep different applications for different domains

### Source Directory Structure

```
deploy_php/
├── meeting_meter/          # Default source (v1.0)
├── meeting_meter_v2/       # Version 2 source
├── meeting_meter_custom/   # Customized version
└── domains.ini             # Domain configurations
```

### Example Use Cases

1. **Version Management**:
   - `meetingmeter.com` → `../meeting_meter` (stable version)
   - `beta.meetingmeter.com` → `../meeting_meter_beta` (beta version)

2. **Customization**:
   - `client1.example.com` → `../meeting_meter_client1` (client-specific)
   - `client2.example.com` → `../meeting_meter_client2` (different client)

3. **Testing**:
   - `test.example.com` → `../meeting_meter_test` (test environment)
   - `staging.example.com` → `../meeting_meter_staging` (staging environment)

## Deployment Modes

### Interactive Deployment

```bash
./deploy.sh --interactive
```

- Prompts for configuration
- Creates deploy.ini file
- Supports single or multi-domain setup
- Basic deployment

### Production Deployment

```bash
./deploy_production.sh
```

- Uses existing deploy.ini
- Security hardening
- SSL setup
- Systemd service
- Multi-domain support with domain selection

### Code-Only Deployment

```bash
./deploy_code_only.sh
```

- Updates only PHP files
- Preserves configurations
- Creates backup
- Multi-domain support with domain selection

## Directory Structure

With multi-domain support, your server will have this structure:

```
/var/www/html/
├── meeting_meter/          # Domain 1 files
├── meeting_meter_2/        # Domain 2 files
└── meeting_meter_3/        # Domain 3 files

/etc/
├── meeting_meter/          # Domain 1 config
├── meeting_meter_2/        # Domain 2 config
└── meeting_meter_3/        # Domain 3 config

/var/log/
├── meeting_meter/          # Domain 1 logs
├── meeting_meter_2/        # Domain 2 logs
└── meeting_meter_3/        # Domain 3 logs

/etc/apache2/sites-available/
├── meeting-meter.conf      # Domain 1 Apache config
├── meeting-meter-2.conf    # Domain 2 Apache config
└── meeting-meter-3.conf    # Domain 3 Apache config
```

## SSL Configuration

Each domain can have its own SSL certificate:

1. Set `enable_ssl = true` in the domain configuration
2. Set the `ssl_email` for Let's Encrypt registration
3. Optionally add alternative domains in `ssl_alt_domains` (comma-separated)
4. Run the production deployment script

**Note**: Alternative domains are optional. Leave `ssl_alt_domains` empty to generate SSL certificates for the main domain only.

### SSL Alternative Domains

The `ssl_alt_domains` field allows you to specify additional domains for the SSL certificate:

- **Empty** (recommended): Certificate for main domain only
  ```ini
  ssl_alt_domains =
  ```

- **Single alternative**: Certificate for main domain + one alternative
  ```ini
  ssl_alt_domains = www.example.com
  ```

- **Multiple alternatives**: Certificate for main domain + multiple alternatives
  ```ini
  ssl_alt_domains = www.example.com,app.example.com,api.example.com
  ```

**Important**: All alternative domains must point to the same server and be accessible during certificate generation.

The script will automatically:
- Install certbot if not present
- Enable required Apache SSL modules
- Configure OCSP stapling for better performance
- Generate SSL certificates for the domain and alternative domains
- Update Apache virtual host configuration with:
  - HTTP to HTTPS redirect (301 redirect)
  - SSL certificate paths
  - Modern SSL/TLS protocols and ciphers
  - Enhanced security headers for HTTPS
  - HSTS (HTTP Strict Transport Security)
  - Content Security Policy headers
- Validate the SSL configuration
- Reload Apache with the new configuration

## Troubleshooting

### Common Issues

1. **Domain not found**: Check that the domain is properly configured in `domains.ini`
2. **Permission errors**: Ensure proper file permissions are set
3. **Apache configuration errors**: Validate Apache configuration with `sudo apache2ctl configtest`
4. **SSL certificate issues**: Check Let's Encrypt logs and domain DNS settings

### SSL-Specific Troubleshooting

1. **SSL certificate generation fails**:
   - Ensure domain DNS is properly configured and pointing to your server
   - Check that ports 80 and 443 are open and accessible
   - Verify domain ownership with `dig +short yourdomain.com`

2. **SSL configuration errors**:
   - Check Apache SSL configuration: `sudo apache2ctl configtest`
   - Verify SSL modules are enabled: `apache2ctl -M | grep ssl`
   - Check SSL certificate files exist: `ls -la /etc/letsencrypt/live/yourdomain.com/`

3. **Mixed content warnings**:
   - Ensure all resources (images, CSS, JS) use HTTPS or relative URLs
   - Check Content Security Policy headers aren't too restrictive

4. **SSL certificate renewal issues**:
   - Test renewal: `sudo certbot renew --dry-run`
   - Check cron job: `sudo crontab -l | grep certbot`
   - Verify certificate expiration: `sudo certbot certificates`

### Validation

Always validate your domain configuration:

```bash
./manage_domains.sh validate
```

This will check for:
- Required fields
- Duplicate app directories
- Configuration syntax

### Logs

Check domain-specific logs:

```bash
# View application logs
sudo tail -f /var/log/meeting_meter/app.log

# View Apache logs (HTTP)
sudo tail -f /var/log/apache2/meeting-meter-error.log
sudo tail -f /var/log/apache2/meeting-meter-access.log

# View Apache SSL logs (if SSL enabled)
sudo tail -f /var/log/apache2/meeting-meter-ssl-error.log
sudo tail -f /var/log/apache2/meeting-meter-ssl-access.log
```

### SSL Testing Commands

When SSL is enabled, use these commands to test and monitor:

```bash
# Test SSL certificate
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com

# Check certificate expiration
sudo certbot certificates

# Test SSL configuration
curl -I https://yourdomain.com

# Test HTTP to HTTPS redirect
curl -I http://yourdomain.com

# Check SSL rating (external)
# Visit: https://www.ssllabs.com/ssltest/analyze.html?d=yourdomain.com
```

## Migration from Single Domain

To migrate from single domain to multi-domain:

1. Backup your current configuration
2. Run `./deploy.sh --interactive`
3. Choose multi-domain mode
4. Add your existing domain using `./manage_domains.sh add`
5. Deploy using `./deploy_production.sh`

## Best Practices

1. **Use descriptive app names**: Make app names unique and descriptive
2. **Separate app directories**: Each domain should have its own app directory
3. **Regular backups**: Set up automated backups for each domain
4. **Monitor logs**: Check logs regularly for each domain
5. **SSL everywhere**: Enable SSL for all production domains
6. **Validate configurations**: Always validate before deploying

## Examples

### Example 1: Basic Multi-Domain Setup

```bash
# 1. Initial setup
./deploy.sh --interactive
# Choose multi-domain mode

# 2. Add domains
./manage_domains.sh add
# Add: example1.com
# Source directory: ../meeting_meter
./manage_domains.sh add
# Add: example2.com
# Source directory: ../meeting_meter_v2

# 3. Deploy to first domain
./deploy_production.sh
# Select: example1.com

# 4. Deploy to second domain
./deploy_production.sh
# Select: example2.com
```

### Example 2: Code Update for All Domains

```bash
# Update code for domain 1
./deploy_code_only.sh
# Select: example1.com

# Update code for domain 2
./deploy_code_only.sh
# Select: example2.com
```

### Example 3: Source Directory Management

```bash
# Set up different source directories
mkdir -p ../meeting_meter_stable
mkdir -p ../meeting_meter_beta
mkdir -p ../meeting_meter_custom

# Copy different versions to each directory
cp -r ../meeting_meter/* ../meeting_meter_stable/
cp -r ../meeting_meter/* ../meeting_meter_beta/
cp -r ../meeting_meter/* ../meeting_meter_custom/

# Add domains with different source directories
./manage_domains.sh add
# Domain: stable.example.com
# Source directory: ../meeting_meter_stable

./manage_domains.sh add
# Domain: beta.example.com
# Source directory: ../meeting_meter_beta

./manage_domains.sh add
# Domain: custom.example.com
# Source directory: ../meeting_meter_custom

# Deploy each domain
./deploy_production.sh
# Select: stable.example.com

./deploy_production.sh
# Select: beta.example.com

./deploy_production.sh
# Select: custom.example.com
```

### Example 4: Domain Management

```bash
# List all domains
./manage_domains.sh list

# Edit a domain
./manage_domains.sh edit
# Select: example1.com

# Validate configuration
./manage_domains.sh validate
```

## Support

For issues or questions:

1. Check the logs for error messages
2. Validate your configuration
3. Review this guide
4. Check the main README.md for general deployment issues

## Security Considerations

- Each domain has isolated configurations
- Secure config directories are outside web root
- Proper file permissions are set automatically
- SSL certificates are domain-specific with automatic renewal
- Logs are separated by domain

### SSL Security Features

When SSL is enabled, the system implements:

- **Modern TLS protocols**: Only TLS 1.2 and 1.3 are supported
- **Strong cipher suites**: ECDHE and AES-GCM preferred
- **HSTS headers**: Prevents downgrade attacks
- **OCSP stapling**: Improves SSL handshake performance
- **HTTP to HTTPS redirect**: All traffic is automatically redirected
- **Enhanced security headers**:
  - Content Security Policy (CSP)
  - X-Frame-Options: DENY
  - X-Content-Type-Options: nosniff
  - Referrer-Policy: strict-origin-when-cross-origin
- **Secure session cookies**: HTTPOnly and Secure flags enabled
- **Certificate transparency**: Full certificate chain provided
