#!/usr/bin/env bash
# Docker Management Suite - One-Click Production Environment
# Version: 2.0.0
# Author: centopw
# Source: https://github.com/centopw/dockmate
# Installation: 

set -eo pipefail
[ -n "$DEBUG" ] && set -x

# ==============================================================================
# Configuration
# ==============================================================================
SCRIPT_NAME="${0##*/}"
LOG_FILE="/var/log/${SCRIPT_NAME%.*}.log"
CONFIG_FILE="/etc/dockmate.conf"
DOCKER_VERSION="24.0.9"
COMPOSE_VERSION="v2.27.1"
BACKUP_DIR="/var/backups/docker"

# ANSI Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# ==============================================================================
# Initialization Checks
# ==============================================================================
init_checks() {
  [ "$(id -u)" -eq 0 ] || die "Root privileges required"
  [ -f "$CONFIG_FILE" ] || generate_config
  source "$CONFIG_FILE"
  setup_logging
  check_os_support
  install_dependencies
}

# ==============================================================================
# Core Functions
# ==============================================================================
install_docker() {
  log "Installing Docker $DOCKER_VERSION"
  case "$OS_ID" in
    ubuntu|debian) curl -fsSL https://get.docker.com | sh -s -- --version "$DOCKER_VERSION" ;;
    centos|fedora) yum install -y "docker-ce-$DOCKER_VERSION" ;;
  esac
  systemctl enable --now docker
}

install_compose() {
  log "Installing Docker Compose $COMPOSE_VERSION"
  compose_plugin="/usr/libexec/docker/cli-plugins/docker-compose"
  mkdir -p "${compose_plugin%/*}"
  curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" \
    -o "$compose_plugin"
  chmod +x "$compose_plugin"
}

secure_docker() {
  log "Applying security hardening"
  [ ! -f /etc/docker/daemon.json ] && echo '{}' > /etc/docker/daemon.json
  jq '. += {
    "userns-remap": "default",
    "no-new-privileges": true,
    "log-driver": "json-file",
    "log-opts": {"max-size": "10m", "max-file": "3"}
  }' /etc/docker/daemon.json > tmp.json && mv tmp.json /etc/docker/daemon.json
  systemctl restart docker
}

# ==============================================================================
# Advanced Features
# ==============================================================================
backup_environment() {
  local backup_path="$BACKUP_DIR/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup_path"
  
  log "Backing up Docker environment to $backup_path"
  docker ps -aq | xargs docker inspect > "$backup_path/containers.json"
  docker volume ls -q | xargs -I{} sh -c "docker run --rm -v {}:/volume busybox tar cf - /volume > $backup_path/{}.tar"
  docker image save -o "$backup_path/images.tar" $(docker images -q)
}

manage_swarm() {
  case "$1" in
    init) docker swarm init --advertise-addr $(hostname -I | awk '{print $1}') ;;
    join) docker swarm join --token $2 $3 ;;
  esac
}

# ==============================================================================
# Main Interface
# ==============================================================================
show_menu() {
  clear
  echo -e "${BLUE}Docker Management Suite${NC}"
  echo "1. Full Installation (Docker + Compose + Security)"
  echo "2. Update Components"
  echo "3. Backup Environment"
  echo "4. Restore Environment"
  echo "5. Swarm Cluster Setup"
  echo "6. Health Check"
  echo "7. Uninstall"
  echo "8. Exit"
}

process_choice() {
  case $1 in
    1) install_docker; install_compose; secure_docker ;;
    2) update_components ;;
    3) backup_environment ;;
    4) restore_environment ;;
    5) swarm_operations ;;
    6) health_check ;;
    7) uninstall ;;
    8) exit 0 ;;
    *) echo -e "${RED}Invalid option${NC}" ;;
  esac
}

# ==============================================================================
# Execution Flow
# ==============================================================================
main() {
  init_checks
  while true; do
    show_menu
    read -p "Select operation: " choice
    process_choice "$choice"
    read -p "Press Enter to continue..."
  done
}

# ==============================================================================
# One-Click Installation & Execution
# ==============================================================================
if [ "$0" = "bash" ]; then
  log "Starting installation from remote source"
  export DEBIAN_FRONTEND=noninteractive
  [ ! -f "/usr/bin/dockmate" ] && \
    curl -o /usr/bin/dockmate https://raw.githubusercontent.com/yourrepo/dockmate/main/dockmate.sh && \
    chmod +x /usr/bin/dockmate
  dockmate "$@"
else
  main "$@"
fi
