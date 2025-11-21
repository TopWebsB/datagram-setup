#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DATAGRAM_DIR="$HOME/datagram-node"
SCRIPT_DIR="$DATAGRAM_DIR/scripts"

# Logging functions
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "Please don't run this script as root. Use a regular user with sudo privileges."
    exit 1
fi

# Check sudo privileges
if ! sudo -n true 2>/dev/null; then
    log_error "This user doesn't have sudo privileges or password is required."
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Docker
install_docker() {
    log_info "Installing Docker..."
    
    if command_exists docker; then
        log_warning "Docker is already installed. Skipping Docker installation."
        return 0
    fi

    # Update package index
    sudo apt update

    # Install prerequisites
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add user to docker group
    sudo usermod -aG docker $USER

    log_success "Docker installed successfully"
}

# Function to configure firewall
configure_firewall() {
    log_info "Configuring firewall (UFW)..."
    
    if command_exists ufw; then
        if sudo ufw status | grep -q "active"; then
            log_warning "UFW is already active. Ensuring necessary ports are open..."
        else
            sudo ufw allow OpenSSH
            sudo ufw allow 80/tcp
            sudo ufw allow 443/tcp
            sudo ufw --force enable
            log_success "UFW configured and enabled"
        fi
    else
        log_warning "UFW not installed. Skipping firewall configuration."
    fi
}

# Function to install essential tools
install_essential_tools() {
    log_info "Installing essential tools..."
    
    sudo apt update
    sudo apt install -y \
        curl wget git htop \
        net-tools dnsutils traceroute nmap \
        lsof ncdu jq \
        tmux screen neovim
    
    log_success "Essential tools installed"
}

# Function to setup datagram directory structure
setup_directory_structure() {
    log_info "Setting up directory structure..."
    
    mkdir -p $DATAGRAM_DIR
    mkdir -p $SCRIPT_DIR
    mkdir -p $DATAGRAM_DIR/logs
    
    log_success "Directory structure created at $DATAGRAM_DIR"
}

# Function to create Dockerfile
create_dockerfile() {
    log_info "Creating Dockerfile..."
    
    cat > $DATAGRAM_DIR/Dockerfile << 'EOF'
FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and install Datagram
RUN curl -fsSL https://github.com/Datagram-Group/datagram-cli-release/releases/latest/download/datagram-cli-x86_64-linux \
    -o /usr/local/bin/datagram && \
    chmod +x /usr/local/bin/datagram

# Create application directory
RUN mkdir -p /app

# Set working directory
WORKDIR /app

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/datagram"]
EOF

    log_success "Dockerfile created"
}

# Function to create docker-compose.yml
create_docker_compose() {
    log_info "Creating docker-compose.yml..."
    
    cat > $DATAGRAM_DIR/docker-compose.yml << 'EOF'
version: '3.8'

services:
  datagram:
    build: .
    container_name: datagram-node
    restart: unless-stopped
    command: run -- -key ${DATAGRAM_LICENSE}
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    volumes:
      - datagram_data:/app
    healthcheck:
      test: ["CMD", "ps", "aux"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  datagram_data:
EOF

    log_success "docker-compose.yml created"
}

# Function to create environment file
create_env_file() {
    log_info "Setting up environment file..."
    
    if [ -z "$DATAGRAM_LICENSE" ]; then
        log_warning "DATAGRAM_LICENSE environment variable not set."
        echo
        read -p "Please enter your Datagram License Key: " LICENSE_KEY
        
        if [ -z "$LICENSE_KEY" ]; then
            log_error "No license key provided. Exiting."
            exit 1
        fi
        
        cat > $DATAGRAM_DIR/.env << EOF
DATAGRAM_LICENSE=$LICENSE_KEY
EOF
        log_success "Environment file created with provided license key"
    else
        cat > $DATAGRAM_DIR/.env << EOF
DATAGRAM_LICENSE=$DATAGRAM_LICENSE
EOF
        log_success "Environment file created with environment variable"
    fi
    
    # Secure the .env file
    chmod 600 $DATAGRAM_DIR/.env
}

# Function to create management scripts
create_management_scripts() {
    log_info "Creating management scripts..."
    
    # Status script
    cat > $SCRIPT_DIR/status.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "=== Datagram Container Status ==="

# Check if container is running
if docker compose ps | grep -q "Up"; then
    echo "✅ Container: RUNNING"
    
    # Check recent logs for connection status
    echo "=== Recent Logs (last 20 lines) ==="
    docker compose logs --tail=20 | grep -E "(connected|running|ready|error|fail|warning)" || echo "No significant status messages in recent logs"
    
    # Check container health
    echo "=== Container Details ==="
    docker ps --filter "name=datagram-node" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    echo "❌ Container: STOPPED or NOT RUNNING"
fi
EOF

    # Restart script
    cat > $SCRIPT_DIR/restart.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "Restarting Datagram container..."
docker compose restart

echo "Waiting for container to stabilize..."
sleep 5

# Show status after restart
./scripts/status.sh
EOF

    # Logs script
    cat > $SCRIPT_DIR/logs.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "Showing Datagram logs (Ctrl+C to exit):"
docker compose logs -f
EOF

    # Stop script
    cat > $SCRIPT_DIR/stop.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "Stopping Datagram container..."
docker compose down

echo "Current status:"
docker compose ps
EOF

    # Start script
    cat > $SCRIPT_DIR/start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "Starting Datagram container..."
docker compose up -d

echo "Waiting for startup..."
sleep 3

./scripts/status.sh
EOF

    # Update script
    cat > $SCRIPT_DIR/update.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "Updating Datagram container..."
docker compose down
docker compose build --no-cache
docker compose up -d

echo "Update completed. Current status:"
./scripts/status.sh
EOF

    # Make scripts executable
    chmod +x $SCRIPT_DIR/*.sh
    
    # Create symlinks in main directory for easy access
    for script in status restart logs stop start update; do
        ln -sf $SCRIPT_DIR/$script.sh $DATAGRAM_DIR/$script-datagram.sh
    done

    log_success "Management scripts created and made executable"
}

# Function to build and start Datagram
build_and_start_datagram() {
    log_info "Building and starting Datagram container..."
    
    cd $DATAGRAM_DIR
    
    # Build the image
    docker compose build
    
    # Start the service
    docker compose up -d
    
    log_success "Datagram container built and started"
}

# Function to display final information
display_final_info() {
    log_success "=== Setup Completed Successfully! ==="
    echo
    echo "📁 Installation directory: $DATAGRAM_DIR"
    echo "🔧 Management scripts available in: $SCRIPT_DIR"
    echo
    echo "🚀 Quick Start Commands:"
    echo "   cd $DATAGRAM_DIR"
    echo "   ./status-datagram.sh          # Check status"
    echo "   ./logs-datagram.sh            # View logs"
    echo "   ./restart-datagram.sh         # Restart service"
    echo "   ./stop-datagram.sh            # Stop service"
    echo "   ./start-datagram.sh           # Start service"
    echo "   ./update-datagram.sh          # Update container"
    echo
    echo "📊 Monitoring Commands:"
    echo "   docker ps                     # List all containers"
    echo "   docker stats                  # Container resource usage"
    echo "   docker compose logs -f        # Follow logs"
    echo
    echo "⚠️  Important Notes:"
    echo "   - Your license key is stored in: $DATAGRAM_DIR/.env"
    echo "   - Container data is stored in Docker volume: datagram_data"
    echo "   - Container will auto-restart on system reboot"
    echo "   - Logs are limited to 10MB per file, 3 files max"
    echo
    echo "To check if everything is working, run:"
    echo "  $DATAGRAM_DIR/scripts/status.sh"
}

# Main execution function
main() {
    echo
    log_info "Starting VPS Datagram Automated Setup..."
    echo "=============================================="
    
    # Part 1: Initial Server Setup & Docker Installation
    log_info "=== PART 1: Server Setup & Docker Installation ==="
    install_essential_tools
    install_docker
    configure_firewall
    
    # Part 2: Dockerized Datagram Setup
    log_info "=== PART 2: Dockerized Datagram Setup ==="
    setup_directory_structure
    create_dockerfile
    create_docker_compose
    create_env_file
    create_management_scripts
    
    # Part 3: Build and Run Datagram
    log_info "=== PART 3: Build and Run Datagram ==="
    build_and_start_datagram
    
    # Display final information
    display_final_info
    
    log_success "Setup completed! You may need to logout and login again for Docker group changes to take effect."
}

# Run main function
main "$@"
