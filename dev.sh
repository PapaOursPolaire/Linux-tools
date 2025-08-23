#!/bin/bash

# Script d'installation universelle pour développeurs Linux
# Compatible avec Arch/Manjaro, Ubuntu/Debian, Fedora, openSUSE
# Auteur: PapaOursPolaire - GitHub
# Version: 45.2
# Mise à jour : 23/08/2025 à 22:57

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

# Fonction pour vérifier si un paquet est déjà installé
is_package_installed() {
    local package="$1"
    case "$DISTRO" in
        arch)
            pacman -Qi "$package" >/dev/null 2>&1
            return $?
            ;;
        debian)
            dpkg -s "$package" >/dev/null 2>&1
            return $?
            ;;
        fedora)
            rpm -q "$package" >/dev/null 2>&1
            return $?
            ;;
        opensuse)
            rpm -q "$package" >/dev/null 2>&1
            return $?
            ;;
    esac
}

# Fonction pour vérifier si un flatpak est installé
is_flatpak_installed() {
    local flatpak_id="$1"
    flatpak info "$flatpak_id" >/dev/null 2>&1
    return $?
}

# Fonction pour vérifier si un binaire est disponible
is_binary_available() {
    local binary="$1"
    command -v "$binary" >/dev/null 2>&1
    return $?
}

# Installation selon la distribution
install_package() {
    local package="$1"
    local flatpak_package="$2"
    local description="$3"
    
    # Vérifier si le paquet est déjà installé
    if is_package_installed "$package" || is_binary_available "$package"; then
        print_message "✅ $package est déjà installé" "$GREEN"
        return 0
    fi
    
    # Vérifier si le flatpak est déjà installé
    if [ -n "$flatpak_package" ] && is_flatpak_installed "$flatpak_package"; then
        print_message "✅ $flatpak_package (flatpak) est déjà installé" "$GREEN"
        return 0
    fi
    
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
                    flatpak install -y flathub "$flatpak_package" || {
                        print_message "❌ Échec d'installation via Flatpak" "$RED"
                        return 1
                    }
                else
                    print_message "❌ Échec d'installation via apt" "$RED"
                    return 1
                fi
            }
            ;;
        fedora)
            sudo dnf install -y "$package" || {
                if [ -n "$flatpak_package" ] && $FLATPAK_AVAILABLE; then
                    print_message "⚠️  Tentative via Flatpak..." "$YELLOW"
                    flatpak install -y flathub "$flatpak_package" || {
                        print_message "❌ Échec d'installation via Flatpak" "$RED"
                        return 1
                    }
                else
                    print_message "❌ Échec d'installation via dnf" "$RED"
                    return 1
                fi
            }
            ;;
        opensuse)
            sudo zypper install -y "$package" || {
                if [ -n "$flatpak_package" ] && $FLATPAK_AVAILABLE; then
                    print_message "⚠️  Tentative via Flatpak..." "$YELLOW"
                    flatpak install -y flathub "$flatpak_package" || {
                        print_message "❌ Échec d'installation via Flatpak" "$RED"
                        return 1
                    }
                else
                    print_message "❌ Échec d'installation via zypper" "$RED"
                    return 1
                fi
            }
            ;;
    esac
    
    print_message "✅ $package installé avec succès" "$GREEN"
    return 0
}

# Installation via Flatpak uniquement
install_flatpak() {
    local package="$1"
    local description="$2"
    
    if ! $FLATPAK_AVAILABLE; then
        print_message "❌ Flatpak non disponible pour $package" "$RED"
        return 1
    fi
    
    if is_flatpak_installed "$package"; then
        print_message "✅ $package (flatpak) est déjà installé" "$GREEN"
        return 0
    fi
    
    print_message "📦 Installation de $package via Flatpak..." "$BLUE"
    flatpak install -y flathub "$package" || {
        print_message "❌ Échec d'installation de $package" "$RED"
        return 1
    }
    print_message "✅ $package installé avec succès" "$GREEN"
    return 0
}

# Fonction utilitaire pour installer un logiciel avec vérification
safe_install() {
    local name="$1"
    local description="$2"
    local package_name="$3"
    local flatpak_id="$4"
    local binary_name="$5"
    
    if ask_install "$name" "$description"; then
        # Utiliser le nom du binaire fourni ou le nom du paquet par défaut
        local check_binary="${binary_name:-$package_name}"
        
        # Vérifier si le logiciel est déjà installé
        if command -v "$check_binary" >/dev/null 2>&1; then
            print_message "✅ $name est déjà installé" "$GREEN"
            return 0
        fi
        
        # Essayer d'installer via le gestionnaire de paquets
        if [ -n "$package_name" ]; then
            install_package "$package_name" "$flatpak_id" "$description" || {
                print_message "❌ Échec d'installation de $name" "$RED"
                return 1
            }
        # Sinon essayer via flatpak
        elif [ -n "$flatpak_id" ] && $FLATPAK_AVAILABLE; then
            install_flatpak "$flatpak_id" "$description" || {
                print_message "❌ Échec d'installation de $name" "$RED"
                return 1
            }
        else
            print_message "❌ Aucune méthode d'installation disponible pour $name" "$RED"
            return 1
        fi
    fi
    return 0
}

# Installation Node.js avec NVM
install_nodejs() {
    # Vérifier si Node.js est déjà installé via NVM ou autre
    if command -v node >/dev/null 2>&1; then
        print_message "✅ Node.js est déjà installé" "$GREEN"
        return 0
    fi
    
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
    if ! command -v code >/dev/null 2>&1; then
        print_message "❌ VS Code n'est pas installé, impossible d'installer les extensions" "$RED"
        return 1
    fi
    
    print_message "📦 Installation des extensions VS Code..." "$BLUE"
    
    extensions=(
        "ms-python.python" "ms-vscode.cpptools" "redhat.java" "golang.go"
        "rust-lang.rust-analyzer" "esbenp.prettier-vscode" "dbaeumer.vscode-eslint"
        "bradlc.vscode-tailwindcss" "ritwickdey.liveserver" "formulahendry.auto-rename-tag"
        "formulahendry.auto-close-tag" "ms-azuretools.vscode-docker" "ms-toolsai.jupyter"
        "ms-vscode.makefile-tools" "ms-vscode.cmake-tools" "eamodio.gitlens"
        "mhutchie.git-graph" "donjayamanne.githistory" "aaron-bond.better-comments"
        "usernamehw.errorlens" "gruntfuggly.todo-tree" "streetsidesoftware.code-spell-checker"
        "pkief.material-icon-theme" "dracula-theme.theme-dracula" "zhuangtongfa.material-theme"
        "rocketseat.theme-omni" "yzhang.markdown-all-in-one" "shd101wyy.markdown-preview-enhanced"
        "vscjava.vscode-java-pack" "github.copilot" "ms-vscode.cpptools-extension-pack"
        "codeium.codeium" "amazonwebservices.aws-toolkit-vscode" "rangav.vscode-thunder-client"
        "humao.rest-client" "johnpapa.vscode-peacock" "vscode-icons-team.vscode-icons"
        "coenraads.bracket-pair-colorizer-2" "formulahendry.code-runner" "tabnine.tabnine-vscode"
        "hediet.vscode-drawio"
    )
    
    for ext in "${extensions[@]}"; do
        print_message "Installation extension: $ext" "$BLUE"
        code --install-extension "$ext" --force || {
            print_message "⚠️  Échec installation extension: $ext" "$YELLOW"
        }
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
            sudo pacman -Syu --noconfirm || {
                print_message "⚠️  Échec de la mise à jour du système" "$YELLOW"
            }
            ;;
        debian)
            sudo apt update && sudo apt upgrade -y || {
                print_message "⚠️  Échec de la mise à jour du système" "$YELLOW"
            }
            ;;
        fedora)
            sudo dnf upgrade -y || {
                print_message "⚠️  Échec de la mise à jour du système" "$YELLOW"
            }
            ;;
        opensuse)
            sudo zypper refresh && sudo zypper update -y || {
                print_message "⚠️  Échec de la mise à jour du système" "$YELLOW"
            }
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
    safe_install "Git" "Contrôle de version" "git" "" "git"
    safe_install "Git LFS" "Support des gros fichiers Git" "git-lfs" "" "git-lfs"
    
    # Docker
    if ask_install "Docker" "Conteneurisation"; then
        if command -v docker >/dev/null 2>&1; then
            print_message "✅ Docker est déjà installé" "$GREEN"
        else
            case "$DISTRO" in
                arch)
                    install_package "docker" "" "Moteur de conteneurisation" || {
                        print_message "❌ Échec d'installation de Docker" "$RED"
                    }
                    if command -v docker >/dev/null 2>&1; then
                        sudo systemctl enable docker
                        sudo usermod -aG docker $USER
                        print_message "✅ Docker configuré avec succès" "$GREEN"
                    fi
                    ;;
                debian)
                    # Vérifier si le dépôt Docker est déjà configuré
                    if [ ! -f "/etc/apt/sources.list.d/docker.list" ] && [ ! -f "/usr/share/keyrings/docker-archive-keyring.gpg" ]; then
                        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                        sudo apt update
                    fi
                    
                    # Installer Docker
                    if install_package "docker-ce docker-ce-cli containerd.io" "" "Moteur de conteneurisation"; then
                        sudo usermod -aG docker $USER
                        print_message "✅ Docker configuré avec succès" "$GREEN"
                    else
                        print_message "❌ Échec d'installation de Docker" "$RED"
                    fi
                    ;;
                fedora)
                    if install_package "docker-ce docker-ce-cli containerd.io" "" "Moteur de conteneurisation"; then
                        sudo systemctl enable docker
                        sudo usermod -aG docker $USER
                        print_message "✅ Docker configuré avec succès" "$GREEN"
                    else
                        print_message "❌ Échec d'installation de Docker" "$RED"
                    fi
                    ;;
                opensuse)
                    if install_package "docker" "" "Moteur de conteneurisation"; then
                        sudo systemctl enable docker
                        sudo usermod -aG docker $USER
                        print_message "✅ Docker configuré avec succès" "$GREEN"
                    else
                        print_message "❌ Échec d'installation de Docker" "$RED"
                    fi
                    ;;
            esac
        fi
    fi
    
    safe_install "Docker Compose" "Orchestration de conteneurs" "docker-compose" "" "docker-compose"
    
    # Éditeurs de code
    if ask_install "Visual Studio Code" "Éditeur de code Microsoft"; then
        if command -v code >/dev/null 2>&1; then
            print_message "✅ Visual Studio Code est déjà installé" "$GREEN"
        else
            case "$DISTRO" in
                arch)
                    if [ -n "$AUR_HELPER" ]; then
                        $AUR_HELPER -S --noconfirm visual-studio-code-bin || {
                            print_message "❌ Échec d'installation de Visual Studio Code" "$RED"
                        }
                    else
                        print_message "❌ Aucun helper AUR disponible pour installer Visual Studio Code" "$RED"
                    fi
                    ;;
                debian)
                    # Vérifier si le dépôt Microsoft est déjà configuré
                    if [ ! -f "/etc/apt/trusted.gpg.d/packages.microsoft.gpg" ]; then
                        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
                        sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
                        sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
                        sudo apt update
                    fi
                    
                    install_package "code" "" "Éditeur de code Microsoft" || {
                        print_message "❌ Échec d'installation de Visual Studio Code" "$RED"
                    }
                    ;;
                fedora)
                    # Vérifier si le dépôt Microsoft est déjà configuré
                    if [ ! -f "/etc/yum.repos.d/vscode.repo" ]; then
                        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
                    fi
                    
                    install_package "code" "" "Éditeur de code Microsoft" || {
                        print_message "❌ Échec d'installation de Visual Studio Code" "$RED"
                    }
                    ;;
                opensuse)
                    # Vérifier si le dépôt Microsoft est déjà configuré
                    if [ ! -f "/etc/zypp/repos.d/vscode.repo" ]; then
                        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                        sudo zypper addrepo https://packages.microsoft.com/yumrepos/vscode vscode
                    fi
                    
                    install_package "code" "" "Éditeur de code Microsoft" || {
                        print_message "❌ Échec d'installation de Visual Studio Code" "$RED"
                    }
                    ;;
            esac
            
            # Installation des extensions VS Code seulement si VS Code a été installé avec succès
            if command -v code >/dev/null 2>&1 && ask_install "Extensions VS Code" "Toutes les extensions recommandées"; then
                install_vscode_extensions
            fi
        fi
    fi
    
    safe_install "VSCodium" "Version libre de VS Code" "codium" "com.vscodium.codium" "codium"
    safe_install "Neovim" "Éditeur de texte avancé" "neovim" "" "nvim"
    safe_install "Micro" "Éditeur de texte simple" "micro" "" "micro"
    
    # Helix (installation spéciale)
    if ask_install "Helix" "Éditeur de texte modal moderne"; then
        if command -v hx >/dev/null 2>&1; then
            print_message "✅ Helix est déjà installé" "$GREEN"
        else
            case "$DISTRO" in
                arch) 
                    install_package "helix" "" "Éditeur de texte modal moderne" || {
                        print_message "❌ Échec d'installation de Helix" "$RED"
                    }
                    ;;
                *) 
                    # Installation via cargo si disponible
                    if command -v cargo >/dev/null 2>&1; then
                        cargo install helix-term || {
                            print_message "❌ Échec d'installation de Helix via cargo" "$RED"
                        }
                    else
                        print_message "⚠️  Helix nécessite Rust/Cargo ou installation manuelle" "$YELLOW"
                    fi
                    ;;
            esac
        fi
    fi
    
    # Terminaux
    safe_install "Kitty" "Émulateur de terminal moderne" "kitty" "" "kitty"
    safe_install "Terminator" "Terminal avec support de division" "terminator" "" "terminator"
    safe_install "Alacritty" "Terminal accéléré GPU" "alacritty" "" "alacritty"
    
    # Langages de programmation
    if ask_install "Node.js & NPM" "Runtime JavaScript"; then
        install_nodejs
    fi
    
    safe_install "Python & Pip" "Langage Python" "python python-pip" "" "python3"
    safe_install "Go" "Langage Go" "go" "" "go"
    safe_install "Rust" "Langage Rust" "rust" "" "rustc"
    safe_install "Java OpenJDK" "Machine virtuelle Java" "jdk-openjdk" "" "java"
    
    # .NET SDK (installation spéciale)
    if ask_install ".NET SDK" "Framework Microsoft .NET"; then
        if command -v dotnet >/dev/null 2>&1; then
            print_message "✅ .NET SDK est déjà installé" "$GREEN"
        else
            case "$DISTRO" in
                arch) 
                    install_package "dotnet-sdk" "" "Framework Microsoft .NET" || {
                        print_message "❌ Échec d'installation de .NET SDK" "$RED"
                    }
                    ;;
                debian) 
                    # Vérifier si le dépôt Microsoft est déjà configuré
                    if [ ! -f "/etc/apt/trusted.gpg.d/packages.microsoft.gpg" ]; then
                        wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
                        sudo dpkg -i packages-microsoft-prod.deb
                        sudo apt update
                    fi
                    install_package "dotnet-sdk-7.0" "" "Framework Microsoft .NET" || {
                        print_message "❌ Échec d'installation de .NET SDK" "$RED"
                    }
                    ;;
                fedora) 
                    install_package "dotnet-sdk-7.0" "" "Framework Microsoft .NET" || {
                        print_message "❌ Échec d'installation de .NET SDK" "$RED"
                    }
                    ;;
                opensuse) 
                    install_package "dotnet-sdk-7.0" "" "Framework Microsoft .NET" || {
                        print_message "❌ Échec d'installation de .NET SDK" "$RED"
                    }
                    ;;
            esac
        fi
    fi
    
    # Outils de compilation
    safe_install "Outils de compilation" "GCC, G++, Clang, Make, CMake" "gcc make cmake clang gdb" "" "gcc"
    
    # Outils de développement
    safe_install "Postman" "Client API" "postman-bin" "com.getpostman.Postman" "postman"
    safe_install "SQLite Browser" "Explorateur de base de données SQLite" "sqlitebrowser" "" "sqlitebrowser"
    
    # Docker Desktop (installation spéciale)
    if ask_install "Docker Desktop" "Interface graphique Docker"; then
        if command -v docker-desktop >/dev/null 2>&1; then
            print_message "✅ Docker Desktop est déjà installé" "$GREEN"
        else
            case "$DISTRO" in
                arch)
                    if [ -n "$AUR_HELPER" ]; then
                        $AUR_HELPER -S --noconfirm docker-desktop || {
                            print_message "❌ Échec d'installation de Docker Desktop" "$RED"
                        }
                    else
                        print_message "❌ Aucun helper AUR disponible pour installer Docker Desktop" "$RED"
                    fi
                    ;;
                debian)
                    # Vérifier si le fichier .deb est déjà téléchargé
                    if [ ! -f "docker-desktop-4.21.1-amd64.deb" ]; then
                        wget https://desktop.docker.com/linux/main/amd64/docker-desktop-4.21.1-amd64.deb
                    fi
                    sudo apt install -y ./docker-desktop-4.21.1-amd64.deb || {
                        print_message "❌ Échec d'installation de Docker Desktop" "$RED"
                    }
                    ;;
                *) 
                    print_message "⚠️  Docker Desktop non disponible pour cette distribution" "$YELLOW" 
                    ;;
            esac
        fi
    fi
    
    safe_install "Lazygit" "Interface Git en terminal" "lazygit" "" "lazygit"
    safe_install "btop" "Moniteur système moderne" "btop" "" "btop"
    safe_install "htop" "Moniteur système classique" "htop" "" "htop"
    
    # ==========================================
    # OUTILS DE PRISE DE NOTES
    # ==========================================
    print_section "📝 OUTILS DE PRISE DE NOTES"
    
    safe_install "Obsidian" "Prise de notes avec liens" "obsidian" "md.obsidian.Obsidian" "obsidian"
    safe_install "Joplin" "Application de notes open source" "joplin-appimage" "net.cozic.joplin_desktop" "joplin"
    
    # ==========================================
    # BUREAU ET UTILITAIRES SYSTÈME
    # ==========================================
    print_section "🖥️  BUREAU ET UTILITAIRES SYSTÈME"
    
    safe_install "GNOME Tweaks" "Personnalisation GNOME" "gnome-tweaks" "" "gnome-tweaks"
    safe_install "Stacer" "Optimiseur système" "stacer" "com.oguzhaninan.Stacer" "stacer"
    safe_install "BleachBit" "Nettoyeur système" "bleachbit" "" "bleachbit"
    safe_install "Timeshift" "Sauvegarde système" "timeshift" "" "timeshift"
    safe_install "GParted" "Gestionnaire de partitions" "gparted" "" "gparted"
    safe_install "ULauncher" "Lanceur d'applications" "ulauncher" "" "ulauncher"
    safe_install "Flameshot" "Capture d'écran" "flameshot" "" "flameshot"
    
    # ==========================================
    # INTERNET ET COMMUNICATION
    # ==========================================
    print_section "🌐 INTERNET ET COMMUNICATION"
    
    safe_install "Firefox" "Navigateur web Mozilla" "firefox" "org.mozilla.firefox" "firefox"
    safe_install "LibreWolf" "Firefox axé sur la vie privée" "librewolf-bin" "io.gitlab.librewolf-community" "librewolf"
    safe_install "Brave Browser" "Navigateur axé sur la vie privée" "brave-bin" "com.brave.Browser" "brave-browser"
    safe_install "Chromium" "Navigateur open source" "chromium" "org.chromium.Chromium" "chromium"
    
    # Google Chrome (installation spéciale)
    if ask_install "Google Chrome" "Navigateur Google"; then
        if command -v google-chrome >/dev/null 2>&1 || command -v google-chrome-stable >/dev/null 2>&1; then
            print_message "✅ Google Chrome est déjà installé" "$GREEN"
        else
            case "$DISTRO" in
                arch)
                    if [ -n "$AUR_HELPER" ]; then
                        $AUR_HELPER -S --noconfirm google-chrome || {
                            print_message "❌ Échec d'installation de Google Chrome" "$RED"
                        }
                    else
                        print_message "❌ Aucun helper AUR disponible pour installer Google Chrome" "$RED"
                    fi
                    ;;
                debian)
                    # Vérifier si le dépôt Google est déjà configuré
                    if [ ! -f "/etc/apt/sources.list.d/google-chrome.list" ]; then
                        wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
                        echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
                        sudo apt update
                    fi
                    install_package "google-chrome-stable" "" "Navigateur Google" || {
                        print_message "❌ Échec d'installation de Google Chrome" "$RED"
                    }
                    ;;
                fedora)
                    # Vérifier si le dépôt Google est déjà configuré
                    if ! sudo dnf repolist | grep -q google-chrome; then
                        sudo dnf install -y fedora-workstation-repositories
                        sudo dnf config-manager --set-enabled google-chrome
                    fi
                    install_package "google-chrome-stable" "" "Navigateur Google" || {
                        print_message "❌ Échec d'installation de Google Chrome" "$RED"
                    }
                    ;;
                opensuse)
                    # Vérifier si le dépôt Google est déjà configuré
                    if [ ! -f "/etc/zypp/repos.d/Google-Chrome.repo" ]; then
                        wget https://dl.google.com/linux/linux_signing_key.pub
                        sudo rpm --import linux_signing_key.pub
                        sudo zypper addrepo http://dl.google.com/linux/chrome/rpm/stable/x86_64 Google-Chrome
                    fi
                    install_package "google-chrome-stable" "" "Navigateur Google" || {
                        print_message "❌ Échec d'installation de Google Chrome" "$RED"
                    }
                    ;;
            esac
        fi
    fi
    
    # DuckDuckGo Browser
    if ask_install "DuckDuckGo Browser" "Navigateur axé sur la vie privée"; then
        if command -v duckduckgo >/dev/null 2>&1; then
            print_message "✅ DuckDuckGo Browser est déjà installé" "$GREEN"
        else
            case "$DISTRO" in
                arch)
                    if [ -n "$AUR_HELPER" ]; then
                        $AUR_HELPER -S --noconfirm duckduckgo-privacy-browser || {
                            print_message "❌ Échec d'installation de DuckDuckGo Browser" "$RED"
                        }
                    else
                        print_message "❌ Aucun helper AUR disponible pour installer DuckDuckGo Browser" "$RED"
                    fi
                    ;;
                *) 
                    print_message "⚠️  DuckDuckGo Browser disponible principalement sur mobile" "$YELLOW"
                    print_message "💡 Configurez DuckDuckGo comme moteur de recherche par défaut dans votre navigateur" "$CYAN"
                    ;;
            esac
        fi
    fi
    
    safe_install "Discord" "Communication gaming" "discord" "com.discordapp.Discord" "discord"
    safe_install "Signal" "Messagerie sécurisée" "signal-desktop" "org.signal.Signal" "signal-desktop"
    safe_install "Telegram" "Messagerie instantanée" "telegram-desktop" "org.telegram.desktop" "telegram-desktop"
    safe_install "Element" "Client Matrix" "element-desktop" "im.riot.Riot" "element-desktop"
    safe_install "Slack" "Communication professionnelle" "slack-desktop" "com.slack.Slack" "slack"
    safe_install "Thunderbird" "Client email" "thunderbird" "org.mozilla.Thunderbird" "thunderbird"
    
    # ==========================================
    # MULTIMÉDIA
    # ==========================================
    print_section "🎵 MULTIMÉDIA"
    
    safe_install "VLC" "Lecteur multimédia universel" "vlc" "org.videolan.VLC" "vlc"
    safe_install "MPV" "Lecteur vidéo minimaliste" "mpv" "" "mpv"
    safe_install "DeaDBeeF" "Lecteur audio léger" "deadbeef" "org.deadbeef.deadbeef" "deadbeef"
    safe_install "Lollypop" "Lecteur de musique moderne" "lollypop" "org.gnome.Lollypop" "lollypop"
    safe_install "Kdenlive" "Éditeur vidéo professionnel" "kdenlive" "org.kde.kdenlive" "kdenlive"
    safe_install "Shotcut" "Éditeur vidéo simple" "shotcut" "org.shotcut.Shotcut" "shotcut"
    safe_install "OBS Studio" "Enregistrement et streaming" "obs-studio" "com.obsproject.Studio" "obs"
    safe_install "Audacity" "Éditeur audio" "audacity" "org.audacityteam.Audacity" "audacity"
    safe_install "EasyEffects" "Processeur audio en temps réel" "easyeffects" "com.github.wwmm.easyeffects" "easyeffects"
    safe_install "Piper" "Configuration souris gaming" "piper" "org.freedesktop.Piper" "piper"
    
    # ==========================================
    # DESIGN ET IMAGE
    # ==========================================
    print_section "🎨 DESIGN ET IMAGE"
    
    safe_install "GIMP" "Éditeur d'image avancé" "gimp" "org.gimp.GIMP" "gimp"
    safe_install "Krita" "Peinture numérique" "krita" "org.kde.krita" "krita"
    safe_install "Inkscape" "Éditeur vectoriel" "inkscape" "org.inkscape.Inkscape" "inkscape"
    safe_install "darktable" "Traitement photo RAW" "darktable" "org.darktable.Darktable" "darktable"
    safe_install "Blender" "Modélisation 3D et animation" "blender" "org.blender.Blender" "blender"
    safe_install "ImageMagick" "Manipulation d'image en ligne de commande" "imagemagick" "" "convert"
    
    # ==========================================
    # GAMING
    # ==========================================
    print_section "🎮 GAMING"
    
    # Steam (installation spéciale)
    if ask_install "Steam" "Plateforme de jeux"; then
        if command -v steam >/dev/null 2>&1; then
            print_message "✅ Steam est déjà installé" "$GREEN"
        else
            case "$DISTRO" in
                arch) 
                    # Activation des dépôts multilib
                    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
                        sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
                        sudo pacman -Sy
                    fi
                    install_package "steam" "" "Plateforme de jeux" || {
                        print_message "❌ Échec d'installation de Steam" "$RED"
                    }
                    ;;
                debian)
                    # Activation des dépôts 32-bit
                    if ! dpkg --print-foreign-architectures | grep -q i386; then
                        sudo dpkg --add-architecture i386
                        sudo apt update
                    fi
                    install_package "steam" "" "Plateforme de jeux" || {
                        print_message "❌ Échec d'installation de Steam" "$RED"
                    }
                    ;;
                fedora) 
                    if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
                        sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
                    fi
                    install_package "steam" "" "Plateforme de jeux" || {
                        print_message "❌ Échec d'installation de Steam" "$RED"
                    }
                    ;;
                *) 
                    install_flatpak "com.valvesoftware.Steam" "Plateforme de jeux Steam" || {
                        print_message "❌ Échec d'installation de Steam" "$RED"
                    }
                    ;;
            esac
        fi
    fi
    
    safe_install "Lutris" "Gestionnaire de jeux" "lutris" "net.lutris.Lutris" "lutris"
    safe_install "Heroic Games Launcher" "Client Epic Games et GOG" "heroic-games-launcher-bin" "com.heroicgameslauncher.hgl" "heroic"
    safe_install "ProtonUp-Qt" "Gestionnaire Proton" "protonup-qt" "net.davidotek.pupgui2" "protonup-qt"
    safe_install "GameMode" "Optimisations gaming" "gamemode" "" "gamemoded"
    safe_install "MangoHud" "Overlay de performance" "mangohud" "" "mangohud"
    safe_install "Bottles" "Gestionnaire Wine" "bottles" "com.usebottles.bottles" "bottles"
    safe_install "Wine Staging" "Couche de compatibilité Windows" "wine-staging" "" "wine"
    safe_install "Winetricks" "Utilitaires Wine" "winetricks" "" "winetricks"
    
    # ==========================================
    # SÉCURITÉ
    # ==========================================
    print_section "🔒 SÉCURITÉ"
    
    safe_install "KeePassXC" "Gestionnaire de mots de passe" "keepassxc" "org.keepassxc.KeePassXC" "keepassxc"
    safe_install "GUFW" "Pare-feu graphique" "gufw" "" "gufw"
    
    # ==========================================
    # AUTRES OUTILS
    # ==========================================
    print_section "🛠️  AUTRES OUTILS"
    
    safe_install "Balena Etcher" "Création de médias bootables" "balena-etcher" "com.balena.Etcher" "balena-etcher"
    safe_install "Popsicle" "Créateur USB (alternative Etcher)" "popsicle" "" "popsicle"
    
    # VirtualBox (installation spéciale)
    if ask_install "VirtualBox" "Machine virtuelle"; then
        if command -v virtualbox >/dev/null 2>&1; then
            print_message "✅ VirtualBox est déjà installé" "$GREEN"
        else
            case "$DISTRO" in
                arch) 
                    install_package "virtualbox" "" "Machine virtuelle" || {
                        print_message "❌ Échec d'installation de VirtualBox" "$RED"
                    }
                    if command -v virtualbox >/dev/null 2>&1; then
                        sudo modprobe vboxdrv
                        sudo usermod -aG vboxusers $USER
                        print_message "✅ VirtualBox configuré avec succès" "$GREEN"
                    fi
                    ;;
                debian) 
                    install_package "virtualbox" "" "Machine virtuelle" || {
                        print_message "❌ Échec d'installation de VirtualBox" "$RED"
                    }
                    ;;
                fedora) 
                    install_package "VirtualBox" "" "Machine virtuelle" || {
                        print_message "❌ Échec d'installation de VirtualBox" "$RED"
                    }
                    ;;
                opensuse) 
                    install_package "virtualbox" "" "Machine virtuelle" || {
                        print_message "❌ Échec d'installation de VirtualBox" "$RED"
                    }
                    ;;
            esac
        fi
    fi
    
    # QEMU/KVM (installation spéciale)
    if ask_install "QEMU/KVM" "Virtualisation native"; then
        if command -v virt-manager >/dev/null 2>&1; then
            print_message "✅ QEMU/KVM est déjà installé" "$GREEN"
        else
            case "$DISTRO" in
                arch) 
                    install_package "qemu-full virt-manager" "" "Virtualisation native" || {
                        print_message "❌ Échec d'installation de QEMU/KVM" "$RED"
                    }
                    if command -v virt-manager >/dev/null 2>&1; then
                        sudo systemctl enable libvirtd
                        sudo usermod -aG libvirt $USER
                        print_message "✅ QEMU/KVM configuré avec succès" "$GREEN"
                    fi
                    ;;
                debian) 
                    install_package "qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager" "" "Virtualisation native" || {
                        print_message "❌ Échec d'installation de QEMU/KVM" "$RED"
                    }
                    if command -v virt-manager >/dev/null 2>&1; then
                        sudo usermod -aG libvirt $USER
                        print_message "✅ QEMU/KVM configuré avec succès" "$GREEN"
                    fi
                    ;;
                fedora) 
                    install_package "qemu-kvm libvirt virt-manager" "" "Virtualisation native" || {
                        print_message "❌ Échec d'installation de QEMU/KVM" "$RED"
                    }
                    if command -v virt-manager >/dev/null 2>&1; then
                        sudo usermod -aG libvirt $USER
                        print_message "✅ QEMU/KVM configuré avec succès" "$GREEN"
                    fi
                    ;;
                opensuse) 
                    install_package "qemu-kvm libvirt virt-manager" "" "Virtualisation native" || {
                        print_message "❌ Échec d'installation de QEMU/KVM" "$RED"
                    }
                    if command -v virt-manager >/dev/null 2>&1; then
                        sudo usermod -aG libvirt $USER
                        print_message "✅ QEMU/KVM configuré avec succès" "$GREEN"
                    fi
                    ;;
            esac
        fi
    fi
    
    # Spicetify-CLI
    if ask_install "Spicetify-CLI" "Personnalisation Spotify"; then
        if command -v spicetify >/dev/null 2>&1; then
            print_message "✅ Spicetify-CLI est déjà installé" "$GREEN"
        else
            # Installation via curl
            curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-cli/master/install.sh | sh || {
                print_message "❌ Échec d'installation de Spicetify-CLI" "$RED"
            }
            if command -v spicetify >/dev/null 2>&1; then
                print_message "✅ Spicetify-CLI installé. Configurez-le avec 'spicetify config'" "$GREEN"
            fi
        fi
    fi
    
    safe_install "Snap" "Gestionnaire de paquets Snap" "snapd" "" "snap"
    safe_install "AppImageLauncher" "Intégration AppImage" "appimagelauncher" "" "appimagelauncher"
    
    # ==========================================
    # OUTILS IA ET DÉVELOPPEMENT AVANCÉ
    # ==========================================
    print_section "🤖 OUTILS IA ET DÉVELOPPEMENT AVANCÉ"
    
    safe_install "GPT4All" "IA locale pour le code" "gpt4all" "io.gpt4all.gpt4all" "gpt4all"
    
    # Installation d'outils IA via pip si Python est installé
    if command -v pip3 >/dev/null 2>&1; then
        if ask_install "Outils IA Python" "Codeium CLI, TabNine, etc."; then
            pip3 install --user codeium || {
                print_message "❌ Échec d'installation de Codeium" "$RED"
            }
            pip3 install --user openai || {
                print_message "❌ Échec d'installation de OpenAI" "$RED"
            }
            pip3 install --user anthropic || {
                print_message "❌ Échec d'installation de Anthropic" "$RED"
            }
            if pip3 list | grep -q codeium; then
                print_message "✅ Outils IA Python installés" "$GREEN"
            fi
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
        # Vérifier si Oh My Zsh est déjà installé
        if [ -d "$HOME/.oh-my-zsh" ]; then
            print_message "✅ Oh My Zsh est déjà installé" "$GREEN"
        else
            # Installation de Zsh si nécessaire
            if ! command -v zsh >/dev/null 2>&1; then
                safe_install "Zsh" "Shell avancé" "zsh" "" "zsh"
            fi
            
            # Installation d'Oh My Zsh
            if command -v zsh >/dev/null 2>&1; then
                sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || {
                    print_message "❌ Échec d'installation de Oh My Zsh" "$RED"
                }
                
                if [ -d "$HOME/.oh-my-zsh" ]; then
                    # Installation de plugins populaires
                    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || {
                        print_message "⚠️  Échec du clonage de zsh-autosuggestions" "$YELLOW"
                    }
                    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting || {
                        print_message "⚠️  Échec du clonage de zsh-syntax-highlighting" "$YELLOW"
                    }
                    
                    # Configuration du .zshrc avec plugins
                    if [ -f ~/.zshrc ]; then
                        sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker docker-compose npm node python rust go)/' ~/.zshrc
                    fi
                    
                    print_message "✅ Oh My Zsh installé avec plugins" "$GREEN"
                    print_message "ℹ️  Changez votre shell avec: chsh -s /bin/zsh" "$CYAN"
                fi
            fi
        fi
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
    rm -f packages-microsoft-prod.deb docker-desktop-*.deb lazygit.tar.gz appimagelauncher_*.deb linux_signing_key.pub
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
