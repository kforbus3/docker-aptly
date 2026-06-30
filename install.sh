#!/bin/bash

# Docker Aptly Repository Server - installation helper.
# Sets up directories and brings the stack up with Docker Compose.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Resolve the Docker Compose command (v2 plugin preferred, v1 fallback).
COMPOSE=""
detect_compose() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE="docker-compose"
    fi
}

# Check that we are not running as root on Linux (Docker should run rootless or
# via the docker group); allow root on macOS where it is harmless.
check_root() {
    if [[ $EUID -eq 0 ]] && [[ ! "$OSTYPE" == "darwin"* ]]; then
        log_error "Do not run this script as root. Run as a regular user with Docker access."
        exit 1
    fi
}

# Install Docker if it is missing (Linux only).
install_docker() {
    if [ -f /etc/debian_version ]; then
        sudo apt update
        sudo apt install -y docker.io docker-compose-plugin
    elif [ -f /etc/redhat-release ]; then
        sudo yum install -y docker docker-compose-plugin
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        log_error "macOS detected. Install Docker Desktop from https://www.docker.com/products/docker-desktop and re-run."
        exit 1
    else
        log_error "Unsupported OS. Install Docker manually: https://docs.docker.com/get-docker/"
        exit 1
    fi
    if [[ ! "$OSTYPE" == "darwin"* ]]; then
        sudo systemctl enable --now docker
    fi
}

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log_warn "Docker not found. Installing Docker..."
        install_docker
    else
        log_info "Docker is already installed."
    fi

    detect_compose
    if [ -z "$COMPOSE" ]; then
        log_warn "Docker Compose not found. Installing the compose plugin..."
        install_docker
        detect_compose
    fi
    if [ -z "$COMPOSE" ]; then
        log_error "Could not find Docker Compose. Install it and re-run."
        exit 1
    fi
    log_info "Using compose command: $COMPOSE"

    # On Linux, make sure the user can talk to the Docker daemon.
    if [[ ! "$OSTYPE" == "darwin"* ]] && ! docker info >/dev/null 2>&1; then
        if ! groups "$(whoami)" | grep -q docker; then
            log_warn "Adding $(whoami) to the docker group..."
            sudo usermod -aG docker "$(whoami)"
            log_info "Log out and back in (or run 'newgrp docker'), then re-run this script."
            exit 0
        fi
    fi
}

create_directories() {
    log_info "Creating data directories under ./data ..."
    mkdir -p ./data/packages/dist1 ./data/packages/dist2 ./data/aptly/public ./data/gpg
    log_info "Directories created."
}

configure_firewall() {
    # Best-effort: open HTTP if a known firewall is present.
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow 80/tcp && log_info "UFW: allowed HTTP (port 80)."
    elif command -v firewall-cmd >/dev/null 2>&1; then
        sudo firewall-cmd --permanent --add-service=http && sudo firewall-cmd --reload
        log_info "firewalld: allowed HTTP."
    else
        log_warn "No supported firewall detected. Open port 80 manually if needed."
    fi
}

deploy_service() {
    log_info "Building and starting the container..."
    $COMPOSE build
    $COMPOSE up -d
    log_info "Container started."
}

verify_installation() {
    log_info "Verifying installation..."
    sleep 5
    if curl -fsS http://localhost/health 2>/dev/null | grep -q "OK"; then
        log_info "Service is healthy."
    else
        log_warn "Service may still be starting. Check with: $COMPOSE ps"
    fi
}

main() {
    log_info "Starting Docker Aptly Repository Server installation..."
    check_root
    check_docker
    create_directories
    [[ "$OSTYPE" == "darwin"* ]] || configure_firewall
    deploy_service
    verify_installation

    echo ""
    log_info "Installation complete. Next steps:"
    echo "  - Drop .deb files into ./data/packages/dist1/ (or dist2/)"
    echo "  - Publish them:  $COMPOSE exec aptly-repo update-snapshots.sh"
    echo "  - Browse the repo at http://YOUR_SERVER_IP/"
    echo "  - GPG public key at http://YOUR_SERVER_IP/gpg/public.key"
    echo "  - See README.md for client setup and full usage."
}

main "$@"
