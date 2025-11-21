#!/bin/bash

# Quick Deploy Script for VPS Datagram Setup
# One-liner: bash <(curl -s https://raw.githubusercontent.com/TopWebsB/datagram-setup/main/scripts/quick-deploy.sh)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${CYAN}[ℹ]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${BLUE}[→]${NC} $1"; }

# Banner
echo -e "${CYAN}"
cat << "EOF"
████████╗ ██████╗ ██████╗██╗     ██████╗  █████╗ ████████╗ █████╗
╚══██╔══╝██╔═══██╗██╔══██╗██║    ██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗
   ██║   ██║   ██║██████╔╝       ██║  ██║███████║   ██║   ███████║
   ██║   ██║   ██║██╔═══╝        ██║  ██║██╔══██║   ██║   ██╔══██║
   ██║   ╚██████╔╝██║            ██████╔╝██║  ██║   ██║   ██║  ██║
   ╚═╝    ╚═════╝ ╚═╝            ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝ 
EOF
echo -e "${NC}"
echo -e "${YELLOW}🚀 Quick Deploy: VPS Datagram Node Setup${NC}"
echo "================================================"
echo -e "${BLUE}GitHub: https://github.com/TopWebsB/datagram-setup${NC}"
echo

# Configuration
REPO_OWNER="TopWebsB"
REPO_NAME="datagram-setup"
MAIN_SCRIPT_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/main/setup.sh"

# Function to check internet connectivity
check_internet() {
    log_step "Checking internet connectivity..."
    if ! curl -s --head https://github.com | head -n 1 | grep -q "HTTP"; then
        log_error "No internet connection. Please check your network."
        exit 1
    fi
    log_success "Internet connection verified"
}

# Function to download and verify script
download_script() {
    local url=$1
    local temp_script="/tmp/datagram-setup-$$.sh"
    
    log_step "Downloading setup script from TopWebsB/datagram-setup..."
    if curl -fsSL "$url" -o "$temp_script"; then
        log_success "Script downloaded successfully"
        echo "$temp_script"
    else
        log_error "Failed to download setup script"
        log_info "Please check:"
        log_info "1. Internet connection"
        log_info "2. Repository URL: https://github.com/$REPO_OWNER/$REPO_NAME"
        log_info "3. File exists: $url"
        exit 1
    fi
}

# Function to check system compatibility
check_system() {
    log_step "Checking system compatibility..."
    
    # Check if Ubuntu
    if [ ! -f /etc/os-release ]; then
        log_error "Unsupported operating system"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        log_warning "This script is optimized for Ubuntu. You're running $PRETTY_NAME"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" ]]; then
        log_warning "This script is optimized for x86_64 architecture. You're running $ARCH"
    fi
    
    log_success "System check passed: $PRETTY_NAME ($ARCH)"
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
    echo "Environment Variables:"
    echo "  DATAGRAM_LICENSE    Your Datagram license key"
    echo "  SKIP_DOCKER_INSTALL Skip Docker installation if already installed"
    echo
    echo "Examples:"
    echo "  # Basic deployment (will prompt for license key)"
    echo "  bash <(curl -s https://raw.githubusercontent.com/TopWebsB/datagram-setup/main/scripts/quick-deploy.sh)"
    echo
    echo "  # With pre-set license key"
    echo "  DATAGRAM_LICENSE=\"abc123...\" bash <(curl -s https://raw.githubusercontent.com/TopWebsB/datagram-setup/main/scripts/quick-deploy.sh)"
    echo
}

# Function to check for updates
check_updates() {
    log_step "Checking repository..."
    log_info "Using TopWebsB/datagram-setup - Automated Datagram Node Deployment"
}

# Function to validate script
validate_script() {
    local script_path=$1
    
    log_step "Validating setup script..."
    
    # Check if script exists and has content
    if [ ! -s "$script_path" ]; then
        log_error "Downloaded script is empty or missing"
        return 1
    fi
    
    # Check if script is executable
    chmod +x "$script_path"
    
    # Basic syntax check
    if ! bash -n "$script_path" 2>/dev/null; then
        log_error "Script syntax validation failed"
        return 1
    fi
    
    log_success "Script validation passed"
    return 0
}

# Function to run setup
run_setup() {
    local script_path=$1
    
    echo
    log_step "Starting automated Datagram node setup..."
    echo "================================================"
    
    # Check if license key is provided via environment
    if [ -n "$DATAGRAM_LICENSE" ]; then
        log_info "Using license key from environment variable"
    else
        log_warning "No license key provided via DATAGRAM_LICENSE environment variable"
        log_info "You will be prompted for your license key during setup"
    fi
    
    # Display what will be installed
    log_info "This setup will install:"
    echo "  • Docker and Docker Compose"
    echo "  • Essential system tools"
    echo "  • Firewall configuration"
    echo "  • Datagram node in Docker container"
    echo "  • Management and monitoring scripts"
    
    # Ask for confirmation
    echo
    read -p "Continue with setup? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Setup cancelled by user"
        exit 0
    fi
    
    # Execute the main setup script
    log_step "Executing main setup script..."
    echo "================================================"
    bash "$script_path"
}

# Function to provide post-install info
post_install_info() {
    echo
    log_success "Quick deploy completed!"
    echo
    log_info "Next steps:"
    echo "  1. Check node status: cd ~/datagram-node && ./status.sh"
    echo "  2. View logs: ./logs.sh"
    echo "  3. Monitor resources: docker stats"
    echo
    log_info "Management commands available in: ~/datagram-node/scripts/"
    echo
    log_info "Need help? Check: https://github.com/TopWebsB/datagram-setup"
    echo
}

# Main execution
main() {
    local temp_script
    
    # Trap to clean up temp files
    trap 'rm -f /tmp/datagram-setup-*.sh' EXIT
    
    # Check arguments
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Show repository info
    log_info "Repository: TopWebsB/datagram-setup"
    log_info "Description: Automated Datagram Node Deployment"
    
    # Initial checks
    check_internet
    check_system
    check_updates
    
    # Download script
    temp_script=$(download_script "$MAIN_SCRIPT_URL")
    
    # Validate script
    if ! validate_script "$temp_script"; then
        log_error "Script validation failed"
        exit 1
    fi
    
    # Run setup
    run_setup "$temp_script"
    
    # Post-install information
    post_install_info
    
    log_success "Deployment completed successfully! 🎉"
}

# Run main function with all arguments
main "$@"
