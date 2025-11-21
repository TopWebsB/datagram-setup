#!/bin/bash

# Quick Deploy Script for VPS Datagram Setup
# One-liner: bash <(curl -s https://raw.githubusercontent.com/TopWebsB/datagram-setup/main/scripts/quick-deploy.sh)

set -e

# Configuration
REPO_OWNER="TopWebsB"
REPO_NAME="datagram-setup"
MAIN_SCRIPT_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/main/setup.sh"

# Banner
echo "=================================================="
echo "WEBS DATAGRAM SETUP"
echo "=================================================="
echo "Automated VPS Deployment for Datagram Nodes"
echo "GitHub: https://github.com/TopWebsB/datagram-setup"
echo "=================================================="
echo

# Function to download and verify script
download_script() {
    local url=$1
    local temp_script="/tmp/datagram-setup-$$.sh"
    
    echo "[INFO] Downloading setup script from TopWebsB/datagram-setup..."
    if curl -fsSL "$url" -o "$temp_script"; then
        if [ -s "$temp_script" ]; then
            echo "[SUCCESS] Script downloaded successfully"
            chmod +x "$temp_script"
            echo "$temp_script"
        else
            echo "[ERROR] Downloaded script is empty"
            return 1
        fi
    else
        echo "[ERROR] Failed to download setup script"
        return 1
    fi
}

# Function to check system compatibility
check_system() {
    echo "[INFO] Checking system compatibility..."
    
    # Check if Ubuntu
    if [ ! -f /etc/os-release ]; then
        echo "[ERROR] Unsupported operating system"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        echo "[WARNING] This script is optimized for Ubuntu. You're running $PRETTY_NAME"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    echo "[SUCCESS] System check passed: $PRETTY_NAME"
}

# Function to check internet connectivity
check_internet() {
    echo "[INFO] Checking internet connectivity..."
    if ! curl -s --head https://github.com > /dev/null; then
        echo "[ERROR] No internet connection. Please check your network."
        exit 1
    fi
    echo "[SUCCESS] Internet connection verified"
}

# Function to display usage
show_usage() {
    echo
    echo "Usage:"
    echo "  bash <(curl -s https://raw.githubusercontent.com/TopWebsB/datagram-setup/main/scripts/quick-deploy.sh)"
    echo
    echo "Options:"
    echo "  DATAGRAM_LICENSE=your_key bash <(curl -s https://raw.githubusercontent.com/TopWebsB/datagram-setup/main/scripts/quick-deploy.sh)"
    echo
    echo "Examples:"
    echo "  # Basic deployment (will prompt for license key)"
    echo "  bash <(curl -s https://raw.githubusercontent.com/TopWebsB/datagram-setup/main/scripts/quick-deploy.sh)"
    echo
    echo "  # With pre-set license key"
    echo "  DATAGRAM_LICENSE=\"abc123...\" bash <(curl -s https://raw.githubusercontent.com/TopWebsB/datagram-setup/main/scripts/quick-deploy.sh)"
    echo
}

# Main execution
main() {
    local temp_script
    
    # Check arguments
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Initial checks
    check_internet
    check_system
    
    # Download script
    temp_script=$(download_script "$MAIN_SCRIPT_URL") || {
        echo
        echo "[ERROR] Setup script not found or download failed."
        echo
        echo "To fix this issue:"
        echo "1. Make sure 'setup.sh' exists in your repository root"
        echo "2. Check the file URL: $MAIN_SCRIPT_URL"
        echo "3. Verify the repository: https://github.com/TopWebsB/datagram-setup"
        echo
        echo "For manual setup:"
        echo "  git clone https://github.com/TopWebsB/datagram-setup.git"
        echo "  cd datagram-setup"
        echo "  ./setup.sh"
        exit 1
    }
    
    # Validate script syntax
    echo "[INFO] Validating setup script..."
    if bash -n "$temp_script" 2>/dev/null; then
        echo "[SUCCESS] Script validation passed"
    else
        echo "[ERROR] Script validation failed - syntax errors detected"
        exit 1
    fi
    
    # Execute the script
    echo
    echo "================================================"
    echo "[INFO] Starting automated Datagram node setup..."
    echo "================================================"
    
    # Check if license key is provided via environment
    if [ -n "$DATAGRAM_LICENSE" ]; then
        echo "[INFO] Using license key from environment variable"
    else
        echo "[INFO] You will be prompted for your license key during setup"
    fi
    
    # Ask for confirmation
    echo
    read -p "Continue with setup? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "[INFO] Setup cancelled by user"
        exit 0
    fi
    
    # Execute the main setup script
    bash "$temp_script"
}

# Trap to clean up temp files
trap 'rm -f /tmp/datagram-setup-*.sh 2>/dev/null' EXIT

# Run main function with all arguments
main "$@"
