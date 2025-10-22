#!/bin/bash

# Color definitions
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[0;31m"
COLOR_CYAN="\033[38;2;0;255;255m"
COLOR_RESET="\033[0m"

# Global variables
detected_distro=""
commands_completed=false
loading_complete=false
current_version="unknown"
downloaded_version="unknown"
installed_version="unknown"

# Utility functions
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

# Version management functions
read_version_file() {
    local path="$1"
    if [[ -f "$path" ]]; then
        local version
        version=$(head -n 1 "$path" 2>/dev/null)
        if [[ -z "$version" ]]; then
            echo "unknown"
        else
            echo "$version"
        fi
    else
        echo "not installed"
    fi
}

get_versions() {
    local config_dir="/home/$USER/.config/cmi/"
    local source_dir="/mnt/claudemods/version/"
    
    current_version=$(read_version_file "${config_dir}version.txt")
    downloaded_version=$(read_version_file "${source_dir}version.txt")
    installed_version="$downloaded_version"
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
    detected_distro="$distro_output"
    return 0
}

setup_directories() {
    print_status "Setting up directories"
    silent_command "cd /home/$USER"
    silent_command "mkdir -p /home/$USER/.config/cmi"
    return 0
}

install_arch_cachyos() {
    # Commands for Arch/CachyOS
    run_command_cyan "sudo rm -rf /home/$USER/.config/cmi/codex-files.img"
    run_command_cyan "cd /home/$USER && git clone https://gitlab.com/claudemods101/claudemods-multi-iso-konsole-script-extras.git"
    run_command_cyan "mkdir -p /home/$USER/.config/cmi"
    run_command_cyan "cd /home/$USER/claudemods-multi-iso-konsole-script-extras/v1.0 && sudo unxz codex-files.img.xz"
    run_command_cyan "cd /home/$USER/claudemods-multi-iso-konsole-script-extras/v1.0 && sudo mv codex-files.img /home/$USER/.config/cmi"
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
    run_command_cyan "sudo pacman -S --needed --noconfirm git rsync squashfs-tools xorriso grub dosfstools unzip nano arch-install-scripts bash-completion erofs-utils findutils jq libarchive libisoburn lsb-release lvm2 mkinitcpio-archiso mkinitcpio-nfs-utils mtools nbd pacman-contrib parted procps-ng pv python sshfs syslinux xdg-utils zsh-completions kernel-modules-hook virt-manager qt6-tools btrfs-progs e2fsprogs f2fs-tools xfsprogs xfsdump cmake"

    # Ask user if they want to install Calamares
    echo -e "${COLOR_GREEN}Do you want to install Calamares? (y/n): ${COLOR_RESET}"
    read -r response

    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        print_status "Starting Calamares installation and configuration..."

        # YOUR EXACT SHELL COMMANDS
        run_command_cyan "cd /mnt/claudemods/calamares-files"

        print_status "Installing Calamares packages..."
        run_command_cyan "sudo pacman -U --noconfirm --overwrite=\"*\" calamares-3.4.0-1-x86_64.pkg.tar.zst calamares-oem-kde-settings-20240616-3-any.pkg.tar calamares-tools-0.1.0-1-any.pkg.tar.zst ckbcomp-1.227-2-any.pkg.tar"

        print_status "Copying Calamares configuration..."
        run_command_cyan "sudo cp -r calamares /etc/"

        print_status "Copying custom branding..."
        run_command_cyan "sudo cp -r claudemods /usr/share/calamares/branding/"

        # Ask user for configuration preference
        print_status "Configuration selection:"
        echo -e "${COLOR_GREEN}Choose Calamares mount configuration:${COLOR_RESET}"
        echo -e "${COLOR_GREEN}1) Default configuration${COLOR_RESET}"
        echo -e "${COLOR_GREEN}2) Custom configuration with new mounts and level 22 compression${COLOR_RESET}"
        echo -e "${COLOR_GREEN}Enter your choice (1 or 2): ${COLOR_RESET}"

        read -r config_choice

        if [[ "$config_choice" == "2" ]]; then
            print_status "Applying custom configuration with new mounts and level 22 compression..."
            run_command_cyan "sudo cp btrfs-custom-config /usr/share/calamares/modules"
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
    echo -en "${COLOR_GREEN}Progress: [${COLOR_RESET}"
    for ((i=0; i<50; i++)); do
        echo -en "${COLOR_YELLOW}=${COLOR_RESET}"
        sleep 0.05
    done
    echo -e "${COLOR_GREEN}] 100%${COLOR_RESET}"
    loading_complete=true
}

execute_installation() {
    while [[ "$loading_complete" == false ]]; do
        sleep 0.01
    done

    # Setup
    if ! setup_directories; then
        commands_completed=true
        return
    fi

    # Detect distribution
    print_status "Detecting distribution"
    if ! detect_distribution; then
        commands_completed=true
        return
    fi

    # Get current version before installation
    get_versions
    current_version="$current_version"

    # Conditional logic based on detected distribution
    if [[ "$detected_distro" == "arch" || "$detected_distro" == "cachyos" ]]; then
        if ! install_arch_cachyos; then
            print_error "Installation failed for Arch/CachyOS"
            commands_completed=true
            return
        fi
    else
        print_error "Unsupported distribution: $detected_distro"
        commands_completed=true
        return
    fi

    # Get final version information
    get_versions
    downloaded_version="$downloaded_version"
    installed_version="$installed_version"

    commands_completed=true
}

main() {
    echo -e "${COLOR_GREEN}Starting installation process...${COLOR_RESET}"

    # Start installation in background
    execute_installation &
    local installation_pid=$!

    # Show loading bar in main thread
    show_loading_bar

    # Wait for installation to complete
    while [[ "$commands_completed" == false ]]; do
        sleep 0.01
    done
    wait "$installation_pid"

    # Display summary with version information
    echo -e "${COLOR_GREEN}\nInstallation complete!${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Detected distro: $detected_distro${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Current version: $current_version${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Downloaded version: $downloaded_version${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Installed version: $installed_version${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Executables installed to: /usr/bin/${COLOR_RESET}"
    echo -e "${COLOR_GREEN}Configuration files in: /home/$USER/.config/cmi/${COLOR_RESET}"

    # Ask to launch
    echo -e "${COLOR_CYAN}\nLaunch now? (y/n): ${COLOR_RESET}"
    read -r response

    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        cd "/home/$USER" && ccd
    fi

    exit 0
}

# Run main function
main
