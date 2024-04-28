#!/bin/bash

# Function to print the Cento ASCII art
print_cento() {
    cat << "EOF"
      
# ______           _   ___  ___      _       
# |  _  \         | |  |  \/  |     | |      
# | | | |___   ___| | _| .  . | __ _| |_ ___ 
# | | | / _ \ / __| |/ / |\/| |/ _` | __/ _ \
# | |/ / (_) | (__|   <| |  | | (_| | ||  __/
# |___/ \___/ \___|_|\_\_|  |_/\__,_|\__\___|

#                       -- By Centopw
                                           

EOF
}

# Function to install Docker
install_docker() {
    echo "Updating package index..."
    if ! sudo apt update; then
        echo "Error: Failed to update package index. Please check your network connection or try again later."
        exit 1
    fi

    echo "Installing Docker..."
    if command -v docker &>/dev/null; then
        echo "Docker is already installed."
    else
        curl -fsSL https://get.docker.com -o install-docker.sh
        if sudo sh install-docker.sh; then
            echo "Docker installed successfully."
        else
            echo "Error: Docker installation failed."
            exit 1
        fi
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    DOCKER_COMPOSE_VERSION="1.29.2"
    DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"

    echo "Installing Docker Compose..."
    if command -v docker-compose &>/dev/null; then
        echo "Docker Compose is already installed."
    else
        sudo curl -L "${DOCKER_COMPOSE_URL}" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        if docker-compose --version; then
            echo "Docker Compose installed successfully."
        else
            echo "Error: Docker Compose installation failed."
            exit 1
        fi
    fi
}

# Main function
main() {
    print_cento
    echo "Choose an option:"
    echo "1. Install Docker"
    echo "2. Install Docker Compose"
    echo "3. Install both Docker and Docker Compose"
    read -rp "Enter your choice (1/2/3): " choice

    case $choice in
        1) install_docker ;;
        2) install_docker_compose ;;
        3) install_docker && install_docker_compose ;;
        *) echo "Invalid choice. Please enter a valid option." && exit 1 ;;
    esac
}

main
