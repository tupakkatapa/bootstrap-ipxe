#!/bin/bash
# A script for building and updating the iPXE firmware on the TFTP server.
# https://github.com/tupakkatapa/bootstrap-ipxe

set -e

# Cores
NB_CORES=$(grep -c '^processor' /proc/cpuinfo)
export MAKEFLAGS="-j$((NB_CORES+1)) -l${NB_CORES}"

# Set the current working directory
DIR=$PWD

# Lists of dependencies
DEPS_APT=( git atftp gcc make liblzma-dev )
DEPS_DNF=( git tftp gcc make xz-devel )
DEPS_PACMAN=( git atftp gcc make xz )

# Check for package manager and dependencies
check_dependencies() {
    # Check for package manager
    if command -v apt-get > /dev/null 2>&1; then
        package_manager="dpkg -s"
        dependencies=("${DEPS_APT[@]}")
    elif command -v dnf > /dev/null 2>&1; then
        package_manager="dnf list installed"
        dependencies=("${DEPS_DNF[@]}")
    elif command -v pacman > /dev/null 2>&1; then
        package_manager="pacman -Q"
        dependencies=("${DEPS_PACMAN[@]}")
    else
        read -p "Could not check for dependencies. Continue? (y/n) " check
        if [ "$check" != "y" ]; then
            echo "Aborting..."
            exit 1
        fi
    fi

    # Check for dependencies
    for p in "${dependencies[@]}"; do
        if ! $package_manager $p > /dev/null 2>&1; then
            echo "$p not found: please install $p" 2>&1
            exit 1
        fi
    done
}

# Call to check dependencies
check_dependencies

# Upload to TFTP
upload_tftp () {

    # Check if undionly.kpxe exists
    if [ ! -f "$DIR/ipxe/src/bin/undionly.kpxe" ]; then
        echo "Error: undionly.kpxe not found. Compile first."
        return
    fi

    # Ask for TFTP server IP
    read -p "Enter the IP address of the TFTP server (default: 192.168.1.1): " TFTP_SERVER
    TFTP_SERVER=${TFTP_SERVER:-"192.168.1.1"}
    
    # Check reachability
    if ! ping -c 1 "$TFTP_SERVER" &> /dev/null; then
        echo "Error: TFTP server is not reachable"
        exit 1
    fi

    # Upload file to the TFTP server
    cd $DIR/ipxe/src/bin
    
    if [ $(command -v dnf) ]; then
        tftp -v "$TFTP_SERVER" -c put undionly.kpxe
    else
        atftp "$TFTP_SERVER" -p -l undionly.kpxe
    fi
    echo "Updated undionly.pxe to TFTP server"
}

# Initial compile of iPXE
compile_undionly () {

    # Check if iPXE repository exists
    if [ -d "$DIR/ipxe" ]; then
        read -p "iPXE repo exists. Remove and recompile? (y/n) " check
        if [ "$check" != "y" ]; then
            echo "Aborting..."
            return
        else
            rm -rf "$DIR/ipxe"
        fi
    fi

    # Clone the iPXE repository
    echo "Cloning iPXE repository..."
    git clone https://github.com/ipxe/ipxe.git &> /dev/null || { echo "Error: Failed to clone iPXE. Check internet or try later."; exit 1; }
    echo "iPXE repository has been cloned successfully"

    # Change to the iPXE source directory
    cd $DIR/ipxe/src
    
    # Change keymap to dynamic
    sed -i 's/#define	KEYBOARD_MAP	us/#define	KEYBOARD_MAP	dynamic/' config/console.h

    # Enable HTTPS protocol
    sed -i 's/#undef	DOWNLOAD_PROTO_HTTPS/#define DOWNLOAD_PROTO_HTTPS/' config/general.h

    # Enable NFS support
    sed -i 's/#undef	DOWNLOAD_PROTO_NFS/#define DOWNLOAD_PROTO_NFS/' config/general.h

    # Enable Ping support
    sed -i 's/\/\/#define PING_CMD/#define PING_CMD/' config/general.h
    sed -i 's/\/\/#define IPSTAT_CMD/#define IPSTAT_CMD/' config/general.h
    sed -i 's/\/\/#define REBOOT_CMD/#define REBOOT_CMD/' config/general.h
    sed -i 's/\/\/#define POWEROFF/#define POWEROFF/' config/general.h

    # Compile iPXE
    make -j bin/undionly.kpxe
}

# Create chainloader.ipxe, this script will be embedded into the iPXE binary.
# It breaks the loop and give control to other ipxe script on given url.
embed_chainloader () {

    # Check if undionly.kpxe exists
    if [ ! -f "$DIR/ipxe/src/bin/undionly.kpxe" ]; then
        echo "Error: undionly.kpxe not found. Compile first."
        return
    fi
 
    # Check if chainloader.ipxe exists
    if [ -f "$DIR/chainloader.ipxe" ]; then
        read -p "chainloader.ipxe exists. Overwrite? (y/n) " check
        if [ "$check" != "y" ]; then
            return
        fi
    fi

    # Create the script
    read -p "Enter URL for next boot stage (default: https://boot.netboot.xyz/): " URL
    URL=${URL:-"https://boot.netboot.xyz/"}
    
    echo "Creating chainloader script with URL: $URL"
    cat >> $DIR/chainloader.ipxe << EOF
#!ipxe
dhcp
chain --autofree $URL || shell 
EOF
    
    # Embed into binary
    cd $DIR/ipxe/src
    make -j bin/undionly.kpxe EMBED=$DIR/chainloader.ipxe
}

# Remove all the files created by this script
clean_files () {
    read -p "This will remove all the files created by this script. Are you sure? (y/n) " check
    if [ "$check" != "y" ]; then
        return
    fi
    rm -rf $DIR/ipxe $DIR/chainloader.ipxe
}

# Menu
while true; do
    clear
    echo "==================================="
    echo "   Bootstrap-iPXE"
    echo "==================================="
    echo "1. Build undionly.pxe"
    echo "2. Create and embed iPXE script"
    echo "3. Upload to TFTP server"
    echo "4. Clean all files"
    echo "q. Quit"
    echo
    read -p "Enter your choice: " choice

    IFS=', ' read -r -a options <<< "$choice"
    for option in "${options[@]}"; do
        if [[ $option == *"-"* ]]; then
            start=$(echo $option | cut -f1 -d-)
            end=$(echo $option | cut -f2 -d-)

            # Loop through options in range
            for (( i = $start; i <= $end; i++ )); do
                case $i in
                    1) compile_undionly;;
                    2) embed_chainloader;;
                    3) upload_tftp;;
                    4) clean_files;;
                    q) exit;;
                    *) echo "Invalid choice. Try again.";;
                esac
            done
        else
            case $option in
                1) compile_undionly;;
                2) embed_chainloader;;
                3) upload_tftp;;
                4) clean_files;;
                q) exit;;
                *) echo "Invalid choice. Try again.";;
            esac
        fi
        read -p "Press enter to continue..."
    done
done
