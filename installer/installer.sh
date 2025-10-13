#!/bin/bash

# Color definitions
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_CYAN='\033[38;2;0;255;255m'
COLOR_RESET='\033[0m'

# Global variables
DETECTED_DISTRO=""
COMMANDS_COMPLETED=false
LOADING_COMPLETE=false
CURRENT_VERSION="unknown"
DOWNLOADED_VERSION="unknown"
INSTALLED_VERSION="unknown"

# Utility Functions
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${COLOR_RESET}"
}

print_status() {
    print_color "$COLOR_GREEN" "[INFO] $1"
}

print_warning() {
    print_color "$COLOR_YELLOW" "[WARNING] $1"
}

print_error() {
    print_color "$COLOR_RED" "[ERROR] $1"
}

run_command() {
    local cmd="$1"
    local result
    result=$(eval "$cmd" 2>/dev/null)
    echo "$result"
}

run_command_cyan() {
    local cmd="$1"
    echo -e "$COLOR_CYAN"
    eval "$cmd"
    local result=$?
    echo -e "$COLOR_RESET"
    return $result
}

silent_command() {
    local cmd="$1"
    eval "$cmd >/dev/null 2>&1"
}

# Version Manager Functions
read_version_file() {
    local path="$1"
    if [[ -f "$path" ]]; then
        local version
        version=$(head -n1 "$path" 2>/dev/null)
        if [[ -n "$version" ]]; then
            echo "$version"
        else
            echo "unknown"
        fi
    else
        echo "not installed"
    fi
}

get_versions() {
    local config_dir="/home/$USER/.config/cmi/"
    local source_dir="/mnt/claudemods/version/"
    
    CURRENT_VERSION=$(read_version_file "${config_dir}version.txt")
    DOWNLOADED_VERSION=$(read_version_file "${source_dir}version.txt")
    INSTALLED_VERSION="$DOWNLOADED_VERSION"
}

update_installed_version() {
    local config_dir="/home/$USER/.config/cmi/"
    local source_dir="/mnt/claudemods/version/"
    
    if [[ -f "${source_dir}version.txt" ]]; then
        cp "${source_dir}version.txt" "${config_dir}version.txt"
    fi
}

detect_distribution() {
    if [[ ! -f "/etc/os-release" ]]; then
        print_error "Cannot detect the distribution. Exiting."
        return 1
    fi

    local distro_output
    distro_output=$(cat /etc/os-release | grep '^ID=' | cut -d'=' -f2 | tr -d '"')
    
    if [[ -n "$distro_output" ]]; then
        DETECTED_DISTRO="$distro_output"
        return 0
    else
        print_error "Failed to read distribution information."
        return 1
    fi
}

setup_directories() {
    print_status "Setting up directories"
    silent_command "cd /home/$USER"
    silent_command "mkdir -p /home/$USER/.config/cmi"
    return 0
}

download_with_wait() {
    print_status "Starting download... This may take several minutes."

    # Remove existing files first
    run_command_cyan "sudo rm -rf /home/$USER/.config/cmi/codex-files.img"
    run_command_cyan "sudo rm -rf /home/$USER/codex-files.img.xz"
    run_command_cyan "sudo rm -rf '/home/$USER/download?id=1yzRPvHfvcqQh5FnqPCjRNqjKlRzaemDq'"

    # Download with explicit wait
    print_status "Downloading file from Google Drive..."
    echo -e "$COLOR_CYAN"
    cd /home/$USER && wget --show-progress --no-check-certificate 'https://drive.usercontent.google.com/download?id=1yzRPvHfvcqQh5FnqPCjRNqjKlRzaemDq&export=download&authuser=0&confirm=t&uuid=cb571b39-a0a0-4d03-b8d9-2f3b605aaeb9&at=AKSUxGNWz75j3Sq6erlvb25_J9cr:1759936706590' >/dev/null 2>&1
    local result=$?
    echo -e "$COLOR_RESET"

    if [[ $result -ne 0 ]]; then
        print_error "Download failed!"
        return 1
    fi

    print_status "Download completed successfully!"
    return 0
}

install_arch_cachyos() {
    # FIXED: Download first and wait for completion
    if ! download_with_wait; then
        return 1
    fi

    # Now continue with the rest of the commands
    run_command_cyan "cd /home/$USER && mv download* /home/$USER/codex-files.img.xz"
    run_command_cyan "mkdir -p /home/$USER/.config/cmi"
    run_command_cyan "cd /home/$USER/ && sudo unxz codex-files.img.xz"
    run_command_cyan "cd /home/$USER/ && sudo mv codex-files.img /home/$USER/.config/cmi"
    run_command_cyan "cd /home/$USER/.config/cmi"
    run_command_cyan "sudo mkdir -p /mnt/claudemods"

    # Handle loop device mounting
    local loop_dev
    loop_dev=$(sudo losetup --find --show /home/$USER/.config/cmi/codex-files.img | tr -d '\n')
    if [[ -n "$loop_dev" ]]; then
        run_command_cyan "sudo mount -o compress=zstd:22,subvol=codex-files \"$loop_dev\" /mnt/claudemods"
    fi

    local current_user
    current_user=$(whoami)
    run_command_cyan "sudo chown \"$current_user:$current_user\" /mnt/claudemods"

    run_command_cyan "cd /mnt/claudemods/working-hooks-btrfs-ext4 && sudo cp -r * /etc/initcpio"
    run_command_cyan "cd /mnt/claudemods && sudo cp -r build-image-arch-img /home/$USER/.config/cmi"

    # Version management
    update_installed_version

    run_command_cyan "cd /mnt/claudemods/cmi && qmake6 && make"
    run_command_cyan "sudo cp /mnt/claudemods/cmi/cmiimg /usr/bin/cmiimg"
    run_command_cyan "cd /mnt/claudemods/rsyncinstaller && qmake6 && make"
    run_command_cyan "sudo cp cmirsyncinstaller /usr/bin/cmirsyncinstaller"
    run_command_cyan "sudo cp /mnt/claudemods/btrfssystemcloner/btrfssystemcloner /usr/bin/btrfssystemcloner"
    run_command_cyan "sudo cp /mnt/claudemods/ccd/ccd /usr/bin/ccd"
    run_command_cyan "sudo pacman -Sy"

    print_status "Installing dependencies"
    run_command_cyan "sudo pacman -S --needed --noconfirm git rsync squashfs-tools xorriso grub dosfstools unzip nano arch-install-scripts bash-completion erofs-utils findutils jq libarchive libisoburn lsb-release lvm2 mkinitcpio-archiso mkinitcpio-nfs-utils mtools nbd pacman-contrib parted procps-ng pv python sshfs syslinux xdg-utils zsh-completions kernel-modules-hook qt6-tools btrfs-progs e2fsprogs f2fs-tools xfsprogs xfsdump cmake"

    # Ask user if they want to install Calamares
    echo -e "${COLOR_GREEN}Do you want to install Calamares? (y/n): ${COLOR_RESET}"
    read -r response

    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        print_status "Starting Calamares installation and configuration..."

        print_status "Installing Calamares packages..."
        run_command_cyan "cd /mnt/claudemods/calamares-files && sudo pacman -U --noconfirm --overwrite=\"*\" calamares-3.4.0-1-x86_64.pkg.tar.zst calamares-oem-kde-settings-20240616-3-any.pkg.tar calamares-tools-0.1.0-1-any.pkg.tar.zst ckbcomp-1.227-2-any.pkg.tar"

        print_status "Copying Calamares configuration..."
        run_command_cyan "cd /mnt/claudemods/calamares-files && sudo cp -r calamares /etc/"

        print_status "Copying custom branding..."
        run_command_cyan "cd /mnt/claudemods/calamares-files && sudo cp -r claudemods /usr/share/calamares/branding/"

        # Ask user for configuration preference
        print_status "Configuration selection:"
        echo -e "${COLOR_GREEN}Choose Calamares mount configuration:${COLOR_RESET}"
        echo -e "${COLOR_GREEN}1) Default configuration${COLOR_RESET}"
        echo -e "${COLOR_GREEN}2) Custom configuration with new mounts and level 22 compression${COLOR_RESET}"
        echo -e "${COLOR_GREEN}Enter your choice (1 or 2): ${COLOR_RESET}"

        read -r config_choice

        if [[ "$config_choice" == "2" ]]; then
            print_status "Applying custom configuration with new mounts and level 22 compression..."
            run_command_cyan "cd /mnt/claudemods/calamares-files/btrfs-custom-config && sudo cp btrfs-custom-config /usr/share/calamares/modules"
            print_status "Custom configuration applied successfully!"
        else
            print_status "Using default Calamares configuration."
            print_status "Skipping custom mount configuration."
        fi

        print_status "Installing Hooks And My Rsync Installer"
        run_command_cyan "sudo rm -rf /usr/share/calamares/branding/manjaro"

        print_status "Calamares installation and configuration completed!"
    fi

    run_command_cyan "cd /mnt/claudemods"
    run_command_cyan "sudo rm -rf codex-files.img.xz"
    run_command_cyan "sudo rm -rf /home/$USER/claudemods-multi-iso-konsole-script-extras"

    return 0
}

show_loading_bar() {
    echo -ne "${COLOR_GREEN}Progress: [${COLOR_RESET}"
    for ((i=0; i<50; i++)); do
        echo -ne "${COLOR_YELLOW}=${COLOR_RESET}"
        sleep 0.05
    done
    echo -e "${COLOR_GREEN}] 100%${COLOR_RESET}"
    LOADING_COMPLETE=true
}

execute_installation() {
    while [[ "$LOADING_COMPLETE" == false ]]; do
        sleep 0.01
    done

    # Setup
    if ! setup_directories; then
        COMMANDS_COMPLETED=true
        return
    fi

    # Detect distribution
    print_status "Detecting distribution"
    if ! detect_distribution; then
        COMMANDS_COMPLETED=true
        return
    fi

    # Get current version before installation
    get_versions

    # Conditional logic based on detected distribution
    if [[ "$DETECTED_DISTRO" == "arch" || "$DETECTED_DISTRO" == "cachyos" ]]; then
        if ! install_arch_cachyos; then
            print_error "Installation failed for Arch/CachyOS"
            COMMANDS_COMPLETED=true
            return
        fi
    else
        print_error "Unsupported distribution: $DETECTED_DISTRO"
        COMMANDS_COMPLETED=true
        return
    fi

    # Get final version information
    get_versions

    COMMANDS_COMPLETED=true
}

main() {
    echo -e "${COLOR_GREEN}Starting installation process...${COLOR_RESET}"

    # Start installation in background
    execute_installation &
    local installation_pid=$!

    # Show loading bar in main thread
    show_loading_bar

    # Wait for installation to complete
    wait "$installation_pid"

    # Display summary with version information
    echo -e "${COLOR_GREEN}\nInstallation complete!${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Detected distro: $DETECTED_DISTRO${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Current version: $CURRENT_VERSION${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Downloaded version: $DOWNLOADED_VERSION${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Installed version: $INSTALLED_VERSION${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Executables installed to: /usr/bin/${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Configuration files in: /home/$USER/.config/cmi/${COLOR_RESET}"

    # Ask to launch
    echo -e "${COLOR_CYAN}\nLaunch now? (y/n): ${COLOR_RESET}"
    read -r response

    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        cd /home/$USER && ccd
    fi

    exit 0
}

# Run the main function
main "$@"
