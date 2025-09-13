# Meeting Meter PHP Deployment Guide

This guide explains how to use the extracted deployment scripts for the Meeting Meter PHP application.

## Overview

The deployment system has been extracted from the original PHP project and enhanced with:

- **Configurable Templates**: All settings can be customized via `deploy.ini`
- **Template-Driven Configuration**: PHP config generated from `config.php.template`
- **Multiple Deployment Modes**: Interactive, production, and code-only deployments
- **Security Hardening**: Production deployments include security features
- **Backup and Rollback**: Automatic backups with rollback on errors

## Directory Structure

```
deploy_php/
├── deploy.sh                 # Main deployment script
├── deploy_production.sh      # Production deployment with security
├── deploy_code_only.sh       # Code-only updates
├── setup_example.sh          # Interactive setup example
├── deploy.ini.example        # Configuration template
├── config.php.template       # PHP configuration template
├── README.md                 # Documentation
└── DEPLOYMENT_GUIDE.md       # This guide
```

## Quick Start

### 1. First-Time Setup

```bash
cd ~/stringsn88keys/deploy_php
./setup_example.sh
```

This will guide you through the setup process and create a `deploy.ini` file.

### 2. Production Deployment

```bash
./deploy_production.sh
```

This deploys with full security hardening, SSL setup, and systemd service.

### 3. Code Updates

```bash
./deploy_code_only.sh
```

This updates only the PHP files without touching configurations.

## Configuration System

### deploy.ini Configuration

The `deploy.ini` file controls all deployment settings:

```ini
[general]
app_name = meeting_meter
domain = meetingmeter.example.com
web_root = /var/www/html
app_dir = meeting_meter

[apache]
config_file = /etc/apache2/sites-available/meeting-meter.conf
site_name = meeting-meter
security_headers = true
rate_limiting = true

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
```

### config.php.template

The PHP configuration is generated from a template with placeholders:

```php
<?php
// API Configuration
define('ALPHA_VANTAGE_API_KEY', '{{ALPHA_VANTAGE_API_KEY}}');

// Application Settings
define('APP_NAME', '{{APP_NAME}}');
define('APP_VERSION', '2.0.0');
define('DEBUG_MODE', {{DEBUG_MODE}});

// Security Settings
define('LOG_ENABLED', {{LOG_ENABLED}});
define('LOG_FILE', '{{LOG_FILE}}');

// ... more configuration options
?>
```

## Deployment Modes

### 1. Interactive Deployment (`deploy.sh --interactive`)

**Use Case**: First-time setup or configuration changes

**Features**:
- Prompts for basic configuration
- Creates `deploy.ini` file
- Deploys application with basic settings
- User-friendly setup process

**Example**:
```bash
./deploy.sh --interactive
```

### 2. Production Deployment (`deploy_production.sh`)

**Use Case**: Full production deployment with security

**Features**:
- Uses existing `deploy.ini` configuration
- Creates secure configuration directory
- Sets up Apache virtual host with security headers
- Configures log rotation
- Creates systemd service
- Optional SSL certificate setup
- Rate limiting and security hardening

**Example**:
```bash
./deploy_production.sh
```

### 3. Code-Only Deployment (`deploy_code_only.sh`)

**Use Case**: Quick code updates without configuration changes

**Features**:
- Updates only PHP files
- Preserves existing configurations
- Creates backup before update
- Validates PHP syntax
- No system configuration changes

**Example**:
```bash
./deploy_code_only.sh
```

## Security Features

### Production Security

The production deployment includes:

- **Secure Configuration**: Config files stored outside web root
- **Proper Permissions**: 600 for config files, 750 for directories
- **Security Headers**: X-Content-Type-Options, X-Frame-Options, etc.
- **Rate Limiting**: Configurable request rate limiting
- **Log Rotation**: Prevents disk space issues
- **SSL Support**: Optional Let's Encrypt integration

### Security Headers

Apache configuration includes:

```apache
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains" env=HTTPS
```

## Customization

### Adding New Configuration Options

1. **Add to `deploy.ini.example`**:
   ```ini
   [new_section]
   new_option = default_value
   ```

2. **Update deployment scripts** to read the new option:
   ```bash
   # In deploy.sh or deploy_production.sh
   new_option=$(grep '^new_option' "$CONFIG_FILE" | cut -d'=' -f2)
   ```

3. **Add placeholder to `config.php.template`** if needed:
   ```php
   define('NEW_OPTION', '{{NEW_OPTION}}');
   ```

4. **Update generation logic**:
   ```bash
   sed -e "s/{{NEW_OPTION}}/$new_option/g" \
       "$SCRIPT_DIR/config.php.template" > "$web_root/$app_dir/config.php"
   ```

### Custom Web Server Support

To add support for other web servers:

1. **Create configuration section** in `deploy.ini.example`:
   ```ini
   [custom_server]
   config_file = /path/to/config
   site_name = custom-site
   ```

2. **Add detection function**:
   ```bash
   configure_custom_server() {
       print_status "Configuring custom server..."
       # Implementation here
   }
   ```

3. **Update `configure_web_server()`**:
   ```bash
   configure_web_server() {
       if systemctl is-active --quiet custom-server; then
           configure_custom_server
       elif systemctl is-active --quiet apache2; then
           configure_apache
       elif systemctl is-active --quiet nginx; then
           configure_nginx
       fi
   }
   ```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure you're not running as root
   - Check sudo privileges
   - Verify file permissions

2. **Missing Source Files**
   - Ensure source files are in `../meeting_meter/` directory
   - Check file paths in configuration

3. **Configuration Errors**
   - Validate `deploy.ini` file syntax
   - Check all required options are set
   - Verify paths exist and are accessible

4. **PHP Syntax Errors**
   - Code-only deployment will roll back on syntax errors
   - Check PHP version compatibility
   - Validate all PHP files before deployment

### Logs and Monitoring

**Application Logs**:
```bash
sudo tail -f /var/log/meeting_meter/app.log
```

**Apache Logs**:
```bash
sudo tail -f /var/log/apache2/meeting-meter-*.log
```

**System Logs**:
```bash
journalctl -u apache2
```

**Check Apache Status**:
```bash
sudo systemctl status apache2
```

**Test Apache Configuration**:
```bash
sudo apache2ctl configtest
```

### Rollback Procedures

**Code-Only Deployment Rollback**:
```bash
# If backup was created
sudo cp -r /tmp/meeting_meter_backup/YYYYMMDD_HHMMSS/* /var/www/html/meeting_meter/
```

**Full Rollback**:
```bash
# Disable site
sudo a2dissite meeting-meter

# Remove application
sudo rm -rf /var/www/html/meeting_meter

# Restore from backup
sudo cp -r /tmp/meeting_meter_backup/YYYYMMDD_HHMMSS/* /var/www/html/meeting_meter/
```

## Best Practices

### Configuration Management

1. **Version Control**: Keep `deploy.ini` in version control
2. **Environment-Specific**: Use different configs for dev/staging/prod
3. **Secrets Management**: Store sensitive data in environment variables
4. **Documentation**: Document custom configurations

### Deployment Workflow

1. **Development**: Use interactive deployment for testing
2. **Staging**: Use production deployment with test domain
3. **Production**: Use production deployment with full security
4. **Updates**: Use code-only deployment for quick fixes

### Security Considerations

1. **Regular Updates**: Keep PHP and web server updated
2. **SSL Certificates**: Use Let's Encrypt for SSL
3. **Log Monitoring**: Monitor logs for security issues
4. **Backup Strategy**: Regular backups with retention policy
5. **Access Control**: Limit file permissions and access

## Examples

### Basic Development Setup

```bash
# Interactive setup
./deploy.sh --interactive

# Configure for development
echo "debug_mode = true" >> deploy.ini
echo "log_enabled = true" >> deploy.ini

# Deploy
./deploy_production.sh
```

### Production Deployment

```bash
# Configure for production
cp deploy.ini.example deploy.ini
# Edit deploy.ini with production settings

# Deploy with security
./deploy_production.sh
```

### Code Updates

```bash
# Update source files
# ... make changes to PHP files ...

# Deploy code only
./deploy_code_only.sh
```

### SSL Setup

```bash
# Enable SSL in configuration
echo "enable_ssl = true" >> deploy.ini
echo "ssl_email = admin@example.com" >> deploy.ini

# Deploy with SSL
./deploy_production.sh
```

## Support

For issues or questions:

1. Check the logs for error messages
2. Verify configuration file settings
3. Ensure all required files are present
4. Check system requirements and permissions
5. Review this guide for troubleshooting steps

The deployment system is designed to be robust and provide clear error messages to help diagnose issues.
