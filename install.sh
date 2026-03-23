#!/bin/bash

# Docker Aptly Repository Server Installation Script
# This script automates the setup of the Aptly repository server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]] && [[ ! "$OSTYPE" == "darwin"* ]]; then
        log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_warn "Docker not found. Installing Docker..."
        install_docker
    else
        log_info "Docker is already installed."
    fi
    
    # Check if user is in docker group
    if ! groups $(whoami) | grep -q docker; then
        log_warn "User not in docker group. Adding user to docker group..."
        sudo usermod -aG docker $(whoami)
        log_info "Please logout and login again to apply group changes, then run this script again."
        exit 0
    fi
}

# Install Docker
install_docker() {
    # Detect OS
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        sudo apt update
        sudo apt install -y docker.io docker-compose
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL/Fedora
        sudo yum install -y docker docker-compose
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        log_error "macOS detected. Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
        log_info "After installing Docker Desktop, please re-run this script."
        exit 1
    else
        log_error "Unsupported OS. Please install Docker manually."
        log_info "Visit https://docs.docker.com/get-docker/ for installation instructions."
        exit 1
    fi
    
    # Enable and start Docker (skip on macOS)
    if [[ ! "$OSTYPE" == "darwin"* ]]; then
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
}

# Create required directories
create_directories() {
    log_info "Creating required directories..."
    sudo mkdir -p /data/forterra/jammy /data/forterra/focal /data/published /data/aptly /data/gpg
    sudo chown -R $(id -u):$(id -g) /data
    log_info "Directories created successfully."
}

# Configure firewall
configure_firewall() {
    log_info "Configuring firewall..."
    
    # Check for ufw (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        sudo ufw allow 80/tcp
        log_info "UFW configured to allow HTTP traffic."
    # Check for firewalld (CentOS/RHEL)
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --reload
        log_info "Firewalld configured to allow HTTP traffic."
    else
        log_warn "No supported firewall detected. Please configure your firewall manually to allow port 80."
    fi
}

# Build and start Docker containers
deploy_service() {
    log_info "Building and starting Docker containers..."
    docker-compose build
    docker-compose up -d
    log_info "Docker containers started successfully."
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Wait a moment for containers to start
    sleep 5
    
    # Check if service is running
    if curl -s http://localhost/health | grep -q "OK"; then
        log_info "Installation verified successfully! Service is running."
    else
        log_warn "Service may still be starting. Please check status with: docker-compose ps"
    fi
}

# Main installation function
main() {
    log_info "Starting Docker Aptly Repository Server Installation..."
    
    check_root
    check_docker
    create_directories
    configure_firewall
    deploy_service
    verify_installation
    
    log_info "Installation completed! Please note:"
    echo "  - Place your .deb files in /data/forterra/jammy/ or /data/forterra/focal/"
    echo "  - Run 'docker-compose exec aptly-repo update-snapshots.sh' to process packages"
    echo "  - Access your repository at http://YOUR_SERVER_IP/"
    echo "  - See README.md for detailed usage instructions"
}

# Run main function
main "$@"