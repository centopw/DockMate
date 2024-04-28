#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print the Cento ASCII art
print_cento() {
    cat << "EOF"
      
# ${YELLOW}______           _   ___  ___      _       ${NC}
# ${YELLOW}|  _  \         | |  |  \/  |     | |      ${NC}
# ${YELLOW}| | | |___   ___| | _| .  . | __ _| |_ ___ ${NC}
# ${YELLOW}| | | / _ \ / __| |/ / |\/| |/ _` | __/ _ \ ${NC}
# ${YELLOW}| |/ / (_) | (__|   <| |  | | (_| | ||  __/${NC}
# ${YELLOW}|___/ \___/ \___|_|\_\_|  |_/\__,_|\__\___|${NC}

#                       -- By Centopw
EOF
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

# Main function
main() {
    print_cento

    # Options for dialog
    options=(
        1 "Install Docker"
        2 "Remove Docker"
        3 "Install Docker Compose"
        4 "Remove Docker Compose"
        5 "Exit"
    )

    while true; do
        choice=$(dialog --clear \
                        --backtitle "Choose an option" \
                        --title "Options" \
                        --menu "Choose an option:" \
                        15 50 5 \
                        "${options[@]}" \
                        2>&1 >/dev/tty)

        case $choice in
            1) install_docker ;;
            2) remove_docker ;;
            3) install_docker_compose ;;
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
