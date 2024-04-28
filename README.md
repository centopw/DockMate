# DockMate

Dockmate is a bash script designed to assist users in managing Docker and Docker Compose on their systems.


## Features

- Interactive menu-driven interface
- Automatic detection of Docker and Docker Compose versions
- Installation and removal of Docker and Docker Compose
- Support for both default and advanced options

## Prerequisites

  - Currently this only work with debian base system.
  - `dialog` package installed (you can install it using `sudo apt install dialog`)
 
## Installation
  
  To install Dockmate, simply run the following command:

```bash
curl -sSL https://raw.githubusercontent.com/centopw/dockmate/main/dockmate.sh | bash
```

This command will download the dockmate.sh script from the repository and execute it directly in your shell environment.

## Usage

Dockmate's advanced options menu allows you to perform the following actions individually:

- Install Docker
- Install Docker Compose
- Remove Docker
- Remove Docker Compose
