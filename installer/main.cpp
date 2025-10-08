#include <iostream>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <pthread.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <array>
#include <memory>
#include <string>
#include <vector>
#include <fstream>
#include <map>

#define COLOR_GREEN "\033[0;32m"
#define COLOR_YELLOW "\033[1;33m"
#define COLOR_RED "\033[0;31m"
#define COLOR_CYAN "\033[38;2;0;255;255m"
#define COLOR_RESET "\033[0m"

// Global variables
char detected_distro[64] = "";
bool commands_completed = false;
bool loading_complete = false;
char current_version[64] = "unknown";
char downloaded_version[64] = "unknown";
char installed_version[64] = "unknown";

// Version Manager Class
class VersionManager {
private:
    std::string config_dir;
    std::string source_dir;

public:
    VersionManager() {
        config_dir = "/home/$USER/.config/cmi/";
        source_dir = "/mnt/claudemods/version/";
    }

    struct VersionInfo {
        std::string current;
        std::string downloaded;
        std::string installed;
    };

    VersionInfo getVersions() {
        VersionInfo info;
        info.current = readVersionFile(config_dir + "version.txt");
        info.downloaded = readVersionFile(source_dir + "version.txt");
        info.installed = info.downloaded;
        return info;
    }

    void updateInstalledVersion() {
        std::string cmd = "cp \"" + source_dir + "version.txt\" \"" + config_dir + "version.txt\"";
        system(cmd.c_str());
    }

private:
    std::string readVersionFile(const std::string& path) {
        std::ifstream file(path);
        if (file.good()) {
            std::string version;
            std::getline(file, version);
            return version.empty() ? "unknown" : version;
        }
        return "not installed";
    }
};

// Utility Functions
void print_color(const char* color, const std::string& message) {
    std::cout << color << message << COLOR_RESET << std::endl;
}

void print_status(const std::string& message) {
    print_color(COLOR_GREEN, "[INFO] " + message);
}

void print_warning(const std::string& message) {
    print_color(COLOR_YELLOW, "[WARNING] " + message);
}

void print_error(const std::string& message) {
    print_color(COLOR_RED, "[ERROR] " + message);
}

std::string run_command(const char* cmd) {
    std::array<char, 128> buffer;
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd, "r"), pclose);
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
        result += buffer.data();
    }
    if (!result.empty() && result.back() == '\n') {
        result.pop_back();
    }
    return result;
}

int run_command_cyan(const char* cmd) {
    std::cout << COLOR_CYAN;
    int result = system(cmd);
    std::cout << COLOR_RESET;
    return result;
}

void silent_command(const char* cmd) {
    char full_cmd[512];
    snprintf(full_cmd, sizeof(full_cmd), "%s >/dev/null 2>&1", cmd);
    system(full_cmd);
}

bool detect_distribution() {
    if (access("/etc/os-release", F_OK) != 0) {
        print_error("Cannot detect the distribution. Exiting.");
        return false;
    }

    try {
        std::string distro_output = run_command("cat /etc/os-release | grep '^ID=' | cut -d'=' -f2 | tr -d '\\\"'");
        strncpy(detected_distro, distro_output.c_str(), sizeof(detected_distro) - 1);
        return true;
    } catch (...) {
        print_error("Failed to read distribution information.");
        return false;
    }
}

bool setup_directories() {
    print_status("Setting up directories");
    silent_command("cd /home/$USER >/dev/null 2>&1");
    silent_command("mkdir -p /home/$USER/.config/cmi >/dev/null 2>&1");
    return true;
}

bool download_with_wait() {
    print_status("Starting download... This may take several minutes.");

    // Remove existing files first
    run_command_cyan("sudo rm -rf /home/$USER/.config/cmi/codex-files.img");
    run_command_cyan("sudo rm -rf /home/$USER/codex-files.img.xz");
    run_command_cyan("sudo rm -rf '/home/$USER/download?id=1yzRPvHfvcqQh5FnqPCjRNqjKlRzaemDq'");

    // Download with explicit wait - use system() directly without backgrounding
    std::cout << COLOR_CYAN;
    print_status("Downloading file from Google Drive...");
    int result = system("cd /home/$USER && wget --show-progress --no-check-certificate 'https://drive.usercontent.google.com/download?id=1yzRPvHfvcqQh5FnqPCjRNqjKlRzaemDq&export=download&authuser=0&confirm=t&uuid=cb571b39-a0a0-4d03-b8d9-2f3b605aaeb9&at=AKSUxGNWz75j3Sq6erlvb25_J9cr:1759936706590'  >/dev/null 2>&1");
    std::cout << COLOR_RESET;

    if (result != 0) {
        print_error("Download failed!");
        return false;
    }

    print_status("Download completed successfully!");
    return true;
}

bool install_arch_cachyos() {
    // Commands for Arch/CachyOS

    // FIXED: Download first and wait for completion
    if (!download_with_wait()) {
        return false;
    }

    // Now continue with the rest of the commands
    run_command_cyan("cd /home/$USER && mv download* /home/$USER/codex-files.img.xz");
    run_command_cyan("mkdir /home/$USER/.config/cmi >/dev/null 2>&1");
    run_command_cyan("cd /home/$USER/ && sudo unxz codex-files.img.xz");
    run_command_cyan("cd /home/$USER/ && sudo mv codex-files.img /home/$USER/.config/cmi");
    run_command_cyan("cd /home/$USER/.config/cmi");
    run_command_cyan("sudo mkdir -p /mnt/claudemods");

    // Handle loop device mounting
    std::string loop_dev = run_command("sudo losetup --find --show /home/$USER/.config/cmi/codex-files.img | tr -d '\\n'");
    if (!loop_dev.empty()) {
        std::string mount_cmd = "sudo mount -o compress=zstd:22,subvol=codex-files \"" + loop_dev + "\" /mnt/claudemods";
        run_command_cyan(mount_cmd.c_str());
    }

    std::string current_user = run_command("whoami");
    std::string chown_cmd = "sudo chown \"" + current_user + ":" + current_user + "\" /mnt/claudemods";
    run_command_cyan(chown_cmd.c_str());

    run_command_cyan("cd /mnt/claudemods/working-hooks-btrfs-ext4 && sudo cp -r * /etc/initcpio");
    run_command_cyan("cd /mnt/claudemods && sudo cp -r build-image-arch-img /home/$USER/.config/cmi");

    // Version management
    VersionManager vm;
    vm.updateInstalledVersion();

    run_command_cyan("cd /mnt/claudemods/cmi && qmake6 && make");
    run_command_cyan("sudo cp /mnt/claudemods/cmi/cmiimg /usr/bin/cmiimg");
    run_command_cyan("cd /mnt/claudemods/rsyncinstaller && qmake6 && make");
    run_command_cyan("sudo cp cmirsyncinstaller /usr/bin/cmirsyncinstaller");
    run_command_cyan("sudo cp /mnt/claudemods/btrfssystemcloner/btrfssystemcloner /usr/bin/btrfssystemcloner");
    run_command_cyan("sudo cp /mnt/claudemods/ccd/ccd /usr/bin/ccd");
    run_command_cyan("sudo pacman -Sy");

    print_status("Installing dependencies");
    run_command_cyan("sudo pacman -S --needed --noconfirm git rsync squashfs-tools xorriso grub dosfstools unzip nano arch-install-scripts bash-completion erofs-utils findutils jq libarchive libisoburn lsb-release lvm2 mkinitcpio-archiso mkinitcpio-nfs-utils mtools nbd pacman-contrib parted procps-ng pv python sshfs syslinux xdg-utils zsh-completions kernel-modules-hook virt-manager qt6-tools btrfs-progs e2fsprogs f2fs-tools xfsprogs xfsdump cmake");

    // Ask user if they want to install Calamares
    std::cout << COLOR_GREEN << "Do you want to install Calamares? (y/n): " << COLOR_RESET;
    char response;
    std::cin >> response;

    if (response == 'y' || response == 'Y') {
        print_status("Starting Calamares installation and configuration...");


        print_status("Installing Calamares packages...");
        run_command_cyan("cd /mnt/claudemods/calamares-files && sudo pacman -U --noconfirm --overwrite=\"*\" calamares-3.4.0-1-x86_64.pkg.tar.zst calamares-oem-kde-settings-20240616-3-any.pkg.tar calamares-tools-0.1.0-1-any.pkg.tar.zst ckbcomp-1.227-2-any.pkg.tar");

        print_status("Copying Calamares configuration...");
        run_command_cyan("cd /mnt/claudemods/calamares-files && sudo cp -r calamares /etc/");

        print_status("Copying custom branding...");
        run_command_cyan("cd /mnt/claudemods/calamares-files && sudo cp -r claudemods /usr/share/calamares/branding/");

        // Ask user for configuration preference
        print_status("Configuration selection:");
        std::cout << COLOR_GREEN << "Choose Calamares mount configuration:" << COLOR_RESET << std::endl;
        std::cout << COLOR_GREEN << "1) Default configuration" << COLOR_RESET << std::endl;
        std::cout << COLOR_GREEN << "2) Custom configuration with new mounts and level 22 compression" << COLOR_RESET << std::endl;
        std::cout << COLOR_GREEN << "Enter your choice (1 or 2): " << COLOR_RESET;

        int config_choice;
        std::cin >> config_choice;

        if (config_choice == 2) {
            print_status("Applying custom configuration with new mounts and level 22 compression...");
            run_command_cyan("cd /mnt/claudemods/calamares-files/btrfs-custom-config && sudo cp btrfs-custom-config /usr/share/calamares/modules");
            print_status("Custom configuration applied successfully!");
        } else {
            print_status("Using default Calamares configuration.");
            print_status("Skipping custom mount configuration.");
        }

        print_status("Installing Hooks And My Rsync Installer");
        run_command_cyan("sudo rm -rf /usr/share/calamares/branding/manjaro");

        print_status("Calamares installation and configuration completed!");
    }

    run_command_cyan("cd /mnt/claudemods");

    run_command_cyan("sudo rm -rf codex-files.img.xz");
    run_command_cyan("sudo rm -rf /home/$USER/claudemods-multi-iso-konsole-script-extras");

    return true;
}

void show_loading_bar() {
    std::cout << COLOR_GREEN << "Progress: [" << COLOR_RESET;
    for (int i = 0; i < 50; i++) {
        std::cout << COLOR_YELLOW << "=" << COLOR_RESET;
        std::cout.flush();
        usleep(50000);
    }
    std::cout << COLOR_GREEN << "] 100%\n" << COLOR_RESET;
    loading_complete = true;
}

void* execute_installation_thread(void* /*arg*/) {
    while (!loading_complete) usleep(10000);

    // Setup
    if (!setup_directories()) {
        commands_completed = true;
        return nullptr;
    }

    // Detect distribution
    print_status("Detecting distribution");
    if (!detect_distribution()) {
        commands_completed = true;
        return nullptr;
    }

    // Get current version before installation
    VersionManager vm;
    auto versions = vm.getVersions();
    strncpy(current_version, versions.current.c_str(), sizeof(current_version) - 1);

    // Conditional logic based on detected distribution
    if (strcmp(detected_distro, "arch") == 0 || strcmp(detected_distro, "cachyos") == 0) {
        if (!install_arch_cachyos()) {
            print_error("Installation failed for Arch/CachyOS");
            commands_completed = true;
            return nullptr;
        }
    } else {
        print_error(std::string("Unsupported distribution: ") + detected_distro);
        commands_completed = true;
        return nullptr;
    }

    // Get final version information
    versions = vm.getVersions();
    strncpy(downloaded_version, versions.downloaded.c_str(), sizeof(downloaded_version) - 1);
    strncpy(installed_version, versions.installed.c_str(), sizeof(installed_version) - 1);

    commands_completed = true;
    return nullptr;
}

int main() {
    pthread_t thread;

    std::cout << COLOR_GREEN << "Starting installation process..." << COLOR_RESET << std::endl;

    // Start installation thread
    pthread_create(&thread, nullptr, execute_installation_thread, nullptr);

    // Show loading bar in main thread
    show_loading_bar();

    // Wait for installation to complete
    while (!commands_completed) usleep(10000);
    pthread_join(thread, nullptr);

    // Display summary with version information
    std::cout << COLOR_GREEN << "\nInstallation complete!\n" << COLOR_RESET;
    std::cout << COLOR_GREEN << "Detected distro: " << detected_distro << COLOR_RESET << std::endl;
    std::cout << COLOR_GREEN << "Current version: " << current_version << COLOR_RESET << std::endl;
    std::cout << COLOR_GREEN << "Downloaded version: " << downloaded_version << COLOR_RESET << std::endl;
    std::cout << COLOR_GREEN << "Installed version: " << installed_version << COLOR_RESET << std::endl;
    std::cout << COLOR_GREEN << "Executables installed to: /usr/bin/\n" << COLOR_RESET;
    std::cout << COLOR_GREEN << "Configuration files in: /home/$USER/.config/cmi/\n" << COLOR_RESET;

    // Ask to launch
    std::cout << COLOR_CYAN << "\nLaunch now? (y/n): " << COLOR_RESET;
    char response;
    std::cin >> response;

    if (response == 'y' || response == 'Y') {
        system("cd /home/$USER && ccd");
    }

    return EXIT_SUCCESS;
}
