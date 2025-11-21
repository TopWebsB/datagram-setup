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
██╗    ██╗███████╗██████╗ ███████╗
██║    ██║██╔════╝██╔══██╗██╔════╝
██║ █╗ ██║█████╗  ██████╔╝███████╗
██║███╗██║██╔══╝  ██╔══██╗╚════██║
╚███╔███╔╝███████╗██║  ██║███████║
 ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝╚══════╝
                                   
 ██████╗  █████╗ ████████╗ █████╗  ██████╗ ██████╗  █████╗ ███╗   ███╗
██╔═══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔════╝██╔══██╗██╔══██╗████╗ ████║
██║   ██║███████║   ██║   ███████║██║     ██████╔╝███████║██╔████╔██║
██║   ██║██╔══██║   ██║   ██╔══██║██║     ██╔══██╗██╔══██║██║╚██╔╝██║
╚██████╔╝██║  ██║   ██║   ██║  ██║╚██████╗██║  ██║██║  ██║██║ ╚═╝ ██║
 ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝
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
FALLBACK_SCRIPT_URL="https://raw.githubusercontent.com/TopWebsB/datagram-setup/main/scripts/fallback-setup.sh"

# Function to create fallback setup
create_fallback_setup() {
    log_warning "Main setup script not found. Creating fallback setup..."
    
    cat > /tmp/datagram-fallback-setup.sh << 'EOF'
#!/bin/bash
echo "Fallback Datagram Setup"
echo "======================"
echo "This is a temporary fallback script."
echo "Please check if setup.sh exists in the main repository."
echo "Visit: https://github.com/TopWebsB/datagram-setup"
EOF
    
    chmod +x /tmp/datagram-fallback-setup.sh
    echo "/tmp/datagram-fallback-setup.sh"
}

# Function to download and verify script
download_script() {
    local url=$1
    local description=$2
    local temp_script="/tmp/datagram-setup-$$.sh"
    
    log_step "Downloading $description..."
    if curl -fsSL "$url" -o "$temp_script" && [ -s "$temp_script" ]; then
        log_success "$description downloaded successfully"
        echo "$temp_script"
    else
        log_warning "Failed to download $description"
        return 1
    fi
}

# Main execution
main() {
    local temp_script
    
    # Trap to clean up temp files
    trap 'rm -f /tmp/datagram-setup-*.sh' EXIT
    
    # Download main script
    temp_script=$(download_script "$MAIN_SCRIPT_URL" "main setup script") || {
        log_error "Main setup script not found in repository."
        echo
        log_info "To fix this, make sure 'setup.sh' exists in the root of your repository:"
        log_info "https://github.com/TopWebsB/datagram-setup"
        echo
        log_info "For now, you can run the manual setup:"
        echo "  git clone https://github.com/TopWebsB/datagram-setup.git"
        echo "  cd datagram-setup"
        echo "  ./setup.sh"
        exit 1
    }
    
    # Validate script
    log_step "Validating setup script..."
    chmod +x "$temp_script"
    if bash -n "$temp_script" 2>/dev/null; then
        log_success "Script validation passed"
    else
        log_error "Script validation failed"
        exit 1
    fi
    
    # Execute the script
    log_step "Starting Datagram setup..."
    echo "================================================"
    bash "$temp_script"
}

# Run main function
main "$@"
