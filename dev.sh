#!/bin/bash

# Script d'installation universelle pour développeurs Linux
# Compatible avec Arch/Manjaro, Ubuntu/Debian, Fedora, openSUSE
# Auteur: PapaOursPolaire - GitHub
# Version: 45.0

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables globales
DISTRO=""
PACKAGE_MANAGER=""
AUR_HELPER=""
FLATPAK_AVAILABLE=false

# Fonction pour afficher un message coloré
print_message() {
    echo -e "${2}${1}${NC}"
}

# Fonction pour afficher un titre de section
print_section() {
    echo ""
    print_message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$BLUE" 
    print_message "$1" "$CYAN"
    print_message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$BLUE"
    echo ""
}

# Fonction pour demander confirmation
ask_install() {
    local package_name="$1"
    local description="$2"
    
    while true; do
        echo -n -e "${YELLOW}Installer ${package_name}${NC}"
        if [ -n "$description" ]; then
            echo -n -e " ${PURPLE}($description)${NC}"
        fi
        echo -n "? [O/n]: "
        read -r choice
        case "$choice" in
            [Oo]|[Oo][Uu][Ii]|"") return 0 ;;
            [Nn]|[Nn][Oo][Nn]) return 1 ;;
            *) echo "Répondez par O (oui) ou N (non)" ;;
        esac
    done
}

# Détection de la distribution
detect_distro() {
    print_message "🔍 Détection de la distribution..." "$BLUE"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            arch|manjaro|endeavouros|artix)
                DISTRO="arch"
                if command -v paru >/dev/null 2>&1; then
                    AUR_HELPER="paru"
                elif command -v yay >/dev/null 2>&1; then
                    AUR_HELPER="yay"
                else
                    PACKAGE_MANAGER="pacman"
                fi
                ;;
            ubuntu|debian|linuxmint|elementary|pop)
                DISTRO="debian"
                PACKAGE_MANAGER="apt"
                ;;
            fedora|centos|rhel|rocky|almalinux)
                DISTRO="fedora"
                PACKAGE_MANAGER="dnf"
                ;;
            opensuse*|sles)
                DISTRO="opensuse"
                PACKAGE_MANAGER="zypper"
                ;;
            *)
                print_message "⚠️  Distribution non reconnue: $ID" "$RED"
                print_message "Le script tentera d'utiliser les gestionnaires de paquets disponibles" "$YELLOW"
                ;;
        esac
    fi
    
    # Vérification de Flatpak
    if command -v flatpak >/dev/null 2>&1; then
        FLATPAK_AVAILABLE=true
    fi
    
    print_message "✅ Distribution détectée: $DISTRO" "$GREEN"
    if [ -n "$AUR_HELPER" ]; then
        print_message "✅ Helper AUR détecté: $AUR_HELPER" "$GREEN"
    elif [ -n "$PACKAGE_MANAGER" ]; then
        print_message "✅ Gestionnaire de paquets: $PACKAGE_MANAGER" "$GREEN"
    fi
    
    if $FLATPAK_AVAILABLE; then
        print_message "✅ Flatpak disponible" "$GREEN"
    fi
}

# Installation selon la distribution
install_package() {
    local package="$1"
    local flatpak_package="$2"
    local description="$3"
    
    print_message "📦 Installation de $package..." "$BLUE"
    
    case "$DISTRO" in
        arch)
            if [ -n "$AUR_HELPER" ]; then
                $AUR_HELPER -S --noconfirm "$package" || {
                    print_message "❌ Échec d'installation via $AUR_HELPER" "$RED"
                    return 1
                }
            else
                sudo pacman -S --noconfirm "$package" || {
                    print_message "❌ Échec d'installation via pacman" "$RED"
                    return 1
                }
            fi
            ;;
        debian)
            sudo apt update && sudo apt install -y "$package" || {
                if [ -n "$flatpak_package" ] && $FLATPAK_AVAILABLE; then
                    print_message "⚠️  Tentative via Flatpak..." "$YELLOW"
                    flatpak install -y flathub "$flatpak_package" || return 1
                else
                    return 1
                fi
            }
            ;;
        fedora)
            sudo dnf install -y "$package" || {
                if [ -n "$flatpak_package" ] && $FLATPAK_AVAILABLE; then
                    print_message "⚠️  Tentative via Flatpak..." "$YELLOW"
                    flatpak install -y flathub "$flatpak_package" || return 1
                else
                    return 1
                fi
            }
            ;;
        opensuse)
            sudo zypper install -y "$package" || {
                if [ -n "$flatpak_package" ] && $FLATPAK_AVAILABLE; then
                    print_message "⚠️  Tentative via Flatpak..." "$YELLOW"
                    flatpak install -y flathub "$flatpak_package" || return 1
                else
                    return 1
                fi
            }
            ;;
    esac
    
    print_message "✅ $package installé avec succès" "$GREEN"
}

# Installation via Flatpak uniquement
install_flatpak() {
    local package="$1"
    local description="$2"
    
    if ! $FLATPAK_AVAILABLE; then
        print_message "❌ Flatpak non disponible pour $package" "$RED"
        return 1
    fi
    
    print_message "📦 Installation de $package via Flatpak..." "$BLUE"
    flatpak install -y flathub "$package" || {
        print_message "❌ Échec d'installation de $package" "$RED"
        return 1
    }
    print_message "✅ $package installé avec succès" "$GREEN"
}

# Installation Node.js avec NVM
install_nodejs() {
    print_message "📦 Installation de Node.js via NVM..." "$BLUE"
    
    # Installation de NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Installation de la dernière version LTS de Node.js
    nvm install --lts
    nvm use --lts
    nvm alias default node
    
    print_message "✅ Node.js installé avec succès" "$GREEN"
}

# Installation des extensions VS Code
install_vscode_extensions() {
    print_message "📦 Installation des extensions VS Code..." "$BLUE"
    
    extensions=(
        "ms-python.python"
        "ms-vscode.cpptools"
        "redhat.java"
        "golang.go"
        "rust-lang.rust-analyzer"
        "esbenp.prettier-vscode"
        "dbaeumer.vscode-eslint"
        "bradlc.vscode-tailwindcss"
        "ritwickdey.liveserver"
        "formulahendry.auto-rename-tag"
        "formulahendry.auto-close-tag"
        "ms-azuretools.vscode-docker"
        "ms-toolsai.jupyter"
        "ms-vscode.makefile-tools"
        "ms-vscode.cmake-tools"
        "eamodio.gitlens"
        "mhutchie.git-graph"
        "donjayamanne.githistory"
        "aaron-bond.better-comments"
        "usernamehw.errorlens"
        "gruntfuggly.todo-tree"
        "streetsidesoftware.code-spell-checker"
        "pkief.material-icon-theme"
        "dracula-theme.theme-dracula"
        "zhuangtongfa.material-theme"
        "rocketseat.theme-omni"
        "yzhang.markdown-all-in-one"
        "shd101wyy.markdown-preview-enhanced"
        "vscjava.vscode-java-pack"
        "github.copilot"
        "ms-vscode.cpptools-extension-pack"
        "codeium.codeium"
        "amazonwebservices.aws-toolkit-vscode"
        "rangav.vscode-thunder-client"
        "humao.rest-client"
        "johnpapa.vscode-peacock"
        "vscode-icons-team.vscode-icons"
        "coenraads.bracket-pair-colorizer-2"
        "formulahendry.code-runner"
        "tabnine.tabnine-vscode"
        "hediet.vscode-drawio"
    )
    
    for ext in "${extensions[@]}"; do
        print_message "Installing extension: $ext" "$BLUE"
        code --install-extension "$ext" --force
    done
    
    print_message "✅ Extensions VS Code installées" "$GREEN"
}

# Configuration de Flatpak
setup_flatpak() {
    if ask_install "Flatpak + Flathub" "Gestionnaire de paquets universel"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm flatpak
                else
                    sudo pacman -S --noconfirm flatpak
                fi
                ;;
            debian)
                sudo apt install -y flatpak
                ;;
            fedora)
                # Flatpak est préinstallé sur Fedora
                ;;
            opensuse)
                sudo zypper install -y flatpak
                ;;
        esac
        
        # Ajout du dépôt Flathub
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        FLATPAK_AVAILABLE=true
        print_message "✅ Flatpak configuré avec Flathub" "$GREEN"
    fi
}

# Script principal
main() {
    print_message "🚀 Script d'installation pour développeurs Linux" "$PURPLE"
    print_message "Ce script va installer tous les outils nécessaires au développement" "$CYAN"
    echo ""
    
    # Mise à jour du système
    print_message "🔄 Mise à jour du système..." "$BLUE"
    case "$DISTRO" in
        arch)
            sudo pacman -Syu --noconfirm
            ;;
        debian)
            sudo apt update && sudo apt upgrade -y
            ;;
        fedora)
            sudo dnf upgrade -y
            ;;
        opensuse)
            sudo zypper refresh && sudo zypper update -y
            ;;
    esac
    
    # Configuration de Flatpak si nécessaire
    if ! $FLATPAK_AVAILABLE; then
        setup_flatpak
    fi
    
    # ==========================================
    # DÉVELOPPEMENT
    # ==========================================
    print_section "🛠️  OUTILS DE DÉVELOPPEMENT"
    
    # Git et Git LFS
    if ask_install "Git" "Contrôle de version"; then
        install_package "git" "" "Système de contrôle de version"
    fi
    
    if ask_install "Git LFS" "Support des gros fichiers Git"; then
        case "$DISTRO" in
            arch) install_package "git-lfs" ;;
            debian) install_package "git-lfs" ;;
            fedora) install_package "git-lfs" ;;
            opensuse) install_package "git-lfs" ;;
        esac
    fi
    
    # Docker
    if ask_install "Docker" "Conteneurisation"; then
        case "$DISTRO" in
            arch)
                install_package "docker"
                sudo systemctl enable docker
                sudo usermod -aG docker $USER
                ;;
            debian)
                # Installation via le dépôt officiel Docker
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt update
                sudo apt install -y docker-ce docker-ce-cli containerd.io
                sudo usermod -aG docker $USER
                ;;
            fedora)
                sudo dnf install -y docker-ce docker-ce-cli containerd.io
                sudo systemctl enable docker
                sudo usermod -aG docker $USER
                ;;
            opensuse)
                sudo zypper install -y docker
                sudo systemctl enable docker
                sudo usermod -aG docker $USER
                ;;
        esac
    fi
    
    if ask_install "Docker Compose" "Orchestration de conteneurs"; then
        case "$DISTRO" in
            arch) install_package "docker-compose" ;;
            debian) install_package "docker-compose-plugin" ;;
            fedora) install_package "docker-compose-plugin" ;;
            opensuse) install_package "docker-compose" ;;
        esac
    fi
    
    # Éditeurs de code
    if ask_install "Visual Studio Code" "Éditeur de code Microsoft"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm visual-studio-code-bin
                fi
                ;;
            debian)
                wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
                sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
                sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
                sudo apt update
                sudo apt install -y code
                ;;
            fedora)
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
                sudo dnf install -y code
                ;;
            opensuse)
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                sudo zypper addrepo https://packages.microsoft.com/yumrepos/vscode vscode
                sudo zypper install -y code
                ;;
        esac
        
        # Installation des extensions VS Code
        if ask_install "Extensions VS Code" "Toutes les extensions recommandées"; then
            install_vscode_extensions
        fi
    fi
    
    if ask_install "VSCodium" "Version libre de VS Code"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm vscodium-bin
                fi
                ;;
            debian)
                wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor | sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg
                echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' | sudo tee /etc/apt/sources.list.d/vscodium.list
                sudo apt update
                sudo apt install -y codium
                ;;
            *) install_flatpak "com.vscodium.codium" "Version libre de VS Code" ;;
        esac
    fi
    
    if ask_install "Neovim" "Éditeur de texte avancé"; then
        install_package "neovim" "" "Éditeur de texte modal"
    fi
    
    if ask_install "Micro" "Éditeur de texte simple"; then
        install_package "micro" "" "Éditeur de texte moderne"
    fi
    
    if ask_install "Helix" "Éditeur de texte modal moderne"; then
        case "$DISTRO" in
            arch) install_package "helix" ;;
            *) 
                # Installation via cargo si disponible
                if command -v cargo >/dev/null 2>&1; then
                    cargo install helix-term
                else
                    print_message "⚠️  Helix nécessite Rust/Cargo ou installation manuelle" "$YELLOW"
                fi
                ;;
        esac
    fi
    
    # Terminaux
    if ask_install "Kitty" "Émulateur de terminal moderne"; then
        install_package "kitty" "" "Terminal avec support GPU"
    fi
    
    if ask_install "Terminator" "Terminal avec support de division"; then
        install_package "terminator" "" "Terminal multi-panneaux"
    fi
    
    if ask_install "Alacritty" "Terminal accéléré GPU"; then
        install_package "alacritty" "" "Terminal haute performance"
    fi
    
    # Langages de programmation
    if ask_install "Node.js & NPM" "Runtime JavaScript"; then
        install_nodejs
    fi
    
    if ask_install "Python & Pip" "Langage Python"; then
        case "$DISTRO" in
            arch) install_package "python python-pip" ;;
            debian) install_package "python3 python3-pip" ;;
            fedora) install_package "python3 python3-pip" ;;
            opensuse) install_package "python3 python3-pip" ;;
        esac
    fi
    
    if ask_install "Go" "Langage Go"; then
        case "$DISTRO" in
            arch) install_package "go" ;;
            debian) install_package "golang-go" ;;
            fedora) install_package "golang" ;;
            opensuse) install_package "go" ;;
        esac
    fi
    
    if ask_install "Rust" "Langage Rust"; then
        case "$DISTRO" in
            arch) install_package "rust" ;;
            debian) install_package "rustc" ;;
            fedora) install_package "rust cargo" ;;
            opensuse) install_package "rust cargo" ;;
        esac
    fi
    
    if ask_install "Java OpenJDK" "Machine virtuelle Java"; then
        case "$DISTRO" in
            arch) install_package "jdk-openjdk" ;;
            debian) install_package "openjdk-17-jdk" ;;
            fedora) install_package "java-17-openjdk-devel" ;;
            opensuse) install_package "java-17-openjdk-devel" ;;
        esac
    fi
    
    if ask_install ".NET SDK" "Framework Microsoft .NET"; then
        case "$DISTRO" in
            arch) install_package "dotnet-sdk" ;;
            debian) 
                wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
                sudo dpkg -i packages-microsoft-prod.deb
                sudo apt update
                sudo apt install -y dotnet-sdk-7.0
                ;;
            fedora) sudo dnf install -y dotnet-sdk-7.0 ;;
            opensuse) sudo zypper install -y dotnet-sdk-7.0 ;;
        esac
    fi
    
    # Outils de compilation
    if ask_install "Outils de compilation" "GCC, G++, Clang, Make, CMake"; then
        case "$DISTRO" in
            arch) install_package "gcc make cmake clang gdb" ;;
            debian) install_package "build-essential cmake clang gdb" ;;
            fedora) install_package "gcc gcc-c++ make cmake clang gdb" ;;
            opensuse) install_package "gcc gcc-c++ make cmake clang gdb" ;;
        esac
    fi
    
    # Outils de développement
    if ask_install "Postman" "Client API"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm postman-bin
                fi
                ;;
            *) install_flatpak "com.getpostman.Postman" "Client API" ;;
        esac
    fi
    
    if ask_install "SQLite Browser" "Explorateur de base de données SQLite"; then
        case "$DISTRO" in
            arch) install_package "sqlitebrowser" ;;
            debian) install_package "sqlitebrowser" ;;
            fedora) install_package "sqlitebrowser" ;;
            opensuse) install_package "sqlitebrowser" ;;
        esac
    fi
    
    if ask_install "Docker Desktop" "Interface graphique Docker"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm docker-desktop
                fi
                ;;
            debian)
                wget https://desktop.docker.com/linux/main/amd64/docker-desktop-4.21.1-amd64.deb
                sudo apt install -y ./docker-desktop-4.21.1-amd64.deb
                ;;
            *) print_message "⚠️  Docker Desktop non disponible pour cette distribution" "$YELLOW" ;;
        esac
    fi
    
    if ask_install "Lazygit" "Interface Git en terminal"; then
        case "$DISTRO" in
            arch) install_package "lazygit" ;;
            debian) 
                # Installation via GitHub release
                LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
                curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
                tar xf lazygit.tar.gz lazygit
                sudo install lazygit /usr/local/bin
                ;;
            fedora) install_package "lazygit" ;;
            opensuse) install_package "lazygit" ;;
        esac
    fi
    
    # Moniteurs système
    if ask_install "btop" "Moniteur système moderne"; then
        install_package "btop" "" "Moniteur système avec interface moderne"
    fi
    
    if ask_install "htop" "Moniteur système classique"; then
        install_package "htop" "" "Moniteur système interactif"
    fi
    
    # ==========================================
    # OUTILS DE PRISE DE NOTES
    # ==========================================
    print_section "📝 OUTILS DE PRISE DE NOTES"
    
    if ask_install "Obsidian" "Prise de notes avec liens"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm obsidian
                fi
                ;;
            *) install_flatpak "md.obsidian.Obsidian" "Prise de notes avec liens" ;;
        esac
    fi
    
    if ask_install "Joplin" "Application de notes open source"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm joplin-appimage
                fi
                ;;
            *) install_flatpak "net.cozic.joplin_desktop" "Application de notes" ;;
        esac
    fi
    
    # ==========================================
    # BUREAU ET UTILITAIRES SYSTÈME
    # ==========================================
    print_section "🖥️  BUREAU ET UTILITAIRES SYSTÈME"
    
    if ask_install "GNOME Tweaks" "Personnalisation GNOME" && command -v gnome-shell >/dev/null 2>&1; then
        install_package "gnome-tweaks" "" "Outil de personnalisation GNOME"
    fi
    
    if ask_install "Stacer" "Optimiseur système"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm stacer
                fi
                ;;
            *) install_flatpak "com.oguzhaninan.Stacer" "Optimiseur système" ;;
        esac
    fi
    
    if ask_install "BleachBit" "Nettoyeur système"; then
        install_package "bleachbit" "" "Nettoyeur de fichiers système"
    fi
    
    if ask_install "Timeshift" "Sauvegarde système"; then
        case "$DISTRO" in
            arch) install_package "timeshift" ;;
            debian) install_package "timeshift" ;;
            fedora) install_package "timeshift" ;;
            opensuse) install_package "timeshift" ;;
        esac
    fi
    
    if ask_install "GParted" "Gestionnaire de partitions"; then
        install_package "gparted" "" "Éditeur de partitions graphique"
    fi
    
    if ask_install "ULauncher" "Lanceur d'applications"; then
        case "$DISTRO" in
            arch) install_package "ulauncher" ;;
            debian) install_package "ulauncher" ;;
            fedora) install_package "ulauncher" ;;
            opensuse) install_package "ulauncher" ;;
        esac
    fi
    
    if ask_install "Flameshot" "Capture d'écran"; then
        install_package "flameshot" "" "Outil de capture d'écran"
    fi
    
    # ==========================================
    # INTERNET ET COMMUNICATION
    # ==========================================
    print_section "🌐 INTERNET ET COMMUNICATION"
    
    if ask_install "Firefox" "Navigateur web Mozilla"; then
        install_package "firefox" "org.mozilla.firefox" "Navigateur web"
    fi
    
    if ask_install "LibreWolf" "Firefox axé sur la vie privée"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm librewolf-bin
                fi
                ;;
            *) install_flatpak "io.gitlab.librewolf-community" "Firefox axé sur la vie privée" ;;
        esac
    fi
    
    if ask_install "Brave Browser" "Navigateur axé sur la vie privée"; then
        case "$DISTRO" in
            arch) install_package "brave-bin" ;;
            debian)
                sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
                echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
                sudo apt update
                sudo apt install -y brave-browser
                ;;
            fedora)
                sudo dnf install -y dnf-plugins-core
                sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/x86_64/
                sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
                sudo dnf install -y brave-browser
                ;;
            *) install_flatpak "com.brave.Browser" "Navigateur Brave" ;;
        esac
    fi
    
    if ask_install "Chromium" "Navigateur open source"; then
        install_package "chromium" "org.chromium.Chromium" "Navigateur Chromium"
    fi
    
    if ask_install "Google Chrome" "Navigateur Google"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm google-chrome
                fi
                ;;
            debian)
                wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
                echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
                sudo apt update
                sudo apt install -y google-chrome-stable
                ;;
            fedora)
                sudo dnf install -y fedora-workstation-repositories
                sudo dnf config-manager --set-enabled google-chrome
                sudo dnf install -y google-chrome-stable
                ;;
            opensuse)
                wget https://dl.google.com/linux/linux_signing_key.pub
                sudo rpm --import linux_signing_key.pub
                sudo zypper addrepo http://dl.google.com/linux/chrome/rpm/stable/x86_64 Google-Chrome
                sudo zypper install -y google-chrome-stable
                ;;
        esac
    fi
    
    if ask_install "DuckDuckGo Browser" "Navigateur axé sur la vie privée"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm duckduckgo-privacy-browser
                fi
                ;;
            *) 
                print_message "⚠️  DuckDuckGo Browser disponible principalement sur mobile" "$YELLOW"
                print_message "💡 Configurez DuckDuckGo comme moteur de recherche par défaut dans votre navigateur" "$CYAN"
                ;;
        esac
    fi
    
    if ask_install "Discord" "Communication gaming"; then
        case "$DISTRO" in
            arch) install_package "discord" ;;
            *) install_flatpak "com.discordapp.Discord" "Communication gaming" ;;
        esac
    fi
    
    if ask_install "Signal" "Messagerie sécurisée"; then
        case "$DISTRO" in
            arch) install_package "signal-desktop" ;;
            *) install_flatpak "org.signal.Signal" "Messagerie sécurisée" ;;
        esac
    fi
    
    if ask_install "Telegram" "Messagerie instantanée"; then
        case "$DISTRO" in
            arch) install_package "telegram-desktop" ;;
            *) install_flatpak "org.telegram.desktop" "Messagerie instantanée" ;;
        esac
    fi
    
    if ask_install "Element" "Client Matrix"; then
        case "$DISTRO" in
            arch) install_package "element-desktop" ;;
            *) install_flatpak "im.riot.Riot" "Client Matrix" ;;
        esac
    fi
    
    if ask_install "Slack" "Communication professionnelle"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm slack-desktop
                fi
                ;;
            *) install_flatpak "com.slack.Slack" "Communication professionnelle" ;;
        esac
    fi
    
    if ask_install "Thunderbird" "Client email"; then
        install_package "thunderbird" "org.mozilla.Thunderbird" "Client de messagerie"
    fi
    
    # ==========================================
    # MULTIMÉDIA
    # ==========================================
    print_section "🎵 MULTIMÉDIA"
    
    if ask_install "VLC" "Lecteur multimédia universel"; then
        install_package "vlc" "org.videolan.VLC" "Lecteur multimédia"
    fi
    
    if ask_install "MPV" "Lecteur vidéo minimaliste"; then
        install_package "mpv" "" "Lecteur vidéo léger"
    fi
    
    if ask_install "DeaDBeeF" "Lecteur audio léger"; then
        case "$DISTRO" in
            arch) install_package "deadbeef" ;;
            *) install_flatpak "org.deadbeef.deadbeef" "Lecteur audio" ;;
        esac
    fi
    
    if ask_install "Lollypop" "Lecteur de musique moderne"; then
        case "$DISTRO" in
            arch) install_package "lollypop" ;;
            *) install_flatpak "org.gnome.Lollypop" "Lecteur de musique" ;;
        esac
    fi
    
    if ask_install "Kdenlive" "Éditeur vidéo professionnel"; then
        case "$DISTRO" in
            arch) install_package "kdenlive" ;;
            *) install_flatpak "org.kde.kdenlive" "Éditeur vidéo" ;;
        esac
    fi
    
    if ask_install "Shotcut" "Éditeur vidéo simple"; then
        case "$DISTRO" in
            arch) install_package "shotcut" ;;
            *) install_flatpak "org.shotcut.Shotcut" "Éditeur vidéo simple" ;;
        esac
    fi
    
    if ask_install "OBS Studio" "Enregistrement et streaming"; then
        case "$DISTRO" in
            arch) install_package "obs-studio" ;;
            *) install_flatpak "com.obsproject.Studio" "Enregistrement et streaming" ;;
        esac
    fi
    
    if ask_install "Audacity" "Éditeur audio"; then
        case "$DISTRO" in
            arch) install_package "audacity" ;;
            *) install_flatpak "org.audacityteam.Audacity" "Éditeur audio" ;;
        esac
    fi
    
    if ask_install "EasyEffects" "Processeur audio en temps réel"; then
        case "$DISTRO" in
            arch) install_package "easyeffects" ;;
            *) install_flatpak "com.github.wwmm.easyeffects" "Processeur audio" ;;
        esac
    fi
    
    if ask_install "Piper" "Configuration souris gaming"; then
        case "$DISTRO" in
            arch) install_package "piper" ;;
            *) install_flatpak "org.freedesktop.Piper" "Configuration souris gaming" ;;
        esac
    fi
    
    # ==========================================
    # DESIGN ET IMAGE
    # ==========================================
    print_section "🎨 DESIGN ET IMAGE"
    
    if ask_install "GIMP" "Éditeur d'image avancé"; then
        case "$DISTRO" in
            arch) install_package "gimp" ;;
            *) install_flatpak "org.gimp.GIMP" "Éditeur d'image" ;;
        esac
    fi
    
    if ask_install "Krita" "Peinture numérique"; then
        case "$DISTRO" in
            arch) install_package "krita" ;;
            *) install_flatpak "org.kde.krita" "Peinture numérique" ;;
        esac
    fi
    
    if ask_install "Inkscape" "Éditeur vectoriel"; then
        case "$DISTRO" in
            arch) install_package "inkscape" ;;
            *) install_flatpak "org.inkscape.Inkscape" "Éditeur vectoriel" ;;
        esac
    fi
    
    if ask_install "darktable" "Traitement photo RAW"; then
        case "$DISTRO" in
            arch) install_package "darktable" ;;
            *) install_flatpak "org.darktable.Darktable" "Traitement photo RAW" ;;
        esac
    fi
    
    if ask_install "Blender" "Modélisation 3D et animation"; then
        case "$DISTRO" in
            arch) install_package "blender" ;;
            *) install_flatpak "org.blender.Blender" "Modélisation 3D" ;;
        esac
    fi
    
    if ask_install "ImageMagick" "Manipulation d'image en ligne de commande"; then
        install_package "imagemagick" "" "Suite d'outils image CLI"
    fi
    
    # ==========================================
    # GAMING
    # ==========================================
    print_section "🎮 GAMING"
    
    if ask_install "Steam" "Plateforme de jeux"; then
        case "$DISTRO" in
            arch) 
                # Activation des dépôts multilib
                sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
                sudo pacman -Sy
                install_package "steam"
                ;;
            debian)
                # Activation des dépôts 32-bit
                sudo dpkg --add-architecture i386
                sudo apt update
                install_package "steam"
                ;;
            fedora) 
                sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
                install_package "steam"
                ;;
            *) install_flatpak "com.valvesoftware.Steam" "Plateforme de jeux Steam" ;;
        esac
    fi
    
    if ask_install "Lutris" "Gestionnaire de jeux"; then
        case "$DISTRO" in
            arch) install_package "lutris" ;;
            *) install_flatpak "net.lutris.Lutris" "Gestionnaire de jeux" ;;
        esac
    fi
    
    if ask_install "Heroic Games Launcher" "Client Epic Games et GOG"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm heroic-games-launcher-bin
                fi
                ;;
            *) install_flatpak "com.heroicgameslauncher.hgl" "Client Epic/GOG" ;;
        esac
    fi
    
    if ask_install "ProtonUp-Qt" "Gestionnaire Proton"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm protonup-qt
                fi
                ;;
            *) install_flatpak "net.davidotek.pupgui2" "Gestionnaire Proton" ;;
        esac
    fi
    
    if ask_install "GameMode" "Optimisations gaming"; then
        case "$DISTRO" in
            arch) install_package "gamemode" ;;
            debian) install_package "gamemode" ;;
            fedora) install_package "gamemode" ;;
            opensuse) install_package "gamemode" ;;
        esac
    fi
    
    if ask_install "MangoHud" "Overlay de performance"; then
        case "$DISTRO" in
            arch) install_package "mangohud" ;;
            debian) install_package "mangohud" ;;
            fedora) install_package "mangohud" ;;
            opensuse) install_package "mangohud" ;;
        esac
    fi
    
    if ask_install "Bottles" "Gestionnaire Wine"; then
        case "$DISTRO" in
            arch) install_package "bottles" ;;
            *) install_flatpak "com.usebottles.bottles" "Gestionnaire Wine" ;;
        esac
    fi
    
    if ask_install "Wine Staging" "Couche de compatibilité Windows"; then
        case "$DISTRO" in
            arch) install_package "wine-staging" ;;
            debian) install_package "wine" ;;
            fedora) install_package "wine" ;;
            opensuse) install_package "wine" ;;
        esac
    fi
    
    if ask_install "Winetricks" "Utilitaires Wine"; then
        install_package "winetricks" "" "Scripts d'installation Wine"
    fi
    
    # ==========================================
    # SÉCURITÉ
    # ==========================================
    print_section "🔒 SÉCURITÉ"
    
    if ask_install "KeePassXC" "Gestionnaire de mots de passe"; then
        case "$DISTRO" in
            arch) install_package "keepassxc" ;;
            *) install_flatpak "org.keepassxc.KeePassXC" "Gestionnaire de mots de passe" ;;
        esac
    fi
    
    if ask_install "GUFW" "Pare-feu graphique"; then
        case "$DISTRO" in
            arch) install_package "gufw" ;;
            debian) install_package "gufw" ;;
            fedora) install_package "firewall-config" ;;
            opensuse) install_package "firewall-config" ;;
        esac
    fi
    
    # ==========================================
    # AUTRES OUTILS
    # ==========================================
    print_section "🛠️  AUTRES OUTILS"
    
    if ask_install "Balena Etcher" "Création de médias bootables"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm balena-etcher
                fi
                ;;
            *) install_flatpak "com.balena.Etcher" "Création de médias bootables" ;;
        esac
    fi
    
    if ask_install "Popsicle" "Créateur USB (alternative Etcher)"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm popsicle
                fi
                ;;
            debian) install_package "popsicle-gtk" ;;
            *) print_message "⚠️  Popsicle non disponible pour cette distribution" "$YELLOW" ;;
        esac
    fi
    
    if ask_install "VirtualBox" "Machine virtuelle"; then
        case "$DISTRO" in
            arch) 
                install_package "virtualbox"
                sudo modprobe vboxdrv
                sudo usermod -aG vboxusers $USER
                ;;
            debian) install_package "virtualbox" ;;
            fedora) install_package "VirtualBox" ;;
            opensuse) install_package "virtualbox" ;;
        esac
    fi
    
    if ask_install "QEMU/KVM" "Virtualisation native"; then
        case "$DISTRO" in
            arch) 
                install_package "qemu-full virt-manager"
                sudo systemctl enable libvirtd
                sudo usermod -aG libvirt $USER
                ;;
            debian) 
                install_package "qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager"
                sudo usermod -aG libvirt $USER
                ;;
            fedora) 
                install_package "qemu-kvm libvirt virt-manager"
                sudo usermod -aG libvirt $USER
                ;;
            opensuse) 
                install_package "qemu-kvm libvirt virt-manager"
                sudo usermod -aG libvirt $USER
                ;;
        esac
    fi
    
    if ask_install "Spicetify-CLI" "Personnalisation Spotify"; then
        # Installation via curl
        curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-cli/master/install.sh | sh
        print_message "✅ Spicetify-CLI installé. Configurez-le avec 'spicetify config'" "$GREEN"
    fi
    
    if ask_install "Snap" "Gestionnaire de paquets Snap"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm snapd
                    sudo systemctl enable snapd.socket
                fi
                ;;
            debian) install_package "snapd" ;;
            fedora) install_package "snapd" ;;
            opensuse) install_package "snapd" ;;
        esac
    fi
    
    if ask_install "AppImageLauncher" "Intégration AppImage"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm appimagelauncher
                fi
                ;;
            debian)
                wget https://github.com/TheAssassin/AppImageLauncher/releases/download/v2.2.0/appimagelauncher_2.2.0-travis995.0f91801.bionic_amd64.deb
                sudo apt install -y ./appimagelauncher_2.2.0-travis995.0f91801.bionic_amd64.deb
                ;;
            *) print_message "⚠️  AppImageLauncher non disponible via gestionnaire de paquets" "$YELLOW" ;;
        esac
    fi
    
    # ==========================================
    # OUTILS IA ET DÉVELOPPEMENT AVANCÉ
    # ==========================================
    print_section "🤖 OUTILS IA ET DÉVELOPPEMENT AVANCÉ"
    
    if ask_install "GPT4All" "IA locale pour le code"; then
        case "$DISTRO" in
            arch)
                if [ -n "$AUR_HELPER" ]; then
                    $AUR_HELPER -S --noconfirm gpt4all
                fi
                ;;
            *) install_flatpak "io.gpt4all.gpt4all" "IA locale" ;;
        esac
    fi
    
    # Installation d'outils IA via pip si Python est installé
    if command -v pip3 >/dev/null 2>&1; then
        if ask_install "Outils IA Python" "Codeium CLI, TabNine, etc."; then
            pip3 install --user codeium
            pip3 install --user openai
            pip3 install --user anthropic
            print_message "✅ Outils IA Python installés" "$GREEN"
        fi
    fi
    
    # ==========================================
    # CONFIGURATION POST-INSTALLATION
    # ==========================================
    print_section "⚙️  CONFIGURATION POST-INSTALLATION"
    
    # Configuration de Git
    if command -v git >/dev/null 2>&1; then
        print_message "Configuration de Git..." "$BLUE"
        read -p "Nom d'utilisateur Git (optionnel): " git_name
        read -p "Email Git (optionnel): " git_email
        
        if [ -n "$git_name" ]; then
            git config --global user.name "$git_name"
        fi
        if [ -n "$git_email" ]; then
            git config --global user.email "$git_email"
        fi
        
        # Configuration d'aliases Git utiles
        git config --global alias.st status
        git config --global alias.co checkout
        git config --global alias.br branch
        git config --global alias.ci commit
        git config --global alias.unstage 'reset HEAD --'
        git config --global alias.last 'log -1 HEAD'
        git config --global alias.visual '!gitk'
        
        print_message "✅ Git configuré" "$GREEN"
    fi
    
    # Configuration de Zsh avec Oh My Zsh (optionnel)
    if ask_install "Oh My Zsh" "Framework Zsh avec thèmes et plugins"; then
        # Installation de Zsh si nécessaire
        case "$DISTRO" in
            arch) install_package "zsh" ;;
            debian) install_package "zsh" ;;
            fedora) install_package "zsh" ;;
            opensuse) install_package "zsh" ;;
        esac
        
        # Installation d'Oh My Zsh
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        
        # Installation de plugins populaires
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
        
        # Configuration du .zshrc avec plugins
        sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker docker-compose npm node python rust go)/' ~/.zshrc
        
        print_message "✅ Oh My Zsh installé avec plugins" "$GREEN"
        print_message "ℹ️  Changez votre shell avec: chsh -s /bin/zsh" "$CYAN"
    fi
    
    # Message final
    print_section "🎉 INSTALLATION TERMINÉE"
    
    print_message "🎊 Félicitations ! Votre environnement de développement est maintenant configuré." "$GREEN"
    print_message "" ""
    print_message "📋 Prochaines étapes recommandées:" "$CYAN"
    print_message "   1. Redémarrez votre session pour appliquer les changements de groupes" "$YELLOW"
    print_message "   2. Configurez vos extensions VS Code selon vos besoins" "$YELLOW"
    print_message "   3. Personnalisez votre terminal et vos outils" "$YELLOW"
    print_message "   4. Configurez vos clés SSH et GPG pour Git" "$YELLOW"
    print_message "   5. Importez vos dotfiles si vous en avez" "$YELLOW"
    print_message "" ""
    print_message "💡 Conseils:" "$BLUE"
    print_message "   • Utilisez 'flatpak update' pour mettre à jour les apps Flatpak" "$NC"
    print_message "   • Explorez les extensions VS Code installées" "$NC"
    print_message "   • Configurez vos outils IA avec vos clés API" "$NC"
    print_message "" ""
    print_message "🚀 Bon développement !" "$PURPLE"
    
    # Nettoyage
    print_message "🧹 Nettoyage des fichiers temporaires..." "$BLUE"
    rm -f packages-microsoft-prod.deb docker-desktop-*.deb lazygit.tar.gz appimagelauncher_*.deb
    print_message "✅ Nettoyage terminé" "$GREEN"
}

# ==========================================
# POINT D'ENTRÉE PRINCIPAL
# ==========================================

# Vérification des privilèges sudo
if ! sudo -n true 2>/dev/null; then
    print_message "🔐 Ce script nécessite des privilèges sudo." "$YELLOW"
    print_message "Veuillez entrer votre mot de passe pour continuer." "$CYAN"
    sudo -v
fi

# Détection de la distribution
detect_distro

# Confirmation avant installation
echo ""
print_message "⚠️  Ce script va installer de nombreux logiciels sur votre système." "$YELLOW"
print_message "Chaque installation sera optionnelle (vous pourrez dire non)." "$CYAN"
echo ""
while true; do
    echo -n -e "${YELLOW}Voulez-vous continuer ?${NC} [O/n]: "
    read -r choice
    case "$choice" in
        [Oo]|[Oo][Uu][Ii]|"") break ;;
        [Nn]|[Nn][Oo][Nn]) 
            print_message "Installation annulée." "$RED"
            exit 0 
            ;;
        *) echo "Répondez par O (oui) ou N (non)" ;;
    esac
done

# Lancement du script principal
main

print_message "🏁 Script terminé avec succès !" "$GREEN"
exit 0