# Meeting Meter PHP Deployment

This directory contains deployment scripts and configuration templates for the Meeting Meter PHP application. The deployment system is designed to be flexible and configurable, allowing you to customize deployment settings without modifying the scripts.

## Files

### Deployment Scripts

- **`deploy.sh`** - Main deployment script with interactive configuration
- **`deploy_production.sh`** - Production deployment with security hardening
- **`deploy_code_only.sh`** - Code-only updates without touching configurations

### Configuration Files

- **`deploy.ini.example`** - Example configuration file with all available options
- **`config.php.template`** - PHP configuration template with placeholders

## Quick Start

1. **Interactive Setup** (Recommended for first-time deployment):
   ```bash
   ./deploy.sh --interactive
   ```
   This will prompt you for basic configuration and create a `deploy.ini` file.

2. **Production Deployment**:
   ```bash
   ./deploy_production.sh
   ```
   This deploys with security hardening, SSL setup, and systemd service.

3. **Code Updates Only**:
   ```bash
   ./deploy_code_only.sh
   ```
   This updates only the PHP files without touching configurations.

## Configuration

### Creating Configuration

The deployment system uses a `deploy.ini` file for configuration. You can create this file in two ways:

1. **Interactive Mode**: Run `./deploy.sh --interactive` to be prompted for settings
2. **Manual Creation**: Copy `deploy.ini.example` to `deploy.ini` and edit the values

### Configuration Sections

The `deploy.ini` file is organized into sections:

#### `[general]`
- `app_name` - Application name
- `domain` - Domain name for the application
- `web_root` - Web server root directory
- `app_dir` - Application directory (relative to web_root)
- `backup_dir` - Backup directory for rollbacks

#### `[apache]`
- `config_file` - Apache configuration file path
- `site_name` - Apache site name
- `security_headers` - Enable security headers
- `rate_limiting` - Enable rate limiting
- `rate_limit` - Rate limit requests per minute

#### `[nginx]`
- `config_file` - Nginx configuration file path
- `site_name` - Nginx site name

#### `[security]`
- `secure_config_dir` - Secure configuration directory (outside web root)
- `log_dir` - Log directory
- `config_permissions` - Configuration file permissions
- `dir_permissions` - Directory permissions

#### `[php]`
- `min_php_version` - Required PHP version
- `required_extensions` - Required PHP extensions (comma-separated)
- `upload_max_filesize` - PHP upload max filesize
- `post_max_size` - PHP post max size
- `max_execution_time` - PHP max execution time
- `memory_limit` - PHP memory limit
- `session_gc_maxlifetime` - PHP session lifetime

#### `[ssl]`
- `enable_ssl` - Enable SSL setup with Let's Encrypt
- `ssl_email` - Email for Let's Encrypt registration
- `ssl_alt_domains` - Additional domains for SSL

#### `[systemd]`
- `enable_service` - Enable systemd service
- `service_file` - Service file path
- `env_file` - Environment file path

#### `[logrotate]`
- `enable_logrotate` - Enable log rotation
- `logrotate_file` - Log rotation config file
- `log_retention_days` - Log retention days

#### `[backup]`
- `enable_backup` - Enable backup before deployment
- `backup_retention_days` - Backup retention days
- `compress_backup` - Backup compression

## Configuration Template

The `config.php.template` file contains placeholders that are replaced during deployment:

- `{{ALPHA_VANTAGE_API_KEY}}` - API key for stock data
- `{{APP_NAME}}` - Application name
- `{{DEBUG_MODE}}` - Debug mode setting
- `{{DEFAULT_TIMEZONE}}` - Default timezone
- `{{LOG_ENABLED}}` - Logging enabled
- `{{LOG_FILE}}` - Log file path
- And many more...

## Deployment Modes

### 1. Interactive Deployment (`deploy.sh --interactive`)

Best for first-time setup:
- Prompts for basic configuration
- Creates `deploy.ini` file
- Deploys application with basic settings

### 2. Production Deployment (`deploy_production.sh`)

Full production setup with security:
- Uses existing `deploy.ini` configuration
- Creates secure configuration directory
- Sets up Apache virtual host with security headers
- Configures log rotation
- Creates systemd service
- Optional SSL certificate setup
- Rate limiting and security hardening

### 3. Code-Only Deployment (`deploy_code_only.sh`)

Quick code updates:
- Updates only PHP files
- Preserves existing configurations
- Creates backup before update
- Validates PHP syntax
- No system configuration changes

## Security Features

The production deployment includes several security features:

- **Secure Configuration**: Config files stored outside web root
- **Proper Permissions**: 600 for config files, 750 for directories
- **Security Headers**: X-Content-Type-Options, X-Frame-Options, etc.
- **Rate Limiting**: Configurable request rate limiting
- **Log Rotation**: Prevents disk space issues
- **SSL Support**: Optional Let's Encrypt integration

## Requirements

- PHP 7.4 or higher
- Apache2 or Nginx
- sudo privileges
- Source files in `../meeting_meter/` directory

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure you're not running as root and have sudo privileges
2. **Missing Files**: Ensure source files are in `../meeting_meter/` directory
3. **Configuration Errors**: Check `deploy.ini` file for correct paths and settings
4. **PHP Syntax Errors**: The code-only deployment will roll back if syntax errors are detected

### Logs

- Application logs: `$log_dir/app.log`
- Apache logs: `/var/log/apache2/${app_name}-*.log`
- System logs: `journalctl -u apache2`

### Useful Commands

```bash
# View application logs
sudo tail -f $log_dir/app.log

# Restart Apache
sudo systemctl restart apache2

# Check Apache status
sudo systemctl status apache2

# Test Apache configuration
sudo apache2ctl configtest

# View Apache configuration
sudo apache2ctl -S
```

## Customization

### Adding New Configuration Options

1. Add the option to `deploy.ini.example`
2. Update the deployment scripts to read the new option
3. Add the placeholder to `config.php.template` if needed
4. Update the generation logic in the scripts

### Custom Web Server Support

To add support for other web servers:

1. Create a new configuration section in `deploy.ini.example`
2. Add a new `configure_<server>()` function
3. Update the `configure_web_server()` function to detect and call the new function

## Examples

### Basic Deployment

```bash
# First time setup
./deploy.sh --interactive

# Production deployment
./deploy_production.sh
```

### Code Updates

```bash
# Update only PHP files
./deploy_code_only.sh
```

### Custom Configuration

```bash
# Edit configuration
nano deploy.ini

# Deploy with custom settings
./deploy_production.sh
```

## Support

For issues or questions:

1. Check the logs for error messages
2. Verify configuration file settings
3. Ensure all required files are present
4. Check system requirements and permissions
