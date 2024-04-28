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

#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to detect Docker version
detect_docker_version() {
    docker_version=$(docker --version 2>/dev/null)
    if [ -n "$docker_version" ]; then
        echo -e "${BLUE}Detected Docker version:${NC}"
        echo "$docker_version"
    else
        echo -e "${BLUE}Docker version:${NC} ${YELLOW}Not detected${NC}"
    fi
}

# Function to detect Docker Compose version
detect_docker_compose_version() {
    docker_compose_version=$(docker-compose --version 2>/dev/null)
    if [ -n "$docker_compose_version" ]; then
        echo -e "${BLUE}Detected Docker Compose version:${NC}"
        echo "$docker_compose_version"
    else
        echo -e "${BLUE}Docker Compose version:${NC} ${YELLOW}Not detected${NC}"
    fi
}

# Function to install Docker
install_docker() {
    echo -e "${BLUE}Updating package index...${NC}"
    if ! sudo apt update; then
        echo -e "${RED}Error: Failed to update package index. Please check your network connection or try again later.${NC}"
        exit 1
    fi

    echo -e "${BLUE}Installing Docker...${NC}"
    if ! command -v docker &>/dev/null; then
        curl -fsSL https://get.docker.com -o install-docker.sh
        if sudo sh install-docker.sh; then
            echo -e "${GREEN}Docker installed successfully.${NC}"
        else
            echo -e "${RED}Error: Docker installation failed.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Docker is already installed.${NC}"
    fi
}

# Function to remove Docker
remove_docker() {
    echo -e "${BLUE}Removing Docker...${NC}"
    if command -v docker &>/dev/null; then
        if sudo apt purge -y docker-ce docker-ce-cli containerd.io; then
            echo -e "${GREEN}Docker removed successfully.${NC}"
        else
            echo -e "${RED}Error: Failed to remove Docker.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Docker is not installed.${NC}"
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    DOCKER_COMPOSE_VERSION="1.29.2"
    DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"

    echo -e "${BLUE}Installing Docker Compose...${NC}"
    if ! command -v docker-compose &>/dev/null; then
        sudo curl -L "${DOCKER_COMPOSE_URL}" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        if docker-compose --version; then
            echo -e "${GREEN}Docker Compose installed successfully.${NC}"
        else
            echo -e "${RED}Error: Docker Compose installation failed.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Docker Compose is already installed.${NC}"
    fi
}

# Function to remove Docker Compose
remove_docker_compose() {
    echo -e "${BLUE}Removing Docker Compose...${NC}"
    if command -v docker-compose &>/dev/null; then
        if sudo rm /usr/local/bin/docker-compose; then
            echo -e "${GREEN}Docker Compose removed successfully.${NC}"
        else
            echo -e "${RED}Error: Failed to remove Docker Compose.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Docker Compose is not installed.${NC}"
    fi
}

# Function to install both Docker and Docker Compose
install_both() {
    install_docker
    install_docker_compose
    echo -e "${GREEN}Install docker and docker-compose success.${NC}"
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

# Function for advanced options menu
advanced_options() {
    # Options for advanced dialog
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
            1) install_docker && echo -e "${GREEN}Install Docker success.${NC}" ;;
            2) install_docker_compose && echo -e "${GREEN}Install Docker Compose success.${NC}" ;;
            3) remove_docker ;;
            4) remove_docker_compose ;;
            5) exit ;;
            *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
        esac
    done
}

# Check if dialog is installed
if ! command -v dialog &>/dev/null; then
    echo -e "${RED}Error: 'dialog' package is not installed.${NC}"
    echo -e "${YELLOW}Please install it using 'sudo apt install dialog' and run the script again.${NC}"
    exit 1
fi

main
