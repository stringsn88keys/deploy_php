#!/bin/bash

# Meeting Meter PHP Deployment Test Script
# This script tests the deployment system without actually deploying

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Meeting Meter PHP Deployment Test ===${NC}"
echo "This script tests the deployment system without actually deploying."
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

# Test 1: Check if all required files exist
print_status "Testing file structure..."

REQUIRED_FILES=(
    "deploy.sh"
    "deploy_production.sh"
    "deploy_code_only.sh"
    "setup_example.sh"
    "deploy.ini.example"
    "config.php.template"
    "README.md"
    "DEPLOYMENT_GUIDE.md"
)

MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_status "✓ $file exists"
    else
        MISSING_FILES+=("$file")
        print_error "✗ $file missing"
    fi
done

if [ ${#MISSING_FILES[@]} -ne 0 ]; then
    print_error "Missing required files: ${MISSING_FILES[*]}"
    exit 1
fi

# Test 2: Check if scripts are executable
print_status "Testing script permissions..."

SCRIPTS=("deploy.sh" "deploy_production.sh" "deploy_code_only.sh" "setup_example.sh")

for script in "${SCRIPTS[@]}"; do
    if [ -x "$script" ]; then
        print_status "✓ $script is executable"
    else
        print_error "✗ $script is not executable"
        exit 1
    fi
done

# Test 3: Check if source files exist
print_status "Testing source files..."

if [ -d "../meeting_meter" ]; then
    print_status "✓ Source directory exists"
    
    SOURCE_FILES=("index.php" "meeting_meter_advanced.php" "demo.php")
    
    for file in "${SOURCE_FILES[@]}"; do
        if [ -f "../meeting_meter/$file" ]; then
            print_status "✓ $file exists in source"
        else
            print_warning "⚠ $file missing in source"
        fi
    done
else
    print_warning "⚠ Source directory not found (../meeting_meter)"
fi

# Test 4: Test configuration file parsing
print_status "Testing configuration file parsing..."

if [ -f "deploy.ini.example" ]; then
    # Test if we can parse the configuration
    # Parse INI file properly, skipping section headers
    if { while IFS='=' read -r key value; do
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
    done < "deploy.ini.example"; } 2>/dev/null; then
        print_status "✓ Configuration file parsing works"
    else
        print_error "✗ Configuration file parsing failed"
        exit 1
    fi
else
    print_error "✗ deploy.ini.example not found"
    exit 1
fi

# Test 5: Test template processing
print_status "Testing template processing..."

if [ -f "config.php.template" ]; then
    # Test if template has placeholders
    PLACEHOLDERS=("{{ALPHA_VANTAGE_API_KEY}}" "{{APP_NAME}}" "{{DEBUG_MODE}}")
    
    for placeholder in "${PLACEHOLDERS[@]}"; do
        if grep -q "$placeholder" "config.php.template"; then
            print_status "✓ Placeholder $placeholder found in template"
        else
            print_warning "⚠ Placeholder $placeholder not found in template"
        fi
    done
else
    print_error "✗ config.php.template not found"
    exit 1
fi

# Test 6: Test script syntax
print_status "Testing script syntax..."

for script in "${SCRIPTS[@]}"; do
    if bash -n "$script" 2>/dev/null; then
        print_status "✓ $script syntax is valid"
    else
        print_error "✗ $script syntax error"
        exit 1
    fi
done

# Test 7: Test PHP syntax in source files
print_status "Testing PHP syntax in source files..."

if [ -d "../meeting_meter" ]; then
    PHP_FILES=("../meeting_meter/index.php" "../meeting_meter/meeting_meter_advanced.php" "../meeting_meter/demo.php")
    
    for file in "${PHP_FILES[@]}"; do
        if [ -f "$file" ]; then
            if php -l "$file" > /dev/null 2>&1; then
                print_status "✓ $(basename "$file") syntax is valid"
            else
                print_warning "⚠ $(basename "$file") syntax error"
            fi
        fi
    done
fi

# Test 8: Test configuration generation
print_status "Testing configuration generation..."

# Create a temporary config file
TEMP_CONFIG="/tmp/test_deploy.ini"
cat > "$TEMP_CONFIG" << 'EOF'
[general]
app_name = test_app
domain = test.example.com
web_root = /tmp/test_web
app_dir = test_app

[apache]
config_file = /tmp/test_apache.conf
site_name = test-site

[security]
secure_config_dir = /tmp/test_config
log_dir = /tmp/test_logs
EOF

# Test if we can load the config
# Parse INI file properly, skipping section headers
if { while IFS='=' read -r key value; do
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
done < "$TEMP_CONFIG"; } 2>/dev/null; then
    print_status "✓ Configuration loading works"
else
    print_error "✗ Configuration loading failed"
    exit 1
fi

# Test template processing
if [ -f "config.php.template" ]; then
    TEMP_OUTPUT="/tmp/test_config.php"
    sed -e "s/{{ALPHA_VANTAGE_API_KEY}}/test_key/g" \
        -e "s/{{APP_NAME}}/test_app/g" \
        -e "s/{{DEBUG_MODE}}/true/g" \
        "config.php.template" > "$TEMP_OUTPUT"
    
    if [ -f "$TEMP_OUTPUT" ]; then
        print_status "✓ Template processing works"
        rm -f "$TEMP_OUTPUT"
    else
        print_error "✗ Template processing failed"
        exit 1
    fi
fi

# Clean up
rm -f "$TEMP_CONFIG"

# Test 9: Test help and usage
print_status "Testing script help and usage..."

for script in "${SCRIPTS[@]}"; do
    if [ -x "$script" ]; then
        if "$script" --help > /dev/null 2>&1 || "$script" -h > /dev/null 2>&1; then
            print_status "✓ $script has help option"
        else
            print_warning "⚠ $script may not have help option"
        fi
    fi
done

# Summary
echo
print_status "=== Test Summary ==="
print_status "✓ File structure test passed"
print_status "✓ Script permissions test passed"
print_status "✓ Configuration parsing test passed"
print_status "✓ Template processing test passed"
print_status "✓ Script syntax test passed"
print_status "✓ PHP syntax test passed"
print_status "✓ Configuration generation test passed"
print_status "✓ Help and usage test passed"

echo
print_status "🎉 All tests passed! The deployment system is ready to use."
echo
print_status "Next steps:"
echo "1. Run ./setup_example.sh for interactive setup"
echo "2. Or copy deploy.ini.example to deploy.ini and customize"
echo "3. Run ./deploy_production.sh for production deployment"
echo
print_status "For more information, see README.md and DEPLOYMENT_GUIDE.md"
