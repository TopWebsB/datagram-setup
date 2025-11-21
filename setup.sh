#!/bin/bash
set -e

echo "================================================"
echo "DATAGRAM NODE SETUP"
echo "================================================"

# Configuration
DATAGRAM_DIR="$HOME/datagram-node"
SCRIPT_DIR="$DATAGRAM_DIR/scripts"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "[ERROR] Please don't run this script as root. Use a regular user with sudo privileges."
    exit 1
fi

# Check sudo privileges
if ! sudo -n true 2>/dev/null; then
    echo "[ERROR] This user doesn't have sudo privileges or password is required."
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Docker
install_docker() {
    echo "[INFO] Installing Docker..."
    
    if command_exists docker; then
        echo "[INFO] Docker is already installed. Skipping Docker installation."
        return 0
    fi

    # Update package index
    sudo apt update -y

    # Install prerequisites
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    sudo apt update -y
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add user to docker group
    sudo usermod -aG docker "$USER"

    echo "[SUCCESS] Docker installed successfully"
}

# Function to install essential tools
install_essential_tools() {
    echo "[INFO] Installing essential tools..."
    
    sudo apt update -y
    sudo apt install -y \
        curl wget git htop \
        net-tools dnsutils \
        lsof jq
    
    echo "[SUCCESS] Essential tools installed"
}

# Function to setup datagram directory structure
setup_directory_structure() {
    echo "[INFO] Setting up directory structure..."
    
    mkdir -p "$DATAGRAM_DIR"
    mkdir -p "$SCRIPT_DIR"
    
    echo "[SUCCESS] Directory structure created at $DATAGRAM_DIR"
}

# Function to create Dockerfile
create_dockerfile() {
    echo "[INFO] Creating Dockerfile..."
    
    cat > "$DATAGRAM_DIR/Dockerfile" << 'EOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://github.com/Datagram-Group/datagram-cli-release/releases/latest/download/datagram-cli-x86_64-linux \
    -o /usr/local/bin/datagram && \
    chmod +x /usr/local/bin/datagram

RUN mkdir -p /app
WORKDIR /app

ENTRYPOINT ["/usr/local/bin/datagram"]
EOF

    echo "[SUCCESS] Dockerfile created"
}

# Function to create docker-compose.yml
create_docker_compose() {
    echo "[INFO] Creating docker-compose.yml..."
    
    cat > "$DATAGRAM_DIR/docker-compose.yml" << 'EOF'
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

volumes:
  datagram_data:
EOF

    echo "[SUCCESS] docker-compose.yml created"
}

# Function to create environment file
create_env_file() {
    echo "[INFO] Setting up environment file..."
    
    if [ -z "$DATAGRAM_LICENSE" ]; then
        echo "[INFO] Please enter your Datagram License Key"
        read -p "License Key: " LICENSE_KEY
        
        if [ -z "$LICENSE_KEY" ]; then
            echo "[ERROR] No license key provided. Exiting."
            exit 1
        fi
        
        cat > "$DATAGRAM_DIR/.env" << EOF
DATAGRAM_LICENSE=$LICENSE_KEY
EOF
        echo "[SUCCESS] Environment file created with provided license key"
    else
        cat > "$DATAGRAM_DIR/.env" << EOF
DATAGRAM_LICENSE=$DATAGRAM_LICENSE
EOF
        echo "[SUCCESS] Environment file created with environment variable"
    fi
    
    # Secure the .env file
    chmod 600 "$DATAGRAM_DIR/.env"
}

# Function to create management scripts
create_management_scripts() {
    echo "[INFO] Creating management scripts..."
    
    # Status script
    cat > "$SCRIPT_DIR/status.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "=== Datagram Container Status ==="

if docker compose ps | grep -q "Up"; then
    echo "✅ Container: RUNNING"
    echo "=== Recent Logs ==="
    docker compose logs --tail=10
else
    echo "❌ Container: STOPPED or NOT RUNNING"
fi
EOF

    # Restart script
    cat > "$SCRIPT_DIR/restart.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "Restarting Datagram container..."
docker compose restart
echo "✅ Datagram service restarted"
EOF

    # Logs script
    cat > "$SCRIPT_DIR/logs.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "Showing Datagram logs (Ctrl+C to exit):"
docker compose logs -f
EOF

    # Start script
    cat > "$SCRIPT_DIR/start.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "Starting Datagram container..."
docker compose up -d
echo "✅ Datagram service started"
EOF

    # Stop script
    cat > "$SCRIPT_DIR/stop.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "Stopping Datagram container..."
docker compose down
echo "✅ Datagram service stopped"
EOF

    # Make scripts executable
    chmod +x "$SCRIPT_DIR"/*.sh
    
    echo "[SUCCESS] Management scripts created"
}

# Function to build and start Datagram
build_and_start_datagram() {
    echo "[INFO] Building and starting Datagram container..."
    
    cd "$DATAGRAM_DIR"
    
    # Build the image
    docker compose build
    
    # Start the service
    docker compose up -d
    
    echo "[SUCCESS] Datagram container built and started"
}

# Function to display final information
display_final_info() {
    echo
    echo "[SUCCESS] === Setup Completed Successfully! ==="
    echo
    echo "Installation directory: $DATAGRAM_DIR"
    echo "Management scripts: $SCRIPT_DIR"
    echo
    echo "Quick commands:"
    echo "  cd $DATAGRAM_DIR"
    echo "  ./scripts/status.sh    # Check status"
    echo "  ./scripts/logs.sh      # View logs"
    echo "  ./scripts/restart.sh   # Restart service"
    echo "  ./scripts/start.sh     # Start service"
    echo "  ./scripts/stop.sh      # Stop service"
    echo
    echo "Important: You may need to logout and login again for Docker group changes to take effect."
    echo "Or run: newgrp docker"
    echo
}

# Main execution function
main() {
    echo
    echo "[INFO] Starting VPS Datagram Automated Setup..."
    echo "=============================================="
    
    # Part 1: Initial Server Setup & Docker Installation
    echo "[INFO] === PART 1: Server Setup & Docker Installation ==="
    install_essential_tools
    install_docker
    
    # Part 2: Dockerized Datagram Setup
    echo "[INFO] === PART 2: Dockerized Datagram Setup ==="
    setup_directory_structure
    create_dockerfile
    create_docker_compose
    create_env_file
    create_management_scripts
    
    # Part 3: Build and Run Datagram
    echo "[INFO] === PART 3: Build and Run Datagram ==="
    build_and_start_datagram
    
    # Display final information
    display_final_info
}

# Run main function
main "$@"
