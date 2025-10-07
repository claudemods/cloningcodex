#include <iostream>
#include <cstdlib>
#include <string>

void playAudio() {
    system("play codex.mp3 > /dev/null 2>&1 &");
}

void executeCMIImg() {
    std::cout << "\033[38;2;0;255;255m";
    std::cout << "Executing CMI IMG ISO Creator v2.04..." << std::endl;
    system("cmiimg");
}

void executeBTRFSSystemCloner() {
    std::cout << "\033[38;2;0;255;255m";
    std::cout << "Executing BTRFS System Cloner v1.02..." << std::endl;
    system("btrfssystemcloner");
}

void displayHeader() {
    // Set color to red for ASCII art
    std::cout << "\033[1;31m";

    std::cout << R"(
░█████╗░██╗░░░░░░█████╗░██╗░░░██╗██████╗░███████╗███╗░░░███╗░█████╗░██████╗░░██████╗
██╔══██╗██║░░░░░██╔══██╗██║░░░██║██╔══██╗██╔════╝████╗░████║██╔══██╗██╔══██╗██╔════╝
██║░░╚═╝██║░░░░░███████║██║░░░██║██║░░██║█████╗░░██╔████╔██║██║░░██║██║░░██║╚█████╗░
██║░░██╗██║░░░░░██╔══██║██║░░░██║██║░░██║██╔══╝░░██║╚██╔╝██║██║░░██║██║░░██║░╚═══██╗
╚█████╔╝███████╗██║░░██║╚██████╔╝██████╔╝███████╗██║░╚═╝░██║╚█████╔╝██████╔╝██████╔╝
░╚════╝░╚══════╝╚═╝░░░░░░╚═════╝░╚══════╝░╚══════╝╚═╝░░░░░╚═╝░╚════╝░╚═════╝░╚═════╝░
)" << std::endl;

// Set color to cyan for the text
std::cout << "\033[38;2;0;255;255m";
std::cout << "claudemods cloning codex v1.0 07-10-2025" << std::endl;
std::cout << std::endl;
std::cout << "\033[0m";
}

void displayMenu() {
    std::cout << "\033[38;2;0;255;255m";
    std::cout << "==========================================" << std::endl;
    std::cout << "           MAIN MENU" << std::endl;
    std::cout << "==========================================" << std::endl;
    std::cout << "1. CMI IMG ISO Creator v2.04" << std::endl;
    std::cout << "2. BTRFS System Cloner v2.0" << std::endl;
    std::cout << "3. Exit" << std::endl;
    std::cout << "==========================================" << std::endl;
    std::cout << "Enter your choice (1-3): ";
    std::cout << "\033[0m";
}

int main() {
    // Play audio in background at start
    playAudio();

    int choice;

    while (true) {
        // Clear screen
        system("clear");

        // Display header
        displayHeader();

        // Display menu
        displayMenu();

        // Get user input
        std::cin >> choice;

        // Process user choice
        switch (choice) {
            case 1:
                executeCMIImg();
                break;
            case 2:
                executeBTRFSSystemCloner();
                break;
            case 3:
                std::cout << "Exiting..." << std::endl;
                return 0;
            default:
                std::cout << "Invalid choice! Please try again." << std::endl;
                std::cout << "Press Enter to continue...";
                std::cin.ignore();
                std::cin.get();
                break;
        }

        // Wait for user to press Enter before showing menu again
        if (choice == 1 || choice == 2) {
            std::cout << std::endl << "Press Enter to return to menu...";
            std::cin.ignore();
            std::cin.get();
        }
    }

    return 0;
}
