#!/bin/bash

# Docker for Linux installation script.
#
# ______           _   ___  ___      _       
# |  _  \         | |  |  \/  |     | |      
# | | | |___   ___| | _| .  . | __ _| |_ ___ 
# | | | / _ \ / __| |/ / |\/| |/ _` | __/ _ \
# | |/ / (_) | (__|   <| |  | | (_| | ||  __/
# |___/ \___/ \___|_|\_\_|  |_/\__,_|\__\___|
#                       -- By Centopw
#
#
# ==============================================================================
# Dockmate is a bash script designed to assist users in managing Docker and Docker Compose on their systems.
#
# Source code is available at https://github.com/centopw/DockMate
#
# Usage
# ==============================================================================
#
# 1. download the script
#
#   $ curl -fsSL https://raw.githubusercontent.com/centopw/DockMate/main/dockmate.sh -o dockmate.sh
#
# 2. verify the script's content
#
#   $ cat dockmate.sh
#
# 4. run the script either as root, or using sudo to perform the installation.
#
#   $ sudo sh dockmate.sh
# ==============================================================================

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to detect software version
detect_version() {
    local software="$1"
    local version_command="$2"
    local version=$($version_command 2>/dev/null)
    if [ -n "$version" ]; then
        echo -e "${BLUE}Detected $software version:${NC}"
        echo "$version"
    else
        echo -e "${BLUE}$software version:${NC} ${YELLOW}Not detected${NC}"
    fi
}

# Function to install software
install_software() {
    local software="$1"
    local install_command="$2"
    echo -e "${BLUE}Installing $software...${NC}"
    if ! command -v "$software" &>/dev/null; then
        if $install_command; then
            echo -e "${GREEN}$software installed successfully.${NC}"
        else
            echo -e "${RED}Error: $software installation failed.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}$software is already installed.${NC}"
    fi
}

# Function to remove software
remove_software() {
    local software="$1"
    local remove_command="$2"
    echo -e "${BLUE}Removing $software...${NC}"
    if command -v "$software" &>/dev/null; then
        if $remove_command; then
            echo -e "${GREEN}$software removed successfully.${NC}"
        else
            echo -e "${RED}Error: Failed to remove $software.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}$software is not installed.${NC}"
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    DOCKER_COMPOSE_VERSION="1.29.2"
    DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
    install_software "Docker Compose" "sudo curl -L $DOCKER_COMPOSE_URL -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose"
}

# Function to remove Docker Compose
remove_docker_compose() {
    remove_software "Docker Compose" "sudo rm /usr/local/bin/docker-compose"
}

# Function to install both Docker and Docker Compose
install_both() {
    install_software "Docker" "curl -fsSL https://get.docker.com -o install-docker.sh && sudo sh install-docker.sh"
    install_docker_compose
    echo -e "${GREEN}Install docker and docker-compose success.${NC}"
}

# Function for advanced options menu
advanced_options() {
    options=(
        1 "Install Docker"
        2 "Install Docker Compose"
        3 "Remove Docker"
        4 "Remove Docker Compose"
        5 "Exit"
    )

    while true; do
        choice=$(dialog --clear \
                        --backtitle "Advanced Options" \
                        --title "Options" \
                        --menu "Choose an option:" \
                        20 60 6 \
                        "${options[@]}" \
                        2>&1 >/dev/tty)

        case $choice in
            1) install_software "Docker" "curl -fsSL https://get.docker.com -o install-docker.sh && sudo sh install-docker.sh" && echo -e "${GREEN}Install Docker success.${NC}" ;;
            2) install_docker_compose && echo -e "${GREEN}Install Docker Compose success.${NC}" ;;
            3) remove_software "Docker" "sudo apt purge -y docker-ce docker-ce-cli containerd.io" ;;
            4) remove_docker_compose ;;
            5) exit ;;
            *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
        esac
    done
}

# Main function
main() {
    # Options for initial dialog
    initial_options=(
        1 "Use the default setup to install Docker and Docker Compose"
        2 "Advance"
    )

    # Prompt user to install both Docker and Docker Compose
    choice=$(dialog --clear \
                    --backtitle "Welcome!" \
                    --title "Install Docker and Docker Compose?" \
                    --menu "Do you want to use the default setup to install Docker and Docker Compose?" \
                    15 60 3 \
                    "${initial_options[@]}" \
                    2>&1 >/dev/tty)

    case $choice in
        1) install_both ;;
        2) advanced_options ;;
        *) echo -e "${RED}Invalid choice. Exiting.${NC}" && exit 1 ;;
    esac
}

# Check if dialog is installed
if ! command -v dialog &>/dev/null; then
    echo -e "${RED}Error: 'dialog' package is not installed.${NC}"
    echo -e "${YELLOW}Please install it using 'sudo apt install dialog' and run the script again.${NC}"
    exit 1
fi

main
