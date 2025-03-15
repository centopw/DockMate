#!/bin/bash

#######################################################
#                                                     #
#   ____             _    __  __       _              #
#  |  _ \  ___   ___| | _|  \/  | __ _| |_ ___        #
#  | | | |/ _ \ / __| |/ / |\/| |/ _` | __/ _ \       #
#  | |_| | (_) | (__|   <| |  | | (_| | ||  __/       #
#  |____/ \___/ \___|_|\_\_|  |_|\__,_|\__\___|       #
#                                                     #
#  Docker & Docker Compose Management Tool            #
#  By Centopw - Enhanced Version                      #
#                                                     #
#######################################################

# DockMate v2.0.0 - A comprehensive Docker and Docker Compose management tool
# Source code: https://github.com/centopw/DockMate
# License: MIT

# ============================================================================
# CONFIGURATION
# ============================================================================

# Script version
VERSION="2.0.0"

# Latest stable Docker Compose version
DEFAULT_COMPOSE_VERSION="v2.25.0"

# Log file
LOG_FILE="/tmp/dockmate_$(date +%Y%m%d%H%M%S).log"

# ============================================================================
# ANSI COLOR CODES
# ============================================================================

# Text colors
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

# Bold text colors
BOLD_BLACK='\033[1;30m'
BOLD_RED='\033[1;31m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_BLUE='\033[1;34m'
BOLD_MAGENTA='\033[1;35m'
BOLD_CYAN='\033[1;36m'
BOLD_WHITE='\033[1;37m'

# Background colors
BG_BLACK='\033[40m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'
BG_MAGENTA='\033[45m'
BG_CYAN='\033[46m'
BG_WHITE='\033[47m'

# Special formatting
UNDERLINE='\033[4m'
NC='\033[0m' # No Color/Reset

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Clear screen
clear_screen() {
    clear
}

# Log messages to file and optionally display
log() {
    local level="$1"
    local message="$2"
    local display="$3"
    
    # Add timestamp to log
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Write to log file
    echo -e "[$timestamp][$level] $message" >> "$LOG_FILE"
    
    # Display message if requested
    if [ "$display" = true ]; then
        case "$level" in
            "INFO")
                echo -e "${BOLD_BLUE}[INFO]${NC} $message"
                ;;
            "SUCCESS")
                echo -e "${BOLD_GREEN}[SUCCESS]${NC} $message"
                ;;
            "WARNING")
                echo -e "${BOLD_YELLOW}[WARNING]${NC} $message"
                ;;
            "ERROR")
                echo -e "${BOLD_RED}[ERROR]${NC} $message"
                ;;
            *)
                echo -e "$message"
                ;;
        esac
    fi
}

# Check if script is run as root or with sudo
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "ERROR" "This script must be run as root or with sudo privileges." true
        exit 1
    fi
}

# Function to check required commands
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log "ERROR" "Required command '$cmd' not found." true
        return 1
    fi
    return 0
}

# Function to detect operating system
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS="$ID"
        VERSION="$VERSION_ID"
        
        # Group similar distributions
        case "$OS" in
            ubuntu|debian|linuxmint|pop|elementary|zorin)
                OS_FAMILY="debian"
                PACKAGE_MANAGER="apt"
                ;;
            centos|rhel|fedora|rocky|almalinux|ol)
                OS_FAMILY="rhel"
                PACKAGE_MANAGER="dnf"
                # Use yum for older CentOS/RHEL
                if [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
                    if [ "${VERSION_ID%%.*}" -lt 8 ]; then
                        PACKAGE_MANAGER="yum"
                    fi
                fi
                ;;
            opensuse*|sles)
                OS_FAMILY="suse"
                PACKAGE_MANAGER="zypper"
                ;;
            alpine)
                OS_FAMILY="alpine"
                PACKAGE_MANAGER="apk"
                ;;
            arch|manjaro|endeavouros)
                OS_FAMILY="arch"
                PACKAGE_MANAGER="pacman"
                ;;
            *)
                OS_FAMILY="unknown"
                PACKAGE_MANAGER="unknown"
                ;;
        esac
        
        log "INFO" "Detected OS: $OS ($OS_FAMILY), Version: $VERSION, Package Manager: $PACKAGE_MANAGER" true
        return 0
    else
        log "ERROR" "Cannot detect operating system." true
        return 1
    fi
}

# Function to handle error messages
handle_error() {
    local exit_code=$1
    local error_message=$2
    
    if [ $exit_code -ne 0 ]; then
        log "ERROR" "$error_message (Exit code: $exit_code)" true
        return 1
    fi
    return 0
}

# Function to show progress bar
show_progress() {
    local duration=$1
    local message="${2:-Processing...}"
    local width=50
    local i=0

    # Calculate the increment per step
    local increment=$(( 100 / duration ))
    
    # Print message first
    echo -ne "${message} ["
    
    # Show progress bar
    while [ $i -lt $duration ]; do
        local progress=$(( i * increment ))
        local completed=$(( progress * width / 100 ))
        local remaining=$(( width - completed ))
        
        # Create the progress bar string
        local bar=$(printf "%${completed}s" | tr ' ' '#')
        local space=$(printf "%${remaining}s")
        
        # Print the progress bar
        echo -ne "\r${message} [${bar}${space}] ${progress}%"
        
        # Sleep for a short time
        sleep 1
        
        # Increment counter
        ((i++))
    done
    
    # Complete the progress bar
    echo -ne "\r${message} ["
    printf "%${width}s" | tr ' ' '#'
    echo -e "] 100%"
}

# Function to prompt user for confirmation
confirm() {
    local message="$1"
    local default="${2:-y}" # Default to yes
    
    if [ "$default" = "y" ]; then
        options="[Y/n]"
    else
        options="[y/N]"
    fi
    
    read -r -p "$message $options " response
    response=${response,,} # Convert to lowercase
    
    if [ -z "$response" ]; then
        response="$default"
    fi
    
    if [[ "$response" =~ ^(yes|y)$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to display menu and get user choice
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    local i=0
    local choice
    
    # Print menu header
    echo -e "\n${BOLD_WHITE}==== $title ====${NC}\n"
    
    # Print menu options
    while [ $i -lt $count ]; do
        echo -e "${BOLD_CYAN}$(($i+1))${NC}) ${options[$i]}"
        ((i++))
    done
    
    # Get user choice
    echo
    read -r -p "Enter your choice [1-$count]: " choice
    
    # Validate choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
        return "$choice"
    else
        log "ERROR" "Invalid choice. Please enter a number between 1 and $count." true
        return 0
    fi
}

# Function to display a header
show_header() {
    local width=70
    local text="$1"
    local padding=$(( (width - ${#text} - 2) / 2 ))
    
    # Print top border
    printf "${BOLD_BLUE}+"
    printf "%${width}s" | tr ' ' '-'
    printf "+${NC}\n"
    
    # Print title
    printf "${BOLD_BLUE}|%${padding}s${BOLD_CYAN} $text ${BOLD_BLUE}%${padding}s|${NC}\n"
    
    # Print bottom border
    printf "${BOLD_BLUE}+"
    printf "%${width}s" | tr ' ' '-'
    printf "+${NC}\n"
}

# ============================================================================
# DOCKER FUNCTIONS
# ============================================================================

# Function to detect Docker version
detect_docker_version() {
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oP 'Docker version \K[^,]+')
        DOCKER_INSTALLED=true
        log "INFO" "Docker version: $DOCKER_VERSION" true
    else
        DOCKER_INSTALLED=false
        log "INFO" "Docker is not installed" true
    fi
}

# Function to detect Docker Compose version
detect_docker_compose_version() {
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_VERSION_OLD=$(docker-compose --version 2>/dev/null | grep -oP 'version \K[^,]+')
        DOCKER_COMPOSE_INSTALLED="classic"
        log "INFO" "Docker Compose (classic) version: $DOCKER_COMPOSE_VERSION_OLD" true
    elif docker compose version &> /dev/null; then
        DOCKER_COMPOSE_VERSION_NEW=$(docker compose version 2>/dev/null | grep -oP 'Docker Compose version \K[^,]+')
        DOCKER_COMPOSE_INSTALLED="plugin"
        log "INFO" "Docker Compose (plugin) version: $DOCKER_COMPOSE_VERSION_NEW" true
    else
        DOCKER_COMPOSE_INSTALLED=false
        log "INFO" "Docker Compose is not installed" true
    fi
}

# Function to check Docker status
check_docker_status() {
    if [ "$DOCKER_INSTALLED" = true ]; then
        if systemctl is-active --quiet docker; then
            DOCKER_STATUS="running"
            log "INFO" "Docker status: ${GREEN}Running${NC}" true
        else
            DOCKER_STATUS="stopped"
            log "INFO" "Docker status: ${RED}Stopped${NC}" true
        fi
    else
        DOCKER_STATUS="not_installed"
        log "INFO" "Docker status: ${YELLOW}Not installed${NC}" true
    fi
}

# Function to start Docker service
start_docker_service() {
    log "INFO" "Starting Docker service..." true
    if systemctl start docker; then
        log "SUCCESS" "Docker service started successfully" true
        return 0
    else
        log "ERROR" "Failed to start Docker service" true
        return 1
    fi
}

# Function to stop Docker service
stop_docker_service() {
    log "INFO" "Stopping Docker service..." true
    if systemctl stop docker; then
        log "SUCCESS" "Docker service stopped successfully" true
        return 0
    else
        log "ERROR" "Failed to stop Docker service" true
        return 1
    fi
}

# Function to restart Docker service
restart_docker_service() {
    log "INFO" "Restarting Docker service..." true
    if systemctl restart docker; then
        log "SUCCESS" "Docker service restarted successfully" true
        return 0
    else
        log "ERROR" "Failed to restart Docker service" true
        return 1
    fi
}

# Function to check Docker system info
check_docker_info() {
    if [ "$DOCKER_INSTALLED" = true ] && [ "$DOCKER_STATUS" = "running" ]; then
        log "INFO" "Docker System Information:" true
        docker info | grep -E "Server Version|Storage Driver|Logging Driver|Cgroup Driver|Kernel Version|Operating System|Architecture|CPUs|Total Memory"
        echo
        log "INFO" "Docker Resources Usage:" true
        docker system df
    else
        log "ERROR" "Docker is not installed or not running" true
    fi
}

# Function to install Docker
install_docker() {
    log "INFO" "Installing Docker..." true
    
    # Check if Docker is already installed
    if [ "$DOCKER_INSTALLED" = true ]; then
        log "WARNING" "Docker is already installed (Version: $DOCKER_VERSION)" true
        if confirm "Do you want to reinstall Docker?"; then
            remove_docker
        else
            return 0
        fi
    fi
    
    # Install Docker based on OS family
    case "$OS_FAMILY" in
        debian)
            log "INFO" "Installing Docker on Debian-based system..." true
            
            # Install dependencies
            apt-get update
            apt-get install -y ca-certificates curl gnupg lsb-release
            
            # Add Docker's official GPG key
            mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Set up the repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | \
                tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker Engine
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
            
        rhel)
            log "INFO" "Installing Docker on RHEL-based system..." true
            
            # Install dependencies
            $PACKAGE_MANAGER install -y yum-utils device-mapper-persistent-data lvm2
            
            # Add Docker repository
            yum-config-manager --add-repo https://download.docker.com/linux/$OS/docker-ce.repo
            
            # Install Docker Engine
            $PACKAGE_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
            
        arch)
            log "INFO" "Installing Docker on Arch-based system..." true
            $PACKAGE_MANAGER -Sy docker docker-compose
            ;;
            
        alpine)
            log "INFO" "Installing Docker on Alpine Linux..." true
            $PACKAGE_MANAGER add docker docker-compose
            rc-update add docker boot
            ;;
            
        suse)
            log "INFO" "Installing Docker on SUSE-based system..." true
            $PACKAGE_MANAGER install -y docker docker-compose
            ;;
            
        *)
            log "INFO" "Using generic Docker installation method..." true
            curl -fsSL https://get.docker.com -o install-docker.sh
            sh install-docker.sh
            ;;
    esac
    
    # Check if Docker was installed successfully
    if command -v docker &> /dev/null; then
        # Start Docker service
        systemctl start docker
        systemctl enable docker
        
        # Update Docker installation status
        detect_docker_version
        
        log "SUCCESS" "Docker installed successfully (Version: $DOCKER_VERSION)" true
        return 0
    else
        log "ERROR" "Docker installation failed" true
        return 1
    fi
}

# Function to remove Docker
remove_docker() {
    log "INFO" "Removing Docker..." true
    
    # Check if Docker is installed
    if [ "$DOCKER_INSTALLED" = false ]; then
        log "WARNING" "Docker is not installed" true
        return 0
    fi
    
    # Confirm before removing
    if ! confirm "Are you sure you want to remove Docker? This will delete all containers, images, volumes, and networks."; then
        log "INFO" "Docker removal canceled" true
        return 0
    fi
    
    # Stop Docker service
    systemctl stop docker
    
    # Remove Docker based on OS family
    case "$OS_FAMILY" in
        debian)
            log "INFO" "Removing Docker from Debian-based system..." true
            apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            apt-get autoremove -y
            ;;
            
        rhel)
            log "INFO" "Removing Docker from RHEL-based system..." true
            $PACKAGE_MANAGER remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
            
        arch)
            log "INFO" "Removing Docker from Arch-based system..." true
            $PACKAGE_MANAGER -Rs docker docker-compose
            ;;
            
        alpine)
            log "INFO" "Removing Docker from Alpine Linux..." true
            rc-update del docker boot
            $PACKAGE_MANAGER del docker docker-compose
            ;;
            
        suse)
            log "INFO" "Removing Docker from SUSE-based system..." true
            $PACKAGE_MANAGER remove -y docker docker-compose
            ;;
            
        *)
            log "INFO" "Using generic Docker removal method..." true
            apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            yum remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
    esac
    
    # Remove Docker data
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    
    log "SUCCESS" "Docker removed successfully" true
    
    # Update Docker installation status
    DOCKER_INSTALLED=false
    DOCKER_STATUS="not_installed"
    
    return 0
}

# Function to install Docker Compose
install_docker_compose() {
    log "INFO" "Installing Docker Compose..." true
    
    # Check if Docker Compose is already installed
    if [ "$DOCKER_COMPOSE_INSTALLED" != false ]; then
        if [ "$DOCKER_COMPOSE_INSTALLED" = "classic" ]; then
            CURRENT_VERSION="$DOCKER_COMPOSE_VERSION_OLD (classic)"
        else
            CURRENT_VERSION="$DOCKER_COMPOSE_VERSION_NEW (plugin)"
        fi
        
        log "WARNING" "Docker Compose is already installed (Version: $CURRENT_VERSION)" true
        if confirm "Do you want to reinstall Docker Compose?"; then
            remove_docker_compose
        else
            return 0
        fi
    fi
    
    # Check if Docker is installed first
    if [ "$DOCKER_INSTALLED" = false ]; then
        log "WARNING" "Docker is not installed. Docker Compose requires Docker." true
        if confirm "Do you want to install Docker first?"; then
            install_docker
        else
            log "ERROR" "Docker Compose installation aborted. Docker is required." true
            return 1
        fi
    fi
    
    # Install Docker Compose Plugin (preferred method)
    if [ "$OS_FAMILY" = "debian" ] || [ "$OS_FAMILY" = "rhel" ]; then
        log "INFO" "Installing Docker Compose Plugin..." true
        
        case "$OS_FAMILY" in
            debian)
                apt-get update
                apt-get install -y docker-compose-plugin
                ;;
            rhel)
                $PACKAGE_MANAGER install -y docker-compose-plugin
                ;;
        esac
        
        # Check if plugin was installed successfully
        if docker compose version &> /dev/null; then
            log "SUCCESS" "Docker Compose Plugin installed successfully" true
            detect_docker_compose_version
            return 0
        else
            log "WARNING" "Docker Compose Plugin installation failed, trying standalone method..." true
        fi
    fi
    
    # Fallback to standalone Docker Compose installation
    log "INFO" "Installing standalone Docker Compose..." true
    
    # Determine system architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) COMPOSE_ARCH="x86_64" ;;
        aarch64) COMPOSE_ARCH="aarch64" ;;
        armv7l) COMPOSE_ARCH="armv7" ;;
        *) 
            log "ERROR" "Unsupported architecture: $ARCH" true
            return 1
            ;;
    esac
    
    # Download Docker Compose binary
    DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/$DEFAULT_COMPOSE_VERSION/docker-compose-linux-$COMPOSE_ARCH"
    log "INFO" "Downloading Docker Compose from $DOCKER_COMPOSE_URL..." true
    
    if curl -L "$DOCKER_COMPOSE_URL" -o /usr/local/bin/docker-compose; then
        chmod +x /usr/local/bin/docker-compose
        
        # Create symbolic link
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
        
        # Check if installation was successful
        if docker-compose --version &> /dev/null; then
            log "SUCCESS" "Docker Compose installed successfully" true
            detect_docker_compose_version
            return 0
        else
            log "ERROR" "Docker Compose installation failed" true
            return 1
        fi
    else
        log "ERROR" "Failed to download Docker Compose" true
        return 1
    fi
}

# Function to remove Docker Compose
remove_docker_compose() {
    log "INFO" "Removing Docker Compose..." true
    
    # Check if Docker Compose is installed
    if [ "$DOCKER_COMPOSE_INSTALLED" = false ]; then
        log "WARNING" "Docker Compose is not installed" true
        return 0
    fi
    
    # Remove based on installation type
    if [ "$DOCKER_COMPOSE_INSTALLED" = "plugin" ]; then
        # Remove Docker Compose Plugin
        case "$OS_FAMILY" in
            debian)
                apt-get purge -y docker-compose-plugin
                ;;
            rhel)
                $PACKAGE_MANAGER remove -y docker-compose-plugin
                ;;
            *)
                log "INFO" "Attempting to remove Docker Compose Plugin..." true
                apt-get purge -y docker-compose-plugin
                $PACKAGE_MANAGER remove -y docker-compose-plugin
                ;;
        esac
    fi
    
    # Remove standalone Docker Compose
    if [ -f /usr/local/bin/docker-compose ]; then
        rm -f /usr/local/bin/docker-compose
    fi
    
    if [ -f /usr/bin/docker-compose ]; then
        rm -f /usr/bin/docker-compose
    fi
    
    log "SUCCESS" "Docker Compose removed successfully" true
    
    # Update Docker Compose installation status
    DOCKER_COMPOSE_INSTALLED=false
    
    return 0
}

# ============================================================================
# DOCKER CONTAINER MANAGEMENT FUNCTIONS
# ============================================================================

# Function to list containers
list_containers() {
    local filter="$1"  # all, running, stopped
    
    log "INFO" "Listing Docker containers..." true
    
    if [ "$DOCKER_INSTALLED" = false ] || [ "$DOCKER_STATUS" != "running" ]; then
        log "ERROR" "Docker is not installed or not running" true
        return 1
    fi
    
    case "$filter" in
        all)
            echo -e "\n${BOLD_CYAN}All containers:${NC}"
            docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
            ;;
        running)
            echo -e "\n${BOLD_GREEN}Running containers:${NC}"
            docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
            ;;
        stopped)
            echo -e "\n${BOLD_YELLOW}Stopped containers:${NC}"
            docker ps -f "status=exited" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
            ;;
        *)
            # Default to all containers
            echo -e "\n${BOLD_CYAN}All containers:${NC}"
            docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
            ;;
    esac
}

# Function to manage Docker containers
manage_containers() {
    local options=(
        "List All Containers"
        "List Running Containers"
        "List Stopped Containers"
        "Start a Container"
        "Stop a Container"
        "Restart a Container"
        "Remove a Container"
        "View Container Logs"
        "Execute Command in Container"
        "Back to Main Menu"
    )
    
    while true; do
        clear_screen
        show_header "Docker Container Management"
        
        show_menu "Container Management Options" "${options[@]}"
        choice=$?
        
        case $choice in
            1) # List All Containers
                list_containers "all"
                ;;
            2) # List Running Containers
                list_containers "running"
                ;;
            3) # List Stopped Containers
                list_containers "stopped"
                ;;
            4) # Start a Container
                list_containers "stopped"
                echo
                read -r -p "Enter container ID or name to start: " container_id
                if [ -n "$container_id" ]; then
                    log "INFO" "Starting container $container_id..." true
                    if docker start "$container_id"; then
                        log "SUCCESS" "Container $container_id started successfully" true
                    else
                        log "ERROR" "Failed to start container $container_id" true
                    fi
                fi
                ;;
            5) # Stop a Container
                list_containers "running"
                echo
                read -r -p "Enter container ID or name to stop: " container_id
                if [ -n "$container_id" ]; then
                    log "INFO" "Stopping container $container_id..." true
                    if docker stop "$container_id"; then
                        log "SUCCESS" "Container $container_id stopped successfully" true
                    else
                        log "ERROR" "Failed to stop container $container_id" true
                    fi
                fi
                ;;
            6) # Restart a Container
                list_containers "running"
                echo
                read -r -p "Enter container ID or name to restart: " container_id
                if [ -n "$container_id" ]; then
                    log "INFO" "Restarting container $container_id..." true
                    if docker restart "$container_id"; then
                        log "SUCCESS" "Container $container_id restarted successfully" true
                    else
                        log "ERROR" "Failed to restart container $container_id" true
                    fi
                fi
                ;;
            7) # Remove a Container
                list_containers "all"
                echo
                read -r -p "Enter container ID or name to remove: " container_id
                if [ -n "$container_id" ]; then
                    read -r -p "Force removal? [y/N]: " force
                    if [[ "${force,,}" =~ ^(yes|y)$ ]]; then
                        force_opt="-f"
                    else
                        force_opt=""
                    fi
                    log "INFO" "Removing container $container_id..." true
                    if docker rm $force_opt "$container_id"; then
                        log "SUCCESS" "Container $container_id removed successfully" true
                    else
                        log "ERROR" "Failed to remove container $container_id" true
                    fi
                fi
                ;;
            8) # View Container Logs
                list_containers "all"
                echo
                read -r -p "Enter container ID or name to view logs: " container_id
                if [ -n "$container_id" ]; then
                    read -r -p "Number of lines to show (default: 50): " lines
                    lines=${lines:-50}
                    log "INFO" "Viewing logs for container $container_id..." true
                    docker logs --tail="$lines" -f "$container_id"
                fi
                ;;
            9) # Execute Command in Container
                list_containers "running"
                echo
                read -r -p "Enter container ID or name to execute command: " container_id
                if [ -n "$container_id" ]; then
                    read -r -p "Enter command to execute (default: /bin/bash): " cmd
                    cmd=${cmd:-/bin/bash}
                    log "INFO" "Executing command in container $container_id..." true
                    docker exec -it "$container_id" $cmd
                fi
                ;;
            10) # Back to Main Menu
                return
                ;;
            *)
                log "ERROR" "Invalid choice. Please try again." true
                ;;
        esac
        
        echo
        read -r -p "Press Enter to continue..."
    done
}

# ============================================================================
# DOCKER IMAGE MANAGEMENT FUNCTIONS
# ============================================================================

# Function to list images
list_images() {
    local filter="$1"  # all, dangling
    
    log "INFO" "Listing Docker images..." true
    
    if [ "$DOCKER_INSTALLED" = false ] || [ "$DOCKER_STATUS" != "running" ]; then
        log "ERROR" "Docker is not installed or not running" true
        return 1
    fi
    
    case "$filter" in
        dangling)
            echo -e "\n${BOLD_YELLOW}Dangling images (no tags):${NC}"
            docker images --filter "dangling=true" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedSince}}"
            ;;
        *)
            # Default to all images
            echo -e "\n${BOLD_CYAN}All images:${NC}"
            docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedSince}}"
            ;;
    esac
}

# Function to manage Docker images
manage_images() {
    local options=(
        "List All Images"
        "List Dangling Images"
        "Pull an Image"
        "Remove an Image"
        "Remove Dangling Images"
        "Build an Image from Dockerfile"
        "Tag an Image"
        "Search Docker Hub"
        "Back to Main Menu"
    )
    
    while true; do
        clear_screen
        show_header "Docker Image Management"
        
        show_menu "Image Management Options" "${options[@]}"
        choice=$?
        
        case $choice in
            1) # List All Images
                list_images "all"
                ;;
            2) # List Dangling Images
                list_images "dangling"
                ;;
            3) # Pull an Image
                echo
                read -r -p "Enter image name to pull (e.g., ubuntu:latest): " image_name
                if [ -n "$image_name" ]; then
                    log "INFO" "Pulling image $image_name..." true
                    if docker pull "$image_name"; then
                        log "SUCCESS" "Image $image_name pulled successfully" true
                    else
                        log "ERROR" "Failed to pull image $image_name" true
                    fi
                fi
                ;;
            4) # Remove an Image
                list_images "all"
                echo
                read -r -p "Enter image ID or name to remove: " image_id
                if [ -n "$image_id" ]; then
                    read -r -p "Force removal? [y/N]: " force
                    if [[ "${force,,}" =~ ^(yes|y)$ ]]; then
                        force_opt="-f"
                    else
                        force_opt=""
                    fi
                    log "INFO" "Removing image $image_id..." true
                    if docker rmi $force_opt "$image_id"; then
                        log "SUCCESS" "Image $image_id removed successfully" true
                    else
                        log "ERROR" "Failed to remove image $image_id" true
                    fi
                fi
                ;;
            5) # Remove Dangling Images
                if confirm "Are you sure you want to remove all dangling images?"; then
                    log "INFO" "Removing dangling images..." true
                    if docker image prune -f; then
                        log "SUCCESS" "Dangling images removed successfully" true
                    else
                        log "ERROR" "Failed to remove dangling images" true
                    fi
                fi
                ;;
            6) # Build an Image from Dockerfile
                echo
                read -r -p "Enter the directory containing the Dockerfile: " dockerfile_dir
                if [ -d "$dockerfile_dir" ]; then
                    read -r -p "Enter a tag for the new image: " image_tag
                    if [ -n "$image_tag" ]; then
                        log "INFO" "Building image from Dockerfile in $dockerfile_dir..." true
                        if docker build -t "$image_tag" "$dockerfile_dir"; then
                            log "SUCCESS" "Image $image_tag built successfully" true
                        else
                            log "ERROR" "Failed to build image $image_tag" true
                        fi
                    fi
                else
                    log "ERROR" "Directory not found: $dockerfile_dir" true
                fi
                ;;
            7) # Tag an Image
                list_images "all"
                echo
                read -r -p "Enter image ID or name to tag: " image_id
                if [ -n "$image_id" ]; then
                    read -r -p "Enter new tag (e.g., myimage:latest): " new_tag
                    if [ -n "$new_tag" ]; then
                        log "INFO" "Tagging image $image_id as $new_tag..." true
                        if docker tag "$image_id" "$new_tag"; then
                            log "SUCCESS" "Image tagged successfully" true
                        else
                            log "ERROR" "Failed to tag image" true
                        fi
                    fi
                fi
                ;;
            8) # Search Docker Hub
                echo
                read -r -p "Enter image name to search for: " search_term
                if [ -n "$search_term" ]; then
                    log "INFO" "Searching Docker Hub for '$search_term'..." true
                    docker search "$search_term" --format "table {{.Name}}\t{{.Description}}\t{{.Stars}}\t{{.IsOfficial}}"
                fi
                ;;
            9) # Back to Main Menu
                return
                ;;
            *)
                log "ERROR" "Invalid choice. Please try again." true
                ;;
        esac
        
        echo
        read -r -p "Press Enter to continue..."
    done
}

# ============================================================================
# DOCKER VOLUME MANAGEMENT FUNCTIONS
# ============================================================================

# Function to list volumes
list_volumes() {
    log "INFO" "Listing Docker volumes..." true
    
    if [ "$DOCKER_INSTALLED" = false ] || [ "$DOCKER_STATUS" != "running" ]; then
        log "ERROR" "Docker is not installed or not running" true
        return 1
    fi
    
    echo -e "\n${BOLD_CYAN}Docker volumes:${NC}"
    docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Mountpoint}}"
}

# Function to manage Docker volumes
manage_volumes() {
    local options=(
        "List All Volumes"
        "Create a Volume"
        "Remove a Volume"
        "Remove All Unused Volumes"
        "Inspect a Volume"
        "Back to Main Menu"
    )
    
    while true; do
        clear_screen
        show_header "Docker Volume Management"
        
        show_menu "Volume Management Options" "${options[@]}"
        choice=$?
        
        case $choice in
            1) # List All Volumes
                list_volumes
                ;;
            2) # Create a Volume
                echo
                read -r -p "Enter name for new volume: " volume_name
                if [ -n "$volume_name" ]; then
                    log "INFO" "Creating volume $volume_name..." true
                    if docker volume create "$volume_name"; then
                        log "SUCCESS" "Volume $volume_name created successfully" true
                    else
                        log "ERROR" "Failed to create volume $volume_name" true
                    fi
                fi
                ;;
            3) # Remove a Volume
                list_volumes
                echo
                read -r -p "Enter volume name to remove: " volume_name
                if [ -n "$volume_name" ]; then
                    log "INFO" "Removing volume $volume_name..." true
                    if docker volume rm "$volume_name"; then
                        log "SUCCESS" "Volume $volume_name removed successfully" true
                    else
                        log "ERROR" "Failed to remove volume $volume_name" true
                    fi
                fi
                ;;
            4) # Remove All Unused Volumes
                if confirm "Are you sure you want to remove all unused volumes?"; then
                    log "INFO" "Removing all unused volumes..." true
                    if docker volume prune -f; then
                        log "SUCCESS" "Unused volumes removed successfully" true
                    else
                        log "ERROR" "Failed to remove unused volumes" true
                    fi
                fi
                ;;
            5) # Inspect a Volume
                list_volumes
                echo
                read -r -p "Enter volume name to inspect: " volume_name
                if [ -n "$volume_name" ]; then
                    log "INFO" "Inspecting volume $volume_name..." true
                    docker volume inspect "$volume_name"
                fi
                ;;
            6) # Back to Main Menu
                return
                ;;
            *)
                log "ERROR" "Invalid choice. Please try again." true
                ;;
        esac
        
        echo
        read -r -p "Press Enter to continue..."
    done
}

# ============================================================================
# DOCKER NETWORK MANAGEMENT FUNCTIONS
# ============================================================================

# Function to list networks
list_networks() {
    log "INFO" "Listing Docker networks..." true
    
    if [ "$DOCKER_INSTALLED" = false ] || [ "$DOCKER_STATUS" != "running" ]; then
        log "ERROR" "Docker is not installed or not running" true
        return 1
    fi
    
    echo -e "\n${BOLD_CYAN}Docker networks:${NC}"
    docker network ls --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}"
}

# Function to manage Docker networks
manage_networks() {
    local options=(
        "List All Networks"
        "Create a Network"
        "Remove a Network"
        "Remove All Unused Networks"
        "Inspect a Network"
        "Connect Container to Network"
        "Disconnect Container from Network"
        "Back to Main Menu"
    )
    
    while true; do
        clear_screen
        show_header "Docker Network Management"
        
        show_menu "Network Management Options" "${options[@]}"
        choice=$?
        
        case $choice in
            1) # List All Networks
                list_networks
                ;;
            2) # Create a Network
                echo
                read -r -p "Enter name for new network: " network_name
                if [ -n "$network_name" ]; then
                    read -r -p "Enter driver (default: bridge): " driver
                    driver=${driver:-bridge}
                    log "INFO" "Creating network $network_name with driver $driver..." true
                    if docker network create --driver="$driver" "$network_name"; then
                        log "SUCCESS" "Network $network_name created successfully" true
                    else
                        log "ERROR" "Failed to create network $network_name" true
                    fi
                fi
                ;;
            3) # Remove a Network
                list_networks
                echo
                read -r -p "Enter network name or ID to remove: " network_name
                if [ -n "$network_name" ]; then
                    log "INFO" "Removing network $network_name..." true
                    if docker network rm "$network_name"; then
                        log "SUCCESS" "Network $network_name removed successfully" true
                    else
                        log "ERROR" "Failed to remove network $network_name" true
                    fi
                fi
                ;;
            4) # Remove All Unused Networks
                if confirm "Are you sure you want to remove all unused networks?"; then
                    log "INFO" "Removing all unused networks..." true
                    if docker network prune -f; then
                        log "SUCCESS" "Unused networks removed successfully" true
                    else
                        log "ERROR" "Failed to remove unused networks" true
                    fi
                fi
                ;;
            5) # Inspect a Network
                list_networks
                echo
                read -r -p "Enter network name or ID to inspect: " network_name
                if [ -n "$network_name" ]; then
                    log "INFO" "Inspecting network $network_name..." true
                    docker network inspect "$network_name"
                fi
                ;;
            6) # Connect Container to Network
                list_networks
                echo
                read -r -p "Enter network name or ID: " network_name
                if [ -n "$network_name" ]; then
                    list_containers "running"
                    echo
                    read -r -p "Enter container name or ID to connect: " container_name
                    if [ -n "$container_name" ]; then
                        log "INFO" "Connecting container $container_name to network $network_name..." true
                        if docker network connect "$network_name" "$container_name"; then
                            log "SUCCESS" "Container connected to network successfully" true
                        else
                            log "ERROR" "Failed to connect container to network" true
                        fi
                    fi
                fi
                ;;
            7) # Disconnect Container from Network
                list_networks
                echo
                read -r -p "Enter network name or ID: " network_name
                if [ -n "$network_name" ]; then
                    # Show containers in this network
                    echo -e "\n${BOLD_CYAN}Containers in network $network_name:${NC}"
                    docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' "$network_name"
                    echo
                    
                    read -r -p "Enter container name or ID to disconnect: " container_name
                    if [ -n "$container_name" ]; then
                        log "INFO" "Disconnecting container $container_name from network $network_name..." true
                        if docker network disconnect "$network_name" "$container_name"; then
                            log "SUCCESS" "Container disconnected from network successfully" true
                        else
                            log "ERROR" "Failed to disconnect container from network" true
                        fi
                    fi
                fi
                ;;
            8) # Back to Main Menu
                return
                ;;
            *)
                log "ERROR" "Invalid choice. Please try again." true
                ;;
        esac
        
        echo
        read -r -p "Press Enter to continue..."
    done
}

# ============================================================================
# DOCKER COMPOSE MANAGEMENT FUNCTIONS
# ============================================================================

# Function to check Docker Compose project directory
check_compose_project() {
    local project_dir="$1"
    
    # Check if directory exists
    if [ ! -d "$project_dir" ]; then
        log "ERROR" "Directory does not exist: $project_dir" true
        return 1
    fi
    
    # Check for docker-compose.yml or docker-compose.yaml or compose.yaml
    if [ ! -f "$project_dir/docker-compose.yml" ] && [ ! -f "$project_dir/docker-compose.yaml" ] && [ ! -f "$project_dir/compose.yaml" ]; then
        log "ERROR" "No docker-compose.yml, docker-compose.yaml, or compose.yaml found in $project_dir" true
        return 1
    fi
    
    return 0
}

# Function to list running Docker Compose projects
list_compose_projects() {
    log "INFO" "Listing Docker Compose projects..." true
    
    if [ "$DOCKER_INSTALLED" = false ] || [ "$DOCKER_STATUS" != "running" ]; then
        log "ERROR" "Docker is not installed or not running" true
        return 1
    fi
    
    if [ "$DOCKER_COMPOSE_INSTALLED" = false ]; then
        log "ERROR" "Docker Compose is not installed" true
        return 1
    fi
    
    # Find containers created by Docker Compose
    echo -e "\n${BOLD_CYAN}Running Docker Compose projects:${NC}"
    docker ps --filter "label=com.docker.compose.project" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}\t{{.Labels}}" | grep -v "NAMES"
}

# Function to manage Docker Compose projects
manage_compose() {
    local options=(
        "List Running Compose Projects"
        "Start a Compose Project"
        "Stop a Compose Project"
        "Restart a Compose Project"
        "View Compose Project Logs"
        "Remove a Compose Project"
        "Validate Compose File"
        "Back to Main Menu"
    )
    
    while true; do
        clear_screen
        show_header "Docker Compose Management"
        
        show_menu "Compose Management Options" "${options[@]}"
        choice=$?
        
        case $choice in
            1) # List Running Compose Projects
                list_compose_projects
                ;;
            2) # Start a Compose Project
                echo
                read -r -p "Enter the directory containing the docker-compose.yml file: " project_dir
                if check_compose_project "$project_dir"; then
                    read -r -p "Enter a project name (optional): " project_name
                    project_name_opt=""
                    if [ -n "$project_name" ]; then
                        project_name_opt="-p $project_name"
                    fi
                    
                    log "INFO" "Starting Docker Compose project in $project_dir..." true
                    
                    if [ "$DOCKER_COMPOSE_INSTALLED" = "plugin" ]; then
                        cd "$project_dir" && docker compose $project_name_opt up -d
                    else
                        cd "$project_dir" && docker-compose $project_name_opt up -d
                    fi
                    
                    if [ $? -eq 0 ]; then
                        log "SUCCESS" "Docker Compose project started successfully" true
                    else
                        log "ERROR" "Failed to start Docker Compose project" true
                    fi
                fi
                ;;
            3) # Stop a Compose Project
                echo
                read -r -p "Enter the directory containing the docker-compose.yml file: " project_dir
                if check_compose_project "$project_dir"; then
                    read -r -p "Enter the project name (optional): " project_name
                    project_name_opt=""
                    if [ -n "$project_name" ]; then
                        project_name_opt="-p $project_name"
                    fi
                    
                    log "INFO" "Stopping Docker Compose project in $project_dir..." true
                    
                    if [ "$DOCKER_COMPOSE_INSTALLED" = "plugin" ]; then
                        cd "$project_dir" && docker compose $project_name_opt stop
                    else
                        cd "$project_dir" && docker-compose $project_name_opt stop
                    fi
                    
                    if [ $? -eq 0 ]; then
                        log "SUCCESS" "Docker Compose project stopped successfully" true
                    else
                        log "ERROR" "Failed to stop Docker Compose project" true
                    fi
                fi
                ;;
            4) # Restart a Compose Project
                echo
                read -r -p "Enter the directory containing the docker-compose.yml file: " project_dir
                if check_compose_project "$project_dir"; then
                    read -r -p "Enter the project name (optional): " project_name
                    project_name_opt=""
                    if [ -n "$project_name" ]; then
                        project_name_opt="-p $project_name"
                    fi
                    
                    log "INFO" "Restarting Docker Compose project in $project_dir..." true
                    
                    if [ "$DOCKER_COMPOSE_INSTALLED" = "plugin" ]; then
                        cd "$project_dir" && docker compose $project_name_opt restart
                    else
                        cd "$project_dir" && docker-compose $project_name_opt restart
                    fi
                    
                    if [ $? -eq 0 ]; then
                        log "SUCCESS" "Docker Compose project restarted successfully" true
                    else
                        log "ERROR" "Failed to restart Docker Compose project" true
                    fi
                fi
                ;;
            5) # View Compose Project Logs
                echo
                read -r -p "Enter the directory containing the docker-compose.yml file: " project_dir
                if check_compose_project "$project_dir"; then
                    read -r -p "Enter the project name (optional): " project_name
                    project_name_opt=""
                    if [ -n "$project_name" ]; then
                        project_name_opt="-p $project_name"
                    fi
                    
                    read -r -p "Enter service name (optional, leave blank for all): " service_name
                    read -r -p "Number of lines to show (default: 50): " lines
                    lines=${lines:-50}
                    
                    log "INFO" "Viewing logs for Docker Compose project in $project_dir..." true
                    
                    if [ "$DOCKER_COMPOSE_INSTALLED" = "plugin" ]; then
                        cd "$project_dir" && docker compose $project_name_opt logs --tail="$lines" -f $service_name
                    else
                        cd "$project_dir" && docker-compose $project_name_opt logs --tail="$lines" -f $service_name
                    fi
                fi
                ;;
            6) # Remove a Compose Project
                echo
                read -r -p "Enter the directory containing the docker-compose.yml file: " project_dir
                if check_compose_project "$project_dir"; then
                    read -r -p "Enter the project name (optional): " project_name
                    project_name_opt=""
                    if [ -n "$project_name" ]; then
                        project_name_opt="-p $project_name"
                    fi
                    
                    read -r -p "Remove volumes? [y/N]: " remove_volumes
                    volumes_opt=""
                    if [[ "${remove_volumes,,}" =~ ^(yes|y)$ ]]; then
                        volumes_opt="-v"
                    fi
                    
                    log "INFO" "Removing Docker Compose project in $project_dir..." true
                    
                    if [ "$DOCKER_COMPOSE_INSTALLED" = "plugin" ]; then
                        cd "$project_dir" && docker compose $project_name_opt down $volumes_opt
                    else
                        cd "$project_dir" && docker-compose $project_name_opt down $volumes_opt
                    fi
                    
                    if [ $? -eq 0 ]; then
                        log "SUCCESS" "Docker Compose project removed successfully" true
                    else
                        log "ERROR" "Failed to remove Docker Compose project" true
                    fi
                fi
                ;;
            7) # Validate Compose File
                echo
                read -r -p "Enter the directory containing the docker-compose.yml file: " project_dir
                if check_compose_project "$project_dir"; then
                    log "INFO" "Validating Docker Compose file in $project_dir..." true
                    
                    if [ "$DOCKER_COMPOSE_INSTALLED" = "plugin" ]; then
                        cd "$project_dir" && docker compose config
                    else
                        cd "$project_dir" && docker-compose config
                    fi
                    
                    if [ $? -eq 0 ]; then
                        log "SUCCESS" "Docker Compose file validation successful" true
                    else
                        log "ERROR" "Docker Compose file validation failed" true
                    fi
                fi
                ;;
            8) # Back to Main Menu
                return
                ;;
            *)
                log "ERROR" "Invalid choice. Please try again." true
                ;;
        esac
        
        echo
        read -r -p "Press Enter to continue..."
    done
}

# ============================================================================
# DOCKER SYSTEM MAINTENANCE FUNCTIONS
# ============================================================================

# Function to display Docker system info
show_docker_dashboard() {
    log "INFO" "Displaying Docker dashboard..." true
    
    if [ "$DOCKER_INSTALLED" = false ]; then
        log "ERROR" "Docker is not installed" true
        return 1
    fi
    
    clear_screen
    show_header "Docker Dashboard"
    
    # Docker version and status
    echo -e "${BOLD_WHITE}Docker Engine:${NC}"
    echo -e "  Version: ${CYAN}$DOCKER_VERSION${NC}"
    echo -e "  Status: $([ "$DOCKER_STATUS" = "running" ] && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Stopped${NC}")"
    
    # Docker Compose version
    echo -e "\n${BOLD_WHITE}Docker Compose:${NC}"
    if [ "$DOCKER_COMPOSE_INSTALLED" = "classic" ]; then
        echo -e "  Version: ${CYAN}$DOCKER_COMPOSE_VERSION_OLD${NC} (classic)"
    elif [ "$DOCKER_COMPOSE_INSTALLED" = "plugin" ]; then
        echo -e "  Version: ${CYAN}$DOCKER_COMPOSE_VERSION_NEW${NC} (plugin)"
    else
        echo -e "  Status: ${RED}Not installed${NC}"
    fi
    
    # System info
    if [ "$DOCKER_STATUS" = "running" ]; then
        # Docker system resources
        echo -e "\n${BOLD_WHITE}System Resources:${NC}"
        docker info | grep -E "Containers:|Running:|Paused:|Stopped:|Images:" | while read -r line; do
            key=$(echo "$line" | cut -d: -f1)
            value=$(echo "$line" | cut -d: -f2)
            echo -e "  $key: ${CYAN}$value${NC}"
        done
        
        # Docker disk usage
        echo -e "\n${BOLD_WHITE}Disk Usage:${NC}"
        docker system df | grep -v "TYPE" | while read -r line; do
            echo -e "  $line" | sed "s/[0-9.]\+\(\s\+\)GB/${CYAN}&${NC}/"
        done
        
        # Running containers count
        running_containers=$(docker ps -q | wc -l)
        echo -e "\n${BOLD_WHITE}Containers:${NC}"
        echo -e "  Running: ${GREEN}$running_containers${NC}"
        
        # Show top 5 running containers by memory usage
        if [ "$running_containers" -gt 0 ]; then
            echo -e "\n${BOLD_WHITE}Top Containers by Memory Usage:${NC}"
            docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | head -n 6
        fi
    fi
}

# Function to clean up Docker system
docker_system_cleanup() {
    local options=(
        "Remove All Unused Containers"
        "Remove All Unused Images"
        "Remove All Unused Volumes"
        "Remove All Unused Networks"
        "System Prune (Containers, Images, Networks)"
        "System Prune (Everything including Volumes)"
        "Back to Main Menu"
    )
    
    while true; do
        clear_screen
        show_header "Docker System Cleanup"
        
        show_menu "Cleanup Options" "${options[@]}"
        choice=$?
        
        case $choice in
            1) # Remove All Unused Containers
                if confirm "Are you sure you want to remove all unused containers?"; then
                    log "INFO" "Removing all unused containers..." true
                    if docker container prune -f; then
                        log "SUCCESS" "Unused containers removed successfully" true
                    else
                        log "ERROR" "Failed to remove unused containers" true
                    fi
                fi
                ;;
            2) # Remove All Unused Images
                if confirm "Are you sure you want to remove all unused images?"; then
                    log "INFO" "Removing all unused images..." true
                    if docker image prune -af; then
                        log "SUCCESS" "Unused images removed successfully" true
                    else
                        log "ERROR" "Failed to remove unused images" true
                    fi
                fi
                ;;
            3) # Remove All Unused Volumes
                if confirm "Are you sure you want to remove all unused volumes?"; then
                    log "INFO" "Removing all unused volumes..." true
                    if docker volume prune -f; then
                        log "SUCCESS" "Unused volumes removed successfully" true
                    else
                        log "ERROR" "Failed to remove unused volumes" true
                    fi
                fi
                ;;
            4) # Remove All Unused Networks
                if confirm "Are you sure you want to remove all unused networks?"; then
                    log "INFO" "Removing all unused networks..." true
                    if docker network prune -f; then
                        log "SUCCESS" "Unused networks removed successfully" true
                    else
                        log "ERROR" "Failed to remove unused networks" true
                    fi
                fi
                ;;
            5) # System Prune (Containers, Images, Networks)
                if confirm "Are you sure you want to remove all unused containers, images, and networks?"; then
                    log "INFO" "Performing system prune..." true
                    if docker system prune -af; then
                        log "SUCCESS" "System prune completed successfully" true
                    else
                        log "ERROR" "System prune failed" true
                    fi
                fi
                ;;
            6) # System Prune (Everything including Volumes)
                if confirm "WARNING: This will remove all unused data, including volumes. Are you sure?"; then
                    log "INFO" "Performing full system prune including volumes..." true
                    if docker system prune -af --volumes; then
                        log "SUCCESS" "Full system prune completed successfully" true
                    else
                        log "ERROR" "Full system prune failed" true
                    fi
                fi
                ;;
            7) # Back to Main Menu
                return
                ;;
            *)
                log "ERROR" "Invalid choice. Please try again." true
                ;;
        esac
        
        echo
        read -r -p "Press Enter to continue..."
    done
}

# Function to run security checks on Docker installation
docker_security_check() {
    log "INFO" "Running Docker security checks..." true
    
    clear_screen
    show_header "Docker Security Check"
    
    echo -e "${BOLD_WHITE}Security Check Results:${NC}\n"
    
    # Check if Docker is running with secure configuration
    echo -e "${BOLD_CYAN}1. Docker daemon configuration:${NC}"
    if [ -f /etc/docker/daemon.json ]; then
        echo -e "   - daemon.json exists: ${GREEN}Yes${NC}"
        # Check for userns-remap setting (user namespace remapping)
        if grep -q "userns-remap" /etc/docker/daemon.json; then
            echo -e "   - User namespace remapping: ${GREEN}Enabled${NC}"
        else
            echo -e "   - User namespace remapping: ${YELLOW}Not enabled${NC}"
        fi
        # Check for live-restore setting (keep containers alive during daemon downtime)
        if grep -q "live-restore" /etc/docker/daemon.json; then
            echo -e "   - Live restore: ${GREEN}Enabled${NC}"
        else
            echo -e "   - Live restore: ${YELLOW}Not enabled${NC}"
        fi
    else
        echo -e "   - daemon.json exists: ${YELLOW}No${NC}"
        echo -e "   - Recommendation: Create /etc/docker/daemon.json with secure defaults"
    fi
    
    # Check for Docker socket permissions
    echo -e "\n${BOLD_CYAN}2. Docker socket permissions:${NC}"
    if [ -S /var/run/docker.sock ]; then
        socket_perms=$(stat -c "%a %u %g" /var/run/docker.sock)
        socket_owner=$(stat -c "%U" /var/run/docker.sock)
        socket_group=$(stat -c "%G" /var/run/docker.sock)
        echo -e "   - Socket permissions: ${YELLOW}$socket_perms${NC} ($socket_owner:$socket_group)"
        echo -e "   - Recommendation: Ensure socket is owned by root:docker with 660 permissions"
    else
        echo -e "   - Docker socket: ${RED}Not found${NC}"
    fi
    
    # Check for users in docker group
    echo -e "\n${BOLD_CYAN}3. Docker group membership:${NC}"
    if getent group docker > /dev/null; then
        docker_users=$(getent group docker | cut -d: -f4)
        if [ -z "$docker_users" ]; then
            echo -e "   - Users in docker group: ${GREEN}None${NC}"
        else
            echo -e "   - Users in docker group: ${YELLOW}$docker_users${NC}"
            echo -e "   - Note: Users in the docker group have effectively root access"
        fi
    else
        echo -e "   - Docker group: ${YELLOW}Not found${NC}"
    fi
    
    # Check if Docker Content Trust is enabled
    echo -e "\n${BOLD_CYAN}4. Docker Content Trust:${NC}"
    if [ -n "$DOCKER_CONTENT_TRUST" ] && [ "$DOCKER_CONTENT_TRUST" = "1" ]; then
        echo -e "   - Docker Content Trust: ${GREEN}Enabled${NC}"
    else
        echo -e "   - Docker Content Trust: ${YELLOW}Not enabled${NC}"
        echo -e "   - Recommendation: Set DOCKER_CONTENT_TRUST=1 in environment"
    fi
    
    # Check system for common Docker security issues
    echo -e "\n${BOLD_CYAN}5. Container security:${NC}"
    
    # Check for privileged containers
    privileged_containers=$(docker ps --quiet --all --filter "status=running" --format "{{.Names}}" | xargs -r docker inspect --format '{{.Name}}{{if .HostConfig.Privileged}} [PRIVILEGED]{{end}}' | grep "PRIVILEGED" | wc -l)
    
    if [ "$privileged_containers" -gt 0 ]; then
        echo -e "   - Privileged containers: ${RED}$privileged_containers detected${NC}"
        echo -e "   - Recommendation: Avoid using privileged containers in production"
    else
        echo -e "   - Privileged containers: ${GREEN}None detected${NC}"
    fi
    
    echo -e "\n${BOLD_CYAN}6. Security recommendations:${NC}"
    echo -e "   - Enable user namespace remapping in daemon.json"
    echo -e "   - Use Docker Bench Security tool for comprehensive audit"
    echo -e "   - Apply the principle of least privilege for containers"
    echo -e "   - Regularly update Docker Engine and base images"
    echo -e "   - Implement container image scanning"
}

# ============================================================================
# MAIN FUNCTIONS
# ============================================================================

# Function to display the main menu and handle user choices
main_menu() {
    local options=(
        "Docker Dashboard"
        "Manage Containers"
        "Manage Images"
        "Manage Volumes"
        "Manage Networks"
        "Manage Docker Compose Projects"
        "Docker System Cleanup"
        "Docker Security Check"
        "Start/Stop/Restart Docker Service"
        "Install Docker"
        "Install Docker Compose"
        "About DockMate"
        "Exit"
    )
    
    while true; do
        clear_screen
        
        # Display ASCII art header
        cat << "EOF"
 ____             _    __  __       _
|  _ \  ___   ___| | _|  \/  | __ _| |_ ___
| | | |/ _ \ / __| |/ / |\/| |/ _` | __/ _ \
| |_| | (_) | (__|   <| |  | | (_| | ||  __/
|____/ \___/ \___|_|\_\_|  |_|\__,_|\__\___|
                                            v2.0.0
         Docker Management Tool
EOF
        
        echo -e "\n${BOLD_WHITE}System Information:${NC}"
        echo -e "  ${CYAN}OS:${NC} $OS ($OS_FAMILY) $VERSION"
        echo -e "  ${CYAN}Docker:${NC} $([ "$DOCKER_INSTALLED" = true ] && echo -e "${GREEN}Installed${NC} (v$DOCKER_VERSION)" || echo -e "${RED}Not installed${NC}")"
        echo -e "  ${CYAN}Docker Status:${NC} $([ "$DOCKER_STATUS" = "running" ] && echo -e "${GREEN}Running${NC}" || echo -e "${RED}Stopped${NC}")"
        
        if [ "$DOCKER_COMPOSE_INSTALLED" = "classic" ]; then
            echo -e "  ${CYAN}Docker Compose:${NC} ${GREEN}Installed${NC} (v$DOCKER_COMPOSE_VERSION_OLD, classic)"
        elif [ "$DOCKER_COMPOSE_INSTALLED" = "plugin" ]; then
            echo -e "  ${CYAN}Docker Compose:${NC} ${GREEN}Installed${NC} (v$DOCKER_COMPOSE_VERSION_NEW, plugin)"
        else
            echo -e "  ${CYAN}Docker Compose:${NC} ${RED}Not installed${NC}"
        fi
        
        show_menu "Main Menu" "${options[@]}"
        choice=$?
        
        case $choice in
            1) # Docker Dashboard
                show_docker_dashboard
                ;;
            2) # Manage Containers
                if [ "$DOCKER_INSTALLED" = true ] && [ "$DOCKER_STATUS" = "running" ]; then
                    manage_containers
                else
                    log "ERROR" "Docker is not installed or not running" true
                fi
                ;;
            3) # Manage Images
                if [ "$DOCKER_INSTALLED" = true ] && [ "$DOCKER_STATUS" = "running" ]; then
                    manage_images
                else
                    log "ERROR" "Docker is not installed or not running" true
                fi
                ;;
            4) # Manage Volumes
                if [ "$DOCKER_INSTALLED" = true ] && [ "$DOCKER_STATUS" = "running" ]; then
                    manage_volumes
                else
                    log "ERROR" "Docker is not installed or not running" true
                fi
                ;;
            5) # Manage Networks
                if [ "$DOCKER_INSTALLED" = true ] && [ "$DOCKER_STATUS" = "running" ]; then
                    manage_networks
                else
                    log "ERROR" "Docker is not installed or not running" true
                fi
                ;;
            6) # Manage Docker Compose Projects
                if [ "$DOCKER_INSTALLED" = true ] && [ "$DOCKER_STATUS" = "running" ]; then
                    if [ "$DOCKER_COMPOSE_INSTALLED" != false ]; then
                        manage_compose
                    else
                        log "ERROR" "Docker Compose is not installed" true
                        if confirm "Do you want to install Docker Compose now?"; then
                            install_docker_compose
                        fi
                    fi
                else
                    log "ERROR" "Docker is not installed or not running" true
                fi
                ;;
            7) # Docker System Cleanup
                if [ "$DOCKER_INSTALLED" = true ]; then
                    docker_system_cleanup
                else
                    log "ERROR" "Docker is not installed" true
                fi
                ;;
            8) # Docker Security Check
                if [ "$DOCKER_INSTALLED" = true ]; then
                    docker_security_check
                else
                    log "ERROR" "Docker is not installed" true
                fi
                ;;
            9) # Start/Stop/Restart Docker Service
                if [ "$DOCKER_INSTALLED" = true ]; then
                    local service_options=(
                        "Start Docker Service"
                        "Stop Docker Service"
                        "Restart Docker Service"
                        "Back to Main Menu"
                    )
                    
                    show_menu "Docker Service Management" "${service_options[@]}"
                    service_choice=$?
                    
                    case $service_choice in
                        1) # Start Docker Service
                            start_docker_service
                            ;;
                        2) # Stop Docker Service
                            stop_docker_service
                            ;;
                        3) # Restart Docker Service
                            restart_docker_service
                            ;;
                        4) # Back to Main Menu
                            continue
                            ;;
                        *)
                            log "ERROR" "Invalid choice. Please try again." true
                            ;;
                    esac
                else
                    log "ERROR" "Docker is not installed" true
                fi
                ;;
            10) # Install Docker
                install_docker
                ;;
            11) # Install Docker Compose
                install_docker_compose
                ;;
            12) # About DockMate
                clear_screen
                show_header "About DockMate"
                
                cat << EOF

${BOLD_WHITE}DockMate v2.0.0${NC}
A comprehensive Docker and Docker Compose management tool

${BOLD_WHITE}Features:${NC}
• Docker installation and management
• Docker Compose installation and management
• Container, image, volume, and network management
• Docker Compose project management
• System maintenance and cleanup
• Security checks and best practices

${BOLD_WHITE}Created by:${NC} Centopw
${BOLD_WHITE}Enhanced by:${NC} Claude

${BOLD_WHITE}Source code:${NC} https://github.com/centopw/DockMate
${BOLD_WHITE}License:${NC} MIT

EOF
                ;;
            13) # Exit
                log "INFO" "Exiting DockMate..." true
                exit 0
                ;;
            *)
                log "ERROR" "Invalid choice. Please try again." true
                ;;
        esac
        
        echo
        read -r -p "Press Enter to continue..."
    done
}

# Main function to initialize and run the application
main() {
    # Check if running as root
    check_root
    
    # Create log file
    touch "$LOG_FILE"
    log "INFO" "DockMate v2.0.0 started" true
    
    # Detect operating system
    if ! detect_os; then
        log "ERROR" "Unsupported operating system. Exiting." true
        exit 1
    fi
    
    # Detect Docker version and status
    detect_docker_version
    if [ "$DOCKER_INSTALLED" = true ]; then
        check_docker_status
    fi
    
    # Detect Docker Compose version
    detect_docker_compose_version
    
    # Run main menu
    main_menu
}

# Run main function
main