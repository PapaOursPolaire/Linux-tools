#!/bin/bash

# Script universel de l'installation et de la  configuration d'Hyprland 
# Made by PapaOursPolaire - available on GitHub
# Version: 112.2, correctif 2 de la version 112.2
# Mise à jour : 22/08/2025 à 15:48

create_advanced_scripts() {
    log "HEADER" "Création des scripts utilitaires avancés"
    
    mkdir -p ~/.local/bin ~/.config/hypr/scripts
    
    # Script de wallpaper intelligent
    create_wallpaper_script
    
    # Script de capture d'écran avancée
    create_screenshot_menu
    
    # Script de gestion d'énergie
    create_power_menu
    
    # Script de monitoring système
    create_system_monitor
    
    # Script de changement de thème
    create_theme_switcher
    
    # Script de gestion audio
    create_audio_menu
    
    # Script de gestion réseau
    create_network_menu
    
    # Script de gestion Bluetooth
    create_bluetooth_menu
    
    # Script météo
    create_weather_script
    
    # Script de diagnostic Hyprland
    create_hyprland_diagnostics
    
    # Script d'autostart
    create_autostart_script
    
    # Rendre tous les scripts exécutables
    chmod +x ~/.local/bin/* ~/.config/hypr/scripts/*
    
    log "SUCCESS" "Scripts utilitaires créés"
}

create_autostart_script() {
    log "INFO" "Création du script d'autostart"
    
    cat > ~/.config/hypr/scripts/autostart.sh << 'EOF'
#!/bin/bash
# Script d'autostart Hyprland

# Attendre que Hyprland soit prêt
sleep 2

# Polkit
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &

# Services audio
pipewire &
sleep 1
pipewire-pulse &
wireplumber &

# Notifications
dunst &

# Barre des tâches
waybar &

# Wallpaper
~/.config/hypr/scripts/wallpaper.sh random &

# Gestionnaire d'inactivité
hypridle &

# Applications réseau
nm-applet &
blueman-applet &

# Mise à jour de la base de données locate
sudo updatedb &

log "Autostart Hyprland terminé"
EOF
    
    chmod +x ~/.config/hypr/scripts/autostart.sh
}

create_wallpaper_script() {
    log "INFO" "Création du script de wallpaper intelligent"
    
    cat > ~/.config/hypr/scripts/wallpaper.sh << 'EOF'
#!/bin/bash
# Script de wallpaper intelligent avec support vidéo et images

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
VIDEO_WALLPAPER_DIR="$HOME/Videos/Wallpapers"
CURRENT_WALLPAPER_FILE="$HOME/.cache/current_wallpaper"
FALLBACK_COLOR="#0f0f23"

# Créer les dossiers si inexistants
mkdir -p "$WALLPAPER_DIR" "$VIDEO_WALLPAPER_DIR"

# Fonction de logging
log_wallpaper() {
    echo "[$(date '+%H:%M:%S')] WALLPAPER: $1" >> "$HOME/.cache/hyprland.log"
}

# Arrêter les anciens processus de wallpaper
cleanup_wallpaper() {
    pkill mpvpaper 2>/dev/null
    pkill hyprpaper 2>/dev/null
    pkill swaybg 2>/dev/null
}

# Détection du type de fichier et application appropriée
set_wallpaper() {
    local file="$1"
    local extension="${file##*.}"
    
    cleanup_wallpaper
    sleep 0.5
    
    case "${extension,,}" in
        mp4|mkv|avi|webm|mov)
            log_wallpaper "Vidéo détectée: $(basename "$file")"
            if command -v mpvpaper &>/dev/null; then
                mpvpaper -o "loop-file=inf --volume=0 --hwdec=auto" '*' "$file" &
            else
                log_wallpaper "mpvpaper non disponible, fallback couleur"
                hyprctl hyprpaper wallpaper ",$FALLBACK_COLOR"
            fi
            ;;
        jpg|jpeg|png|webp|bmp)
            log_wallpaper "Image détectée: $(basename "$file")"
            if command -v hyprpaper &>/dev/null; then
                echo "preload = $file" > ~/.config/hypr/hyprpaper.conf
                echo "wallpaper = ,$file" >> ~/.config/hypr/hyprpaper.conf
                hyprpaper &
            elif command -v swaybg &>/dev/null; then
                swaybg -i "$file" &
            else
                log_wallpaper "Aucun gestionnaire de wallpaper trouvé"
            fi
            ;;
        *)
            log_wallpaper "Format non supporté: $extension"
            return 1
            ;;
    esac
    
    echo "$file" > "$CURRENT_WALLPAPER_FILE"
    return 0
}

# Mode sélection aléatoire
random_wallpaper() {
    local all_files=()
    
    # Collecter tous les fichiers supportés
    if [[ -d "$WALLPAPER_DIR" ]]; then
        while IFS= read -r -d '' file; do
            all_files+=("$file")
        done < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0 2>/dev/null)
    fi
    
    if [[ -d "$VIDEO_WALLPAPER_DIR" ]]; then
        while IFS= read -r -d '' file; do
            all_files+=("$file")
        done < <(find "$VIDEO_WALLPAPER_DIR" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.webm" \) -print0 2>/dev/null)
    fi
    
    if [[ ${#all_files[@]} -eq 0 ]]; then
        log_wallpaper "Aucun wallpaper trouvé, couleur fallback"
        cleanup_wallpaper
        hyprctl hyprpaper wallpaper ",$FALLBACK_COLOR"
        return 1
    fi
    
    local random_file="${all_files[RANDOM % ${#all_files[@]}]}"
    set_wallpaper "$random_file"
}

# Mode cyclique avec temps
cycle_wallpaper() {
    local interval=${1:-300}  # 5 minutes par défaut
    
    while true; do
        random_wallpaper
        sleep "$interval"
    done
}

# Main
case "${1:-random}" in
    "random")
        random_wallpaper
        ;;
    "cycle")
        cycle_wallpaper "${2:-300}"
        ;;
    "set")
        if [[ -f "$2" ]]; then
            set_wallpaper "$2"
        else
            echo "Fichier non trouvé: $2"
            exit 1
        fi
        ;;
    "stop")
        cleanup_wallpaper
        ;;
    *)
        echo "Usage: $0 {random|cycle [interval]|set <file>|stop}"
        exit 1
        ;;
esac
EOF
    
    log "SUCCESS" "Script de wallpaper créé"
}

create_screenshot_menu() {
    log "INFO" "Création du menu de capture d'écran"
    
    cat > ~/.local/bin/screenshot-menu << 'EOF'
#!/bin/bash
# Menu de capture d'écran avancé avec Wofi

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"

# Options du menu
OPTIONS="Écran complet
Zone sélectionnée  
Fenêtre active
Retard 3 secondes
Enregistrement écran
Presse-papiers"

# Affichage du menu
CHOICE=$(echo -e "$OPTIONS" | wofi --dmenu --prompt "Capture d'écran" --width 400 --height 300)

# Nom de fichier avec timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILENAME="$SCREENSHOT_DIR/screenshot_$TIMESTAMP.png"

case "$CHOICE" in
    "Écran complet")
        grim "$FILENAME"
        notify-send "Capture" "Écran complet sauvé" -i "$FILENAME"
        ;;
    Zone sélectionnée")
        grim -g "$(slurp)" "$FILENAME"
        notify-send "Capture" "Zone sélectionnée sauvée" -i "$FILENAME"
        ;;
    "Fenêtre active")
        # Capturer la fenêtre active
        WINDOW_INFO=$(hyprctl activewindow | grep -E "at:|size:")
        if [[ -n "$WINDOW_INFO" ]]; then
            WINDOW_GEOM=$(echo "$WINDOW_INFO" | awk '/at:/ {x=$2; y=$3} /size:/ {w=$2; h=$3} END {gsub(/,/, "", x); gsub(/,/, "", y); gsub(/,/, "", w); gsub(/,/, "", h); print x","y" "w"x"h}')
            grim -g "$WINDOW_GEOM" "$FILENAME"
            notify-send "Capture" "Fenêtre active sauvée" -i "$FILENAME"
        else
            notify-send "Erreur" "Impossible de capturer la fenêtre active"
        fi
        ;;
    "Retard 3 secondes")
        notify-send "Capture retardée" "3 secondes..." -t 1000
        sleep 3
        grim "$FILENAME"
        notify-send "Capture" "Capture retardée sauvée" -i "$FILENAME"
        ;;
    "Enregistrement écran")
        # Utiliser wf-recorder si disponible
        if command -v wf-recorder &>/dev/null; then
            RECORD_FILE="$SCREENSHOT_DIR/recording_$TIMESTAMP.mp4"
            notify-send "Enregistrement" "Démarré - Ctrl+C pour arrêter"
            wf-recorder -f "$RECORD_FILE" -g "$(slurp)"
            notify-send "Enregistrement" "Sauvé: $(basename "$RECORD_FILE")"
        else
            notify-send "Erreur" "wf-recorder non installé"
        fi
        ;;
    "Presse-papiers")
        grim -g "$(slurp)" - | wl-copy
        notify-send "Presse-papiers" "Capture copiée"
        ;;
esac

# Ouvrir le dossier si demandé
if [[ -f "$FILENAME" ]] && command -v thunar &>/dev/null; then
    if [[ $(notify-send "Capture terminée" "Ouvrir le dossier?" --action="open=Ouvrir") == "open" ]]; then
        thunar "$SCREENSHOT_DIR"
    fi
fi
EOF

    log "SUCCESS" "Menu de capture d'écran créé"
}

create_power_menu() {
    log "INFO" "Création du menu de gestion d'énergie"
    
    cat > ~/.local/bin/power-menu << 'EOF'
#!/bin/bash
# Menu de gestion d'énergie avec confirmations

OPTIONS="Verrouiller
Déconnexion
Redémarrer
Éteindre
Suspension
Économie d'énergie
Performance"

CHOICE=$(echo -e "$OPTIONS" | wofi --dmenu --prompt "⚡ Gestion de l'énergie" --width 300)

confirm_action() {
    local action=$1
    local confirmation=$(echo -e "Confirmer\n Annuler" | wofi --dmenu --prompt "$action")
    [[ "$confirmation" == "Confirmer" ]]
}

case "$CHOICE" in
    "Verrouiller")
        hyprlock
        ;;
    "Déconnexion")
        if confirm_action "Déconnexion"; then
            hyprctl dispatch exit
        fi
        ;;
    "Redémarrer")
        if confirm_action "Redémarrage système"; then
            systemctl reboot
        fi
        ;;
    "⚻ Éteindre")
        if confirm_action "Arrêt système"; then
            systemctl poweroff
        fi
        ;;
    "Suspension")
        systemctl suspend
        ;;
    "Économie d'énergie")
        # Profile économie d'énergie
        if command -v powerprofilesctl &>/dev/null; then
            powerprofilesctl set power-saver
            notify-send "Économie" "Profil économique activé"
        fi
        # Réduction luminosité
        brightnessctl set 30%
        ;;
    "Performance")
        # Profile performance
        if command -v powerprofilesctl &>/dev/null; then
            powerprofilesctl set performance
            notify-send "⚡ Performance" "Profil performance activé"
        fi
        # Augmentation luminosité
        brightnessctl set 80%
        ;;
esac
EOF

    log "SUCCESS" "Menu de gestion d'énergie créé"
}

create_system_monitor() {
    log "INFO" "Création du moniteur système"
    
    cat > ~/.local/bin/system-monitor << 'EOF'
#!/bin/bash
# Moniteur système en temps réel pour terminal

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fonction pour obtenir les informations CPU
get_cpu_info() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    local cpu_temp=""
    
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        cpu_temp=$(awk '{printf "%.1f°C", $1/1000}' /sys/class/thermal/thermal_zone0/temp)
    fi
    
    echo -e "${BLUE}CPU:${NC} ${cpu_usage}% | ${YELLOW}Temp:${NC} ${cpu_temp}"
}

# Fonction pour obtenir les informations RAM
get_memory_info() {
    local mem_info=$(free -h | awk '/^Mem:/ {printf "%.1f/%.1f GB (%.0f%%)", $3, $2, ($3/$2)*100}')
    echo -e "${GREEN}RAM:${NC} $mem_info"
}

# Fonction pour obtenir les informations disque
get_disk_info() {
    local disk_info=$(df -h / | awk 'NR==2 {printf "%s/%s (%s)", $3, $2, $5}')
    echo -e "${CYAN}Disk:${NC} $disk_info"
}

# Fonction pour obtenir les informations réseau
get_network_info() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -n "$interface" ]]; then
        local ip=$(ip addr show "$interface" | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        local status=$(cat /sys/class/net/"$interface"/operstate 2>/dev/null || echo "unknown")
        echo -e "${PURPLE}Network:${NC} $interface ($ip) - $status"
    else
        echo -e "${RED}Network:${NC} Disconnected"
    fi
}

# Fonction pour obtenir les informations GPU
get_gpu_info() {
    if command -v nvidia-smi &>/dev/null; then
        local gpu_info=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
        if [[ -n "$gpu_info" ]]; then
            echo "$gpu_info" | awk -F', ' '{printf "GPU: %s%% | VRAM: %s/%sMB | %s°C", $1, $2, $3, $4}'
        fi
    elif lspci | grep -i "vga\|3d" | grep -qi "amd"; then
        echo "GPU: AMD (no monitoring available)"
    elif lspci | grep -i "vga\|3d" | grep -qi "intel"; then
        echo "GPU: Intel Graphics"
    fi
}

# Fonction pour obtenir les informations batterie
get_battery_info() {
    if [[ -d /sys/class/power_supply/BAT0 ]]; then
        local capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
        local status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
        echo -e "${YELLOW}Battery:${NC} $capacity% ($status)"
    fi
}

# Fonction principale de monitoring
show_system_info() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}          ${CYAN}SYSTEM MONITOR${NC}              ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}$(date '+%H:%M:%S %d/%m/%Y')${NC}"
    echo -e "${WHITE}Uptime: $(uptime -p)${NC}"
    echo ""
    
    get_cpu_info
    get_memory_info  
    get_disk_info
    get_network_info
    
    local gpu_info=$(get_gpu_info)
    [[ -n "$gpu_info" ]] && echo -e "$gpu_info"
    
    get_battery_info
    
    echo ""
    echo -e "${WHITE}Processes:${NC} $(ps -e --no-headers | wc -l)"
    echo -e "${WHITE}User:${NC} $USER@$(hostname)"
    echo ""
    echo -e "${GRAY}Press Ctrl+C to exit${NC}"
}

# Mode interactif ou one-shot
if [[ "$1" == "--once" ]]; then
    show_system_info
else
    # Mode monitoring continu
    while true; do
        show_system_info
        sleep 2
    done
fi
EOF

    log "SUCCESS" "Moniteur système créé"
}

# Script de changement de thème
create_theme_switcher() {
    log "INFO" "Création du changeur de thème"
    
    cat > ~/.local/bin/theme-switcher << 'EOF'
#!/bin/bash
# Changeur de thème Hyprland dynamique

THEMES_DIR="$HOME/.config/hypr/themes"
CURRENT_THEME_FILE="$HOME/.cache/current_theme"
HYPRLAND_CONF="$HOME/.config/hypr/hyprland.conf"

mkdir -p "$THEMES_DIR"

# Thèmes disponibles
declare -A THEMES=(
    ["Arcane/Fallout"]="arcane"
    ["Nord Dark"]="nord"
    ["Dracula"]="dracula" 
    ["Gruvbox Dark"]="gruvbox"
    ["Catppuccin"]="catppuccin"
    ["Tokyo Night"]="tokyo-night"
)

# Couleurs par thème
get_theme_colors() {
    local theme=$1
    case $theme in
        "arcane")
            echo "rgba(33ccffee) rgba(00ff99ee) 45deg|rgba(44475aaa)|rgba(1a1a1aee)"
            ;;
        "nord")
            echo "rgba(88c0d0ee) rgba(81a1c1ee) 45deg|rgba(4c566aaa)|rgba(2e3440ee)"
            ;;
        "dracula")
            echo "rgba(bd93f9ee) rgba(ff79c6ee) 45deg|rgba(44475aaa)|rgba(282a36ee)"
            ;;
        "gruvbox")
            echo "rgba(fe8019ee) rgba(fabd2fee) 45deg|rgba(504945aa)|rgba(1d2021ee)"
            ;;
        "catppuccin")
            echo "rgba(89b4faee) rgba(cba6f7ee) 45deg|rgba(45475aaa)|rgba(1e1e2eee)"
            ;;
        "tokyo-night")
            echo "rgba(7aa2f7ee) rgba(bb9af7ee) 45deg|rgba(414868aa)|rgba(24283bee)"
            ;;
        *)
            echo "rgba(33ccffee) rgba(00ff99ee) 45deg|rgba(44475aaa)|rgba(1a1a1aee)"
            ;;
    esac
}

# Appliquer un thème
apply_theme() {
    local theme_key=$1
    local colors=$(get_theme_colors "$theme_key")
    
    IFS='|' read -r active_border inactive_border shadow_color <<< "$colors"
    
    # Backup de la configuration actuelle
    cp "$HYPRLAND_CONF" "${HYPRLAND_CONF}.backup"
    
    # Modifier les couleurs dans la configuration
    sed -i "s/col\.active_border = .*/col.active_border = $active_border/" "$HYPRLAND_CONF"
    sed -i "s/col\.inactive_border = .*/col.inactive_border = $inactive_border/" "$HYPRLAND_CONF"
    sed -i "s/col\.shadow = .*/col.shadow = $shadow_color/" "$HYPRLAND_CONF"
    
    # Sauvegarder le thème actuel
    echo "$theme_key" > "$CURRENT_THEME_FILE"
    
    # Recharger Hyprland
    hyprctl reload
    
    # Mettre à jour Waybar si nécessaire
    if pgrep waybar >/dev/null; then
        pkill waybar
        sleep 0.5
        waybar &
    fi
    
    notify-send "Thème" "Thème $theme_key appliqué"
}

# Interface de sélection
if [[ "$1" == "--menu" ]] || [[ -z "$1" ]]; then
    # Menu interactif
    THEME_LIST=""
    for theme_name in "${!THEMES[@]}"; do
        THEME_LIST="$THEME_LIST$theme_name\n"
    done
    
    SELECTED=$(echo -e "$THEME_LIST" | wofi --dmenu --prompt "Sélectionner un thème")
    
    if [[ -n "$SELECTED" ]] && [[ -n "${THEMES[$SELECTED]}" ]]; then
        apply_theme "${THEMES[$SELECTED]}"
    fi
elif [[ "$1" == "--current" ]]; then
    # Afficher le thème actuel
    if [[ -f "$CURRENT_THEME_FILE" ]]; then
        cat "$CURRENT_THEME_FILE"
    else
        echo "arcane"
    fi
elif [[ -n "${THEMES[$1]}" ]]; then
    # Appliquer un thème spécifique
    apply_theme "${THEMES[$1]}"
else
    echo "Usage: $0 [--menu|--current|theme_name]"
    echo "Thèmes disponibles: ${!THEMES[*]}"
fi
EOF

    log "SUCCESS" "Changeur de thème créé"
}

# Fonction principale
main() {
    log "HEADER" "Démarrage de l'installation Hyprland Universal"
    
    # Gestion des arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --waybar-bottom)
                WAYBAR_POSITION="bottom"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log "ERROR" "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Banner
    show_banner
    
    # Vérifications préliminaires
    check_privileges
    
    # Détection du système
    detect_distribution
    detect_init_system
    detect_current_environment
    detect_gpu
    check_wayland_support
    evaluate_compatibility
    
    # Création du backup
    log "INFO" "Création d'un backup dans $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Backup des configurations existantes
    [[ -d ~/.config/hypr ]] && cp -r ~/.config/hypr "$BACKUP_DIR/"
    [[ -d ~/.config/waybar ]] && cp -r ~/.config/waybar "$BACKUP_DIR/"
    
    # Installation des composants
    if confirm_action "Procéder à l'installation de Hyprland et des composants?"; then
        install_hyprland_distro
        install_gpu_drivers_universal
        configure_display_manager
    fi
    
    # Configuration des applications
    if confirm_action "Configurer les applications et thèmes?"; then
        create_waybar_config
        create_hyprland_config
        configure_applications
        create_advanced_scripts
    fi
    
    # Services
    if confirm_action "Activer les services système?"; then
        enable_services
    fi
    
    # Rapport final
    generate_final_report
    
    log "SUCCESS" "🎉 Installation Hyprland terminée avec succès!"
    log "INFO" "Redémarrez votre système et sélectionnez Hyprland au login"
}

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
██╗  ██╗██╗   ██╗██████╗ ██████╗ ██╗      █████╗ ███╗   ██╗██████╗ 
██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██║     ██╔══██╗████╗  ██║██╔══██╗
███████║ ╚████╔╝ ██████╔╝██████╔╝██║     ███████║██╔██╗ ██║██║  ██║
██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗██║     ██╔══██║██║╚██╗██║██║  ██║
██║  ██║   ██║   ██║     ██║  ██║███████╗██║  ██║██║ ╚████║██████╔╝
╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ 

EOF
    echo -e "${NC}"
}

show_help() {
    cat << EOF
Hyprland Universal Deployment Script v$SCRIPT_VERSION

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run           Test sans installation
    --verbose           Logs détaillés  
    --force            Forcer l'installation
    --waybar-bottom    Barre des tâches en bas (Windows-style)
    --help             Afficher cette aide

EXEMPLES:
    $0                          # Installation interactive
    $0 --dry-run --verbose      # Test avec logs détaillés
    $0 --force --waybar-bottom  # Installation forcée avec barre en bas

SUPPORT: Arch, Debian/Ubuntu, Fedora, openSUSE, Void Linux
GPU: NVIDIA, AMD, Intel avec optimisations adaptatives

EOF
}

configure_applications() {
    log "HEADER" "Configuration des applications principales"
    
    # Configuration Kitty (terminal)
    configure_kitty_universal
    
    # Configuration Wofi (lanceur d'applications)
    configure_wofi_universal
    
    # Configuration Dunst (notifications)
    configure_dunst_universal
    
    # Configuration Thunar (gestionnaire de fichiers)
    configure_thunar_universal
    
    # Configuration Hypridle/Hyprlock
    configure_idle_lock
    
    log "SUCCESS" "Configuration des applications terminée"
}

# Configuration finale et activation des services
enable_services() {
    log "HEADER" "Activation des services système"
    
    case $INIT_SYSTEM in
        systemd)
            # Services essentiels
            sudo systemctl enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
            sudo systemctl enable --now bluetooth NetworkManager 2>/dev/null || true
            
            # Gestionnaire d'affichage
            if systemctl list-unit-files | grep -q "sddm.service"; then
                sudo systemctl enable sddm
            elif systemctl list-unit-files | grep -q "gdm.service"; then
                sudo systemctl enable gdm
            fi
            ;;
        *)
            log "WARNING" "Système d'init non-systemd, activation manuelle nécessaire"
            ;;
    esac
    
    log "SUCCESS" "Services activés"
}

generate_final_report() {
    log "HEADER" "Génération du rapport final"
    
    local report_file="$HOME/hyprland-installation-report.txt"
    
    cat > "$report_file" << EOF
# =============================================================================
# Rapport d'installation Hyprland Universal
# Date: $(date)
# =============================================================================

## SYSTÈME DÉTECTÉ
- Distribution: $DISTRO ($DISTRO_FAMILY)
- Architecture: $(uname -m)
- Kernel: $(uname -r)
- GPU: $GPU_VENDOR ($GPU_TYPE)
- Init: $INIT_SYSTEM
- Score compatibilité: $COMPATIBILITY_SCORE/100

## COMPOSANTS INSTALLÉS
- Hyprland (compositeur Wayland)
- Waybar (barre des tâches professionnelle - position: $WAYBAR_POSITION)
- Wofi (lanceur d'applications)
- Kitty (terminal)
- Thunar (gestionnaire de fichiers)
- Dunst (notifications)
- Drivers GPU optimisés

## RACCOURCIS CLAVIER PRINCIPAUX
- Super + Q : Terminal
- Super + E : Gestionnaire de fichiers
- Super + R : Menu applications
- Super + L : Verrouillage
- Super + F : Plein écran
- Super + 1-9 : Workspaces
- Print : Capture d'écran
- Super + Shift + L : Menu énergie

## FICHIERS DE CONFIGURATION
- ~/.config/hypr/hyprland.conf (configuration principale)
- ~/.config/waybar/ (barre des tâches)
- ~/.config/wofi/ (lanceur)
- ~/.config/kitty/kitty.conf (terminal)
- ~/.local/bin/ (scripts utilitaires)

## SCRIPTS UTILITAIRES
- screenshot-menu : Capture d'écran avancée
- power-menu : Gestion d'énergie
- theme-switcher : Changement de thèmes
- system-monitor : Monitoring système

## BACKUP
Backup créé dans: $BACKUP_DIR

## LOGS
Logs détaillés: $LOG_FILE

## PROCHAINES ÉTAPES
1. Redémarrer le système
2. Sélectionner "Hyprland" au gestionnaire de connexion
3. Personnaliser les wallpapers dans ~/Pictures/Wallpapers/
4. Tester les raccourcis clavier
5. Configurer les applications supplémentaires

## DÉPANNAGE
- Logs en temps réel: tail -f ~/.cache/hyprland.log
- Test GPU: glxinfo | grep OpenGL
- Diagnostic complet: ~/.local/bin/hyprland-diagnostics

## SUPPORT
- Documentation officielle: https://wiki.hyprland.org/
- GitHub: https://github.com/hyprwm/Hyprland
- Wiki Arch: https://wiki.archlinux.org/title/Hyprland

EOF

    log "SUCCESS" "Rapport généré: $report_file"
}

configure_kitty_universal() {
    log "INFO" "Configuration de Kitty (terminal)"
    
    mkdir -p ~/.config/kitty
    
    cat > ~/.config/kitty/kitty.conf << 'EOF'
# =============================================================================
# Configuration Kitty - Thème Arcane/Fallout Universal
# =============================================================================

# Police
font_family      JetBrains Mono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        12.0

# Transparence adaptée selon GPU
background_opacity 0.95
dynamic_background_opacity yes

# Curseur
cursor_shape block
cursor_blink_interval 0.5
cursor_stop_blinking_after 15.0

# Scrollback
scrollback_lines 10000
scrollback_pager less --chop-long-lines --RAW-CONTROL-CHARS +INPUT_LINE_NUMBER

# URLs
url_color #33ccff
url_style curly
open_url_with default

# Sélection
selection_foreground #000000
selection_background #fffacd
copy_on_select no

# Couleurs - Thème Arcane/Fallout
foreground            #f8f8f2
background            #0f0f23
selection_foreground  #000000
selection_background  #44475a
cursor                #f8f8f2
cursor_text_color     #0f0f23

# Couleurs normales
color0  #21222c
color1  #ff5555
color2  #50fa7b
color3  #f1fa8c
color4  #bd93f9
color5  #ff79c6
color6  #8be9fd
color7  #f8f8f2

# Couleurs claires
color8  #6272a4
color9  #ff6e6e
color10 #69ff94
color11 #ffffa5
color12 #d6acff
color13 #ff92df
color14 #a4ffff
color15 #ffffff

# Gestion des fenêtres
window_padding_width 10
hide_window_decorations titlebar-only
window_logo_path none
window_logo_position bottom-right
window_logo_alpha 0.3

# Tabs
tab_bar_edge bottom
tab_bar_style powerline
tab_powerline_style slanted
active_tab_foreground   #000
active_tab_background   #33ccff
active_tab_font_style   bold
inactive_tab_foreground #f8f8f2
inactive_tab_background #44475a
inactive_tab_font_style normal

# Performance
repaint_delay 10
input_delay 3
sync_to_monitor yes

# Comportement
enable_audio_bell no
visual_bell_duration 0.0
window_alert_on_bell yes
bell_on_tab yes
command_on_bell none

# Shell
shell .
editor .
close_on_child_death no
allow_remote_control yes
update_check_interval 0

# Raccourcis
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard
map ctrl+shift+equal change_font_size all +2.0
map ctrl+shift+minus change_font_size all -2.0
map ctrl+shift+backspace change_font_size all 0
EOF

    log "SUCCESS" "Configuration Kitty créée"
}

configure_wofi_universal() {
    log "INFO" "Configuration de Wofi (lanceur)"
    
    mkdir -p ~/.config/wofi
    
    cat > ~/.config/wofi/config << 'EOF'
# Configuration Wofi Universal
width=800
height=600
location=center
show=drun
prompt=Applications
filter_rate=100
allow_markup=true
no_actions=true
halign=fill
orientation=vertical
content_halign=fill
insensitive=true
allow_images=true
image_size=48
gtk_dark=true
dynamic_lines=true
matching=fuzzy
EOF

    cat > ~/.config/wofi/style.css << 'EOF'
* {
    font-family: 'JetBrains Mono Nerd Font', 'Fira Code', monospace;
    font-size: 14px;
    transition: all 0.3s ease;
}

window {
    margin: 0px;
    border: 3px solid #33ccff;
    background: linear-gradient(135deg, 
        rgba(15, 15, 35, 0.98) 0%, 
        rgba(25, 25, 55, 0.95) 50%, 
        rgba(15, 15, 35, 0.98) 100%);
    border-radius: 20px;
    box-shadow: 
        0 20px 50px rgba(0, 0, 0, 0.5),
        0 0 0 1px rgba(51, 204, 255, 0.3) inset;
    backdrop-filter: blur(25px);
    -webkit-backdrop-filter: blur(25px);
}

#input {
    margin: 15px 20px 10px 20px;
    border: 2px solid #33ccff;
    color: #ffffff;
    background: linear-gradient(135deg, 
        rgba(0, 0, 0, 0.6) 0%, 
        rgba(51, 204, 255, 0.1) 100%);
    border-radius: 15px;
    padding: 15px 20px;
    font-size: 16px;
    font-weight: 500;
    box-shadow: 
        0 0 20px rgba(51, 204, 255, 0.3) inset,
        0 4px 15px rgba(0, 0, 0, 0.3);
}

#input:focus {
    border-color: #00ff99;
    background: linear-gradient(135deg, 
        rgba(0, 0, 0, 0.7) 0%, 
        rgba(0, 255, 153, 0.1) 100%);
    box-shadow: 
        0 0 25px rgba(0, 255, 153, 0.4) inset,
        0 0 30px rgba(0, 255, 153, 0.3);
}

#inner-box {
    margin: 10px 20px 20px 20px;
    border: none;
    background: transparent;
    border-radius: 15px;
}

#outer-box {
    margin: 5px;
    border: none;
    background: transparent;
}

#scroll {
    margin: 0px;
    border: none;
    border-radius: 15px;
}

#text {
    margin: 5px;
    border: none;
    color: #ffffff;
    font-weight: 500;
}

#entry {
    border-radius: 12px;
    margin: 3px 5px;
    padding: 10px 15px;
    background: transparent;
    border: 1px solid transparent;
    transition: all 0.3s cubic-bezier(0.4, 0.0, 0.2, 1);
}

#entry:selected {
    background: linear-gradient(135deg, 
        rgba(51, 204, 255, 0.25) 0%, 
        rgba(0, 255, 153, 0.15) 100%);
    border: 1px solid rgba(51, 204, 255, 0.5);
    box-shadow: 
        0 0 20px rgba(51, 204, 255, 0.3),
        0 4px 15px rgba(0, 0, 0, 0.2);
    transform: translateY(-2px) scale(1.02);
}

#text:selected {
    color: #33ccff;
    font-weight: bold;
    text-shadow: 0 0 10px rgba(51, 204, 255, 0.5);
}

#entry image {
    margin-right: 10px;
    border-radius: 8px;
}

/* Scrollbar */
scrollbar slider {
    background: linear-gradient(135deg, #33ccff, #00ff99);
    border-radius: 10px;
    border: none;
}

scrollbar slider:hover {
    background: linear-gradient(135deg, #00ff99, #33ccff);
}

scrollbar {
    background: rgba(0, 0, 0, 0.2);
    border-radius: 10px;
    margin: 10px;
}
EOF

    log "SUCCESS" "Configuration Wofi créée"
}

configure_dunst_universal() {
    log "INFO" "Configuration de Dunst (notifications)"
    
    mkdir -p ~/.config/dunst
    
    cat > ~/.config/dunst/dunstrc << 'EOF'

[global]
    ### Display ###
    monitor = 0
    follow = none
    
    ### Geometry ###
    width = (300, 500)
    height = 300
    origin = top-right
    offset = 20x50
    scale = 0
    notification_limit = 5
    
    ### Progress bar ###
    progress_bar = true
    progress_bar_height = 12
    progress_bar_frame_width = 2
    progress_bar_min_width = 200
    progress_bar_max_width = 400
    progress_bar_corner_radius = 6
    
    ### Apparence ###
    transparency = 15
    separator_height = 3
    padding = 15
    horizontal_padding = 20
    text_icon_padding = 10
    frame_width = 3
    frame_color = "#33ccff"
    gap_size = 8
    separator_color = frame
    sort = yes
    idle_threshold = 120
    
    ### Text ###
    font = JetBrains Mono Nerd Font 12
    line_height = 2
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    vertical_alignment = center
    show_age_threshold = 60
    word_wrap = yes
    ellipsize = middle
    ignore_newline = no
    stack_duplicates = true
    hide_duplicate_count = false
    show_indicators = yes
    
    ### Icons ###
    icon_position = left
    min_icon_size = 48
    max_icon_size = 64
    icon_path = /usr/share/icons/Papirus-Dark/48x48/status/:/usr/share/icons/Papirus-Dark/48x48/devices/:/usr/share/icons/Papirus-Dark/48x48/apps/
    
    ### History ###
    sticky_history = yes
    history_length = 50
    
    ### Misc/Advanced ###
    dmenu = /usr/bin/wofi --dmenu -p dunst:
    browser = /usr/bin/xdg-open
    always_run_script = true
    title = Dunst
    class = Dunst
    corner_radius = 15
    ignore_dbusclose = false
    force_xwayland = false
    force_xinerama = false
    
    ### Mouse ###
    mouse_left_click = close_current
    mouse_middle_click = do_action, close_current
    mouse_right_click = close_all

[experimental]
    per_monitor_dpi = false

[urgency_low]
    background = "#0f0f23e6"
    foreground = "#ffffff"
    highlight = "#33ccff"
    frame_color = "#33ccff80"
    timeout = 8
    
[urgency_normal]
    background = "#0f0f23e6"
    foreground = "#ffffff"
    highlight = "#00ff99"
    frame_color = "#33ccff"
    timeout = 10

[urgency_critical]
    background = "#ff5555e6"
    foreground = "#ffffff"
    highlight = "#ffffff"
    frame_color = "#ff5555"
    timeout = 0

# Règles spéciales
[spotify]
    appname = "Spotify"
    background = "#1db954e6"
    foreground = "#ffffff"
    frame_color = "#1db954"
    timeout = 5

[volume]
    appname = "volume"
    background = "#6c5ce7e6"
    foreground = "#ffffff"
    frame_color = "#6c5ce7"
    timeout = 3

[brightness]
    appname = "brightness"
    background = "#fdcb6ee6" 
    foreground = "#2d3436"
    frame_color = "#fdcb6e"
    timeout = 3
EOF

    log "SUCCESS" "Configuration Dunst créée"
}

configure_thunar_universal() {
    log "INFO" "Configuration de Thunar (gestionnaire de fichiers)"
    
    mkdir -p ~/.config/thunar
    
    # Configuration basique pour Thunar
    cat > ~/.config/thunar/thunarrc << 'EOF'
[Configuration]
DefaultView=ThunarIconView
LastCompactViewZoomLevel=THUNAR_ZOOM_LEVEL_SMALLEST
LastDetailsViewColumnOrder=THUNAR_COLUMN_NAME,THUNAR_COLUMN_SIZE,THUNAR_COLUMN_TYPE,THUNAR_COLUMN_DATE_MODIFIED
LastDetailsViewColumnWidths=50,50,50,50
LastDetailsViewFixedColumns=FALSE
LastDetailsViewVisibleColumns=THUNAR_COLUMN_DATE_MODIFIED,THUNAR_COLUMN_NAME,THUNAR_COLUMN_SIZE,THUNAR_COLUMN_TYPE
LastDetailsViewZoomLevel=THUNAR_ZOOM_LEVEL_SMALLER
LastIconViewZoomLevel=THUNAR_ZOOM_LEVEL_NORMAL
LastLocationBarPath=
LastSeparatorPosition=170
LastShowHidden=TRUE
LastSidePane=ThunarTreePane
LastSortColumn=THUNAR_COLUMN_NAME
LastSortOrder=GTK_SORT_ASCENDING
LastStatusbarVisible=TRUE
LastView=ThunarIconView
LastWindowHeight=480
LastWindowWidth=640
LastWindowMaximized=FALSE
MiscVolumeManagement=TRUE
MiscCaseSensitive=FALSE
MiscDateStyle=THUNAR_DATE_STYLE_SIMPLE
MiscFoldersFirst=TRUE
MiscHorizontalWheelNavigates=FALSE
MiscRecursivePermissions=THUNAR_RECURSIVE_PERMISSIONS_ASK
MiscRememberGeometry=TRUE
MiscShowAboutTemplates=TRUE
MiscShowThumbnails=TRUE
MiscSingleClick=FALSE
MiscSingleClickTimeout=500
MiscTextBesideIcons=FALSE
ShortcutsIconEmblems=TRUE
ShortcutsIconSize=THUNAR_ICON_SIZE_SMALLER
SidePane=ThunarTreePane
StatusbarVisible=TRUE
TreeIconEmblems=TRUE
TreeIconSize=THUNAR_ICON_SIZE_SMALLEST
EOF

    log "SUCCESS" "Configuration Thunar créée"
}

configure_idle_lock() {
    log "INFO" "Configuration de Hypridle et Hyprlock"
    
    mkdir -p ~/.config/hypr
    
    # Configuration Hypridle
    cat > ~/.config/hypr/hypridle.conf << 'EOF'
# =============================================================================
# Configuration Hypridle - Gestion de l'inactivité
# =============================================================================

general {
    after_sleep_cmd = hyprctl dispatch dpms on
    before_sleep_cmd = loginctl lock-session
    ignore_dbus_inhibit = false
}

# Verrouillage après 5 minutes
listener {
    timeout = 300
    on-timeout = hyprlock
}

# Écran en veille après 10 minutes
listener {
    timeout = 600
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

# Suspension après 30 minutes
listener {
    timeout = 1800
    on-timeout = systemctl suspend
}
EOF

    # Configuration Hyprlock
    cat > ~/.config/hypr/hyprlock.conf << 'EOF'
# =============================================================================
# Configuration Hyprlock - Écran de verrouillage Arcane/Fallout
# =============================================================================

general {
    disable_loading_bar = true
    grace = 300
    hide_cursor = true
    no_fade_in = false
    no_fade_out = false
}

background {
    monitor = 
    path = ~/Pictures/Wallpapers/lock-screen.jpg
    blur_passes = 3
    blur_size = 8
    noise = 0.0117
    contrast = 0.8916
    brightness = 0.8172
    vibrancy = 0.1696
    vibrancy_darkness = 0.0
}

# Zone de saisie du mot de passe
input-field {
    monitor = 
    size = 400, 60
    outline_thickness = 4
    dots_size = 0.33
    dots_spacing = 0.15
    dots_center = false
    dots_rounding = -1
    outer_color = rgb(33ccff)
    inner_color = rgb(0f0f23)
    font_color = rgb(ffffff)
    fade_on_empty = true
    fade_timeout = 1000
    placeholder_text = <i>Mot de passe...</i>
    hide_input = false
    rounding = 12
    check_color = rgb(00ff99)
    fail_color = rgb(ff5555)
    fail_text = <i>$FAIL <b>($ATTEMPTS)</b></i>
    fail_transition = 300
    
    position = 0, -20
    halign = center
    valign = center
}

# Horloge
label {
    monitor = 
    text = cmd[update:1000] echo "$TIME"
    color = rgb(33ccff)
    font_size = 90
    font_family = JetBrains Mono Nerd Font
    shadow_passes = 5
    shadow_size = 10
    
    position = 0, 160
    halign = center
    valign = center
}

# Date
label {
    monitor = 
    text = cmd[update:43200000] date +"%A, %d %B %Y"
    color = rgb(ffffff)
    font_size = 25
    font_family = JetBrains Mono Nerd Font
    
    position = 0, 75
    halign = center
    valign = center
}

# Message de bienvenue
label {
    monitor = 
    text = Bienvenue dans le Wasteland
    color = rgb(00ff99)
    font_size = 20
    font_family = JetBrains Mono Nerd Font
    
    position = 0, -150
    halign = center
    valign = center
}
EOF

    log "SUCCESS" "Configuration Hypridle et Hyprlock créée"
}

# Nettoyage final et mise à jour
cleanup_and_finalize() {
    log "HEADER" "Finalisation et nettoyage"
    
    # Nettoyage des caches de compilation
    if [[ -d /tmp/hyprland-build ]]; then
        rm -rf /tmp/hyprland-build
    fi
    
    # Mise à jour des bases de données
    case $PACKAGE_MANAGER in
        pacman)
            sudo pacman -Sc --noconfirm >/dev/null 2>&1 || true
            ;;
        apt)
            sudo apt autoremove -y >/dev/null 2>&1 || true
            sudo apt autoclean >/dev/null 2>&1 || true
            ;;
        dnf)
            sudo dnf autoremove -y >/dev/null 2>&1 || true
            sudo dnf clean all >/dev/null 2>&1 || true
            ;;
    esac
    
    # Mise à jour des icônes et thèmes
    if command -v gtk-update-icon-cache &>/dev/null; then
        gtk-update-icon-cache -f -t ~/.local/share/icons/ 2>/dev/null || true
    fi
    
    # Rechargement des services utilisateur
    systemctl --user daemon-reload 2>/dev/null || true
    
    log "SUCCESS" "Nettoyage terminé"
}

# Point d'entrée principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
#!/bin/bash

# Hyprland Universel - Version je sais plus combien
# Déploiement intelligent multi-distributions avec Waybar comme élément central
# Support: Arch, Debian/Ubuntu, Fedora, openSUSE, Void Linux
# Thème: Arcane/Fallout avec transparence et blur
# Version: 24/08/2025

set -eE

# Informations du script
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="Hyprland Universal Deploy"
readonly AUTHOR="Auto-Generated Multi-Distro Script"

# Couleurs pour les messages
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;37m'
readonly NC='\033[0m' # No Color

# Variables de détection système
DISTRO=""
DISTRO_FAMILY=""
PACKAGE_MANAGER=""
INIT_SYSTEM=""
DISPLAY_SERVER=""
GPU_VENDOR=""
GPU_TYPE=""
WAYLAND_SUPPORT=false
COMPATIBILITY_SCORE=0

# Variables de configuration
DRY_RUN=false
VERBOSE=false
FORCE_INSTALL=false
KEEP_DE=false
WAYBAR_POSITION="top"  # top (macOS) ou bottom (Windows)
LOG_FILE="$HOME/hyprland-deploy.log"
BACKUP_DIR="$HOME/.hyprland-backup-$(date +%Y%m%d_%H%M%S)"

# Drapeaux GPU
IS_NVIDIA=false
IS_AMD=false
IS_INTEL=false

# Dépendances critiques par famille de distribution
declare -A CRITICAL_DEPS=(
    ["arch"]="base-devel git wayland wayland-protocols"
    ["debian"]="build-essential git libwayland-dev wayland-protocols"
    ["fedora"]="@development-tools git wayland-devel wayland-protocols-devel"
    ["opensuse"]="patterns-devel-base-devel_basis git wayland-devel wayland-protocols-devel"
    ["void"]="base-devel git wayland-devel wayland-protocols"
)

# Fonction de logging avancée
log() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case $level in
        "ERROR")   echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$LOG_FILE" ;;
        "WARNING") echo -e "${YELLOW}[WARNING]${NC} $message" | tee -a "$LOG_FILE" ;;
        "INFO")    echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE" ;;
        "DEBUG")   $VERBOSE && echo -e "${GRAY}[DEBUG]${NC} $message" | tee -a "$LOG_FILE" ;;
        "HEADER")  echo -e "${PURPLE}=== $message ===${NC}" | tee -a "$LOG_FILE" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Gestion d'erreurs globale
handle_error() {
    local exit_code=$?
    local line_number=$1
    log "ERROR" "Erreur ligne $line_number (code: $exit_code)"
    log "ERROR" "Consultez le log: $LOG_FILE"
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# Vérification des privilèges
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        log "ERROR" "Ce script ne doit pas être exécuté en tant que root"
        log "INFO" "Utilisez un utilisateur normal avec accès sudo"
        exit 1
    fi
    
    if ! sudo -n true 2>/dev/null; then
        log "WARNING" "Privilèges sudo requis - veuillez entrer votre mot de passe"
        sudo -v || {
            log "ERROR" "Impossible d'obtenir les privilèges sudo"
            exit 1
        }
    fi
}

# Fonction de confirmation interactive
confirm_action() {
    local message=$1
    local default=${2:-"n"}
    
    if $FORCE_INSTALL; then
        return 0
    fi
    
    while true; do
        echo -ne "${CYAN}$message${NC} (y/n) [${default}]: "
        read -r response
        response=${response:-$default}
        
        case $response in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) log "WARNING" "Répondez par 'y' ou 'n'" ;;
        esac
    done
}

# Détection de la distribution Linux
detect_distribution() {
    log "HEADER" "Détection de la distribution Linux"
    
    # Détection via /etc/os-release
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        local distro_id="${ID,,}"
        local distro_like="${ID_LIKE,,}"
        
        log "DEBUG" "ID: $distro_id, ID_LIKE: $distro_like, VERSION: ${VERSION_ID:-unknown}"
        
        case $distro_id in
            arch|manjaro|endeavouros|artix)
                DISTRO="Arch Linux"
                DISTRO_FAMILY="arch"
                PACKAGE_MANAGER="pacman"
                ;;
            ubuntu|mint|elementary|zorin|pop)
                DISTRO="Ubuntu/Debian"
                DISTRO_FAMILY="debian"
                PACKAGE_MANAGER="apt"
                ;;
            debian|kali|parrot)
                DISTRO="Debian"
                DISTRO_FAMILY="debian"
                PACKAGE_MANAGER="apt"
                ;;
            fedora|nobara)
                DISTRO="Fedora"
                DISTRO_FAMILY="fedora"
                PACKAGE_MANAGER="dnf"
                ;;
            rhel|centos|rocky|almalinux)
                DISTRO="Red Hat Enterprise"
                DISTRO_FAMILY="fedora"
                PACKAGE_MANAGER="dnf"
                ;;
            opensuse*|sled|sles)
                DISTRO="openSUSE"
                DISTRO_FAMILY="opensuse"
                PACKAGE_MANAGER="zypper"
                ;;
            void)
                DISTRO="Void Linux"
                DISTRO_FAMILY="void"
                PACKAGE_MANAGER="xbps"
                ;;
            nixos)
                DISTRO="NixOS"
                DISTRO_FAMILY="nixos"
                PACKAGE_MANAGER="nix"
                ;;
            gentoo|funtoo)
                DISTRO="Gentoo"
                DISTRO_FAMILY="gentoo"
                PACKAGE_MANAGER="emerge"
                ;;
            *)
                # Détection fallback via ID_LIKE
                if [[ "$distro_like" == *"arch"* ]]; then
                    DISTRO_FAMILY="arch"
                    PACKAGE_MANAGER="pacman"
                elif [[ "$distro_like" == *"debian"* || "$distro_like" == *"ubuntu"* ]]; then
                    DISTRO_FAMILY="debian"
                    PACKAGE_MANAGER="apt"
                elif [[ "$distro_like" == *"fedora"* || "$distro_like" == *"rhel"* ]]; then
                    DISTRO_FAMILY="fedora"
                    PACKAGE_MANAGER="dnf"
                elif [[ "$distro_like" == *"suse"* ]]; then
                    DISTRO_FAMILY="opensuse"
                    PACKAGE_MANAGER="zypper"
                else
                    DISTRO_FAMILY="unknown"
                    PACKAGE_MANAGER="unknown"
                fi
                ;;
        esac
        
        log "SUCCESS" "Distribution détectée: $DISTRO ($DISTRO_FAMILY)"
        log "DEBUG" "Gestionnaire de paquets: $PACKAGE_MANAGER"
    else
        log "ERROR" "Impossible de détecter la distribution (/etc/os-release manquant)"
        exit 1
    fi
}

detect_init_system() {
    log "INFO" "Détection du système d'initialisation"
    
    if command -v systemctl &>/dev/null && [[ -d /run/systemd/system ]]; then
        INIT_SYSTEM="systemd"
        log "SUCCESS" "Système d'init: systemd"
    elif command -v rc-service &>/dev/null; then
        INIT_SYSTEM="openrc"
        log "SUCCESS" "Système d'init: OpenRC"
        log "WARNING" "Support OpenRC expérimental"
    elif command -v runit &>/dev/null; then
        INIT_SYSTEM="runit"
        log "SUCCESS" "Système d'init: runit"
        log "WARNING" "Support runit expérimental"
    else
        INIT_SYSTEM="unknown"
        log "WARNING" "Système d'init non reconnu ou non supporté"
    fi
}

detect_current_environment() {
    log "INFO" "Détection de l'environnement graphique actuel"
    
    # Détection du serveur d'affichage
    if [[ -n "$WAYLAND_DISPLAY" ]]; then
        DISPLAY_SERVER="wayland"
        log "SUCCESS" "Session Wayland active: $WAYLAND_DISPLAY"
    elif [[ -n "$DISPLAY" ]]; then
        DISPLAY_SERVER="x11"
        log "INFO" "Session X11 active: $DISPLAY"
    else
        DISPLAY_SERVER="none"
        log "WARNING" "Aucun serveur d'affichage détecté"
    fi
    
    # Détection DE/WM actuel
    local current_de=""
    
    if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
        current_de="$XDG_CURRENT_DESKTOP"
    elif [[ -n "$DESKTOP_SESSION" ]]; then
        current_de="$DESKTOP_SESSION"
    elif [[ -n "$GDMSESSION" ]]; then
        current_de="$GDMSESSION"
    fi
    
    if [[ -n "$current_de" ]]; then
        log "INFO" "Environnement de bureau actuel: $current_de"
        
        # Vérification des conflits potentiels
        case "${current_de,,}" in
            *gnome*|*kde*|*xfce*|*lxde*|*mate*|*cinnamon*)
                log "WARNING" "Environnement de bureau lourd détecté"
                log "INFO" "Considérez la désinstallation pour éviter les conflits"
                ;;
        esac
    fi
}

detect_gpu() {
    log "HEADER" "Détection automatique du GPU"
    
    # Installation de pciutils si nécessaire
    if ! command -v lspci &>/dev/null; then
        log "INFO" "Installation de pciutils pour la détection GPU..."
        install_package "pciutils" || true
    fi
    
    local gpu_line
    gpu_line=$(lspci -nn | grep -E "(VGA|3D|Display)" | head -n1) || gpu_line=""
    
    log "DEBUG" "Ligne PCI détectée: ${gpu_line:-Aucune}"
    
    # Réinitialisation des flags
    IS_NVIDIA=false
    IS_AMD=false
    IS_INTEL=false
    
    # Détection par Vendor ID
    if echo "$gpu_line" | grep -q '\[10de:'; then
        IS_NVIDIA=true
        GPU_VENDOR="NVIDIA"
        GPU_TYPE="nvidia"
        log "SUCCESS" "GPU NVIDIA détecté (Vendor ID: 10de)"
    elif echo "$gpu_line" | grep -q '\[1002:'; then
        IS_AMD=true
        GPU_VENDOR="AMD"
        GPU_TYPE="amd" 
        log "SUCCESS" "GPU AMD détecté (Vendor ID: 1002)"
    elif echo "$gpu_line" | grep -q '\[8086:'; then
        IS_INTEL=true
        GPU_VENDOR="Intel"
        GPU_TYPE="intel"
        log "SUCCESS" "GPU Intel détecté (Vendor ID: 8086)"
    else
        log "WARNING" "GPU non reconnu, configuration générique appliquée"
        GPU_VENDOR="Générique"
        GPU_TYPE="generic"
    fi
    
    # Vérification du support OpenGL
    if command -v glxinfo &>/dev/null; then
        local opengl_version
        opengl_version=$(glxinfo | grep "OpenGL version" | cut -d' ' -f4 | head -c3)
        if [[ -n "$opengl_version" ]] && [[ $(echo "$opengl_version >= 3.3" | bc -l 2>/dev/null) -eq 1 ]]; then
            log "SUCCESS" "Support OpenGL >= 3.3 confirmé: $opengl_version"
            ((COMPATIBILITY_SCORE+=20))
        else
            log "WARNING" "OpenGL version insuffisante ou non détectée"
        fi
    fi
}

check_wayland_support() {
    log "INFO" "Vérification du support Wayland"
    
    local wayland_score=0
    
    # Vérification des bibliothèques Wayland
    if ldconfig -p | grep -q "libwayland-client"; then
        log "SUCCESS" "libwayland-client trouvée"
        ((wayland_score+=10))
    fi
    
    if ldconfig -p | grep -q "libwayland-server"; then
        log "SUCCESS" "libwayland-server trouvée"
        ((wayland_score+=10))
    fi
    
    # Vérification XDG Desktop Portal
    if command -v xdg-desktop-portal &>/dev/null; then
        log "SUCCESS" "XDG Desktop Portal disponible"
        ((wayland_score+=15))
    fi
    
    # Support GPU spécifique
    case $GPU_TYPE in
        "nvidia")
            if $IS_NVIDIA && command -v nvidia-smi &>/dev/null; then
                local nvidia_version
                nvidia_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null || echo "0")
                if [[ $(echo "$nvidia_version >= 495" | bc -l 2>/dev/null) -eq 1 ]]; then
                    log "SUCCESS" "Driver NVIDIA compatible Wayland: $nvidia_version"
                    ((wayland_score+=20))
                else
                    log "WARNING" "Driver NVIDIA trop ancien pour Wayland optimal: $nvidia_version"
                    ((wayland_score+=5))
                fi
            fi
            ;;
        "amd"|"intel")
            log "SUCCESS" "GPU $GPU_VENDOR compatible Wayland nativement"
            ((wayland_score+=25))
            ;;
    esac
    
    # Évaluation finale
    if [[ $wayland_score -ge 40 ]]; then
        WAYLAND_SUPPORT=true
        log "SUCCESS" "Support Wayland excellent (score: $wayland_score/60)"
        ((COMPATIBILITY_SCORE+=30))
    elif [[ $wayland_score -ge 20 ]]; then
        WAYLAND_SUPPORT=true
        log "WARNING" "Support Wayland partiel (score: $wayland_score/60)"
        ((COMPATIBILITY_SCORE+=15))
    else
        WAYLAND_SUPPORT=false
        log "ERROR" "Support Wayland insuffisant (score: $wayland_score/60)"
        log "ERROR" "Hyprland nécessite un support Wayland complet"
    fi
}

evaluate_compatibility() {
    log "HEADER" "Évaluation de la compatibilité Hyprland"
    
    # Tests de compatibilité basiques
    local compat_issues=()
    
    # Distribution supportée
    case $DISTRO_FAMILY in
        arch|debian|fedora|opensuse|void)
            log "SUCCESS" "Distribution supportée: $DISTRO_FAMILY"
            ((COMPATIBILITY_SCORE+=25))
            ;;
        nixos|gentoo)
            log "WARNING" "Distribution supportée expérimentalement: $DISTRO_FAMILY"
            ((COMPATIBILITY_SCORE+=15))
            compat_issues+=("Support expérimental de $DISTRO_FAMILY")
            ;;
        *)
            log "ERROR" "Distribution non supportée: $DISTRO_FAMILY"
            compat_issues+=("Distribution $DISTRO_FAMILY non supportée")
            ;;
    esac
    
    # Système d'init
    case $INIT_SYSTEM in
        systemd)
            log "SUCCESS" "systemd supporté complètement"
            ((COMPATIBILITY_SCORE+=15))
            ;;
        openrc|runit)
            log "WARNING" "Support $INIT_SYSTEM expérimental"
            ((COMPATIBILITY_SCORE+=10))
            compat_issues+=("Système d'init $INIT_SYSTEM expérimental")
            ;;
        *)
            log "ERROR" "Système d'init non supporté: $INIT_SYSTEM"
            compat_issues+=("Système d'init non supporté")
            ;;
    esac
    
    # Architecture
    local arch=$(uname -m)
    case $arch in
        x86_64)
            log "SUCCESS" "Architecture x86_64 supportée"
            ((COMPATIBILITY_SCORE+=10))
            ;;
        aarch64|arm64)
            log "WARNING" "Architecture ARM64 supportée partiellement"
            ((COMPATIBILITY_SCORE+=5))
            compat_issues+=("Architecture ARM peut avoir des limitations")
            ;;
        *)
            log "ERROR" "Architecture non supportée: $arch"
            compat_issues+=("Architecture $arch non supportée")
            ;;
    esac
    
    # Affichage final du score
    log "INFO" "Score de compatibilité final: $COMPATIBILITY_SCORE/100"
    
    if [[ $COMPATIBILITY_SCORE -ge 80 ]]; then
        log "SUCCESS" "🎉 Excellente compatibilité Hyprland!"
        return 0
    elif [[ $COMPATIBILITY_SCORE -ge 60 ]]; then
        log "WARNING" "⚠️ Compatibilité acceptable avec quelques limitations"
        if [[ ${#compat_issues[@]} -gt 0 ]]; then
            log "INFO" "Problèmes potentiels:"
            for issue in "${compat_issues[@]}"; do
                log "WARNING" "  • $issue"
            done
        fi
        
        if ! confirm_action "Continuer malgré les avertissements?" "n"; then
            log "INFO" "Installation annulée par l'utilisateur"
            exit 0
        fi
        return 0
    else
        log "ERROR" "❌ Compatibilité insuffisante pour Hyprland"
        if [[ ${#compat_issues[@]} -gt 0 ]]; then
            log "ERROR" "Problèmes critiques:"
            for issue in "${compat_issues[@]}"; do
                log "ERROR" "  • $issue"
            done
        fi
        
        if ! confirm_action "Forcer l'installation malgré les erreurs?" "n"; then
            log "INFO" "Installation annulée - système non compatible"
            exit 1
        fi
        log "WARNING" "Installation forcée - des problèmes peuvent survenir"
        return 0
    fi
}

# Installation générique de package
install_package() {
    local package=$1
    local is_critical=${2:-false}
    
    if $DRY_RUN; then
        log "INFO" "[DRY-RUN] Installation de: $package"
        return 0
    fi
    
    log "DEBUG" "Installation du package: $package"
    
    case $PACKAGE_MANAGER in
        pacman)
            if sudo pacman -S --noconfirm --needed "$package" 2>/dev/null; then
                log "SUCCESS" "Package installé: $package"
                return 0
            fi
            ;;
        apt)
            if sudo apt-get update -qq && sudo apt-get install -y "$package" 2>/dev/null; then
                log "SUCCESS" "Package installé: $package"
                return 0
            fi
            ;;
        dnf)
            if sudo dnf install -y "$package" 2>/dev/null; then
                log "SUCCESS" "Package installé: $package"
                return 0
            fi
            ;;
        zypper)
            if sudo zypper install -y "$package" 2>/dev/null; then
                log "SUCCESS" "Package installé: $package"
                return 0
            fi
            ;;
        xbps)
            if sudo xbps-install -y "$package" 2>/dev/null; then
                log "SUCCESS" "Package installé: $package"
                return 0
            fi
            ;;
        *)
            log "ERROR" "Gestionnaire de packages non supporté: $PACKAGE_MANAGER"
            return 1
            ;;
    esac
    
    log "WARNING" "Échec d'installation: $package"
    if $is_critical; then
        log "ERROR" "Package critique non installé, arrêt"
        exit 1
    fi
    return 1
}

# Compilation depuis les sources
compile_hyprland_from_source() {
    log "HEADER" "Compilation de Hyprland depuis les sources"
    
    local build_dir="/tmp/hyprland-build"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Clonage du dépôt
    git clone --recursive https://github.com/hyprwm/Hyprland.git
    cd Hyprland
    
    # Compilation
    make all
    
    # Installation
    sudo make install
    
    log "SUCCESS" "Hyprland compilé et installé depuis les sources"
    cd - >/dev/null
    rm -rf "$build_dir"
}

# Installation de Hyprland selon la distribution
install_hyprland_distro() {
    log "HEADER" "Installation de Hyprland pour $DISTRO_FAMILY"
    
    case $DISTRO_FAMILY in
        arch)
            install_hyprland_arch
            ;;
        debian)
            install_hyprland_debian
            ;;
        fedora)
            install_hyprland_fedora
            ;;
        opensuse)
            install_hyprland_opensuse
            ;;
        void)
            install_hyprland_void
            ;;
        nixos)
            install_hyprland_nixos
            ;;
        gentoo)
            install_hyprland_gentoo
            ;;
        *)
            log "ERROR" "Installation Hyprland non supportée pour: $DISTRO_FAMILY"
            exit 1
            ;;
    esac
}

install_hyprland_arch() {
    log "INFO" "Installation Hyprland sur Arch Linux"
    
    # Activation multilib si nécessaire
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        log "INFO" "Activation du dépôt multilib"
        sudo sed -i 's/^#\[multilib\]/[multilib]/' /etc/pacman.conf
        sudo sed -i '/^\[multilib\]/{n;s/^#//}' /etc/pacman.conf
        sudo pacman -Sy
    fi
    
    # Installation yay si absent
    if ! command -v yay &>/dev/null; then
        log "INFO" "Installation de yay (AUR helper)"
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        cd /tmp/yay
        makepkg -si --noconfirm
        cd -
        rm -rf /tmp/yay
    fi
    
    # Packages Hyprland
    local hyprland_packages=(
        hyprland hyprpaper hypridle hyprlock
        xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
        waybar wofi kitty thunar dunst
        sddm qt5-quickcontrols2 qt5-svg qt5-graphicaleffects
        pipewire pipewire-pulse pipewire-alsa wireplumber
        polkit-gnome brightnessctl playerctl
        grim slurp wf-recorder
        ttf-jetbrains-mono-nerd papirus-icon-theme
    )
    
    for pkg in "${hyprland_packages[@]}"; do
        install_package "$pkg" true
    done
    
    # Packages AUR
    local aur_packages=(
        mpvpaper
        bibata-cursor-theme
    )
    
    for pkg in "${aur_packages[@]}"; do
        if ! yay -S --noconfirm "$pkg" 2>/dev/null; then
            log "WARNING" "Package AUR non installé: $pkg"
        fi
    done
}

install_hyprland_debian() {
    log "INFO" "Installation Hyprland sur Debian/Ubuntu"
    
    # Mise à jour des dépôts
    sudo apt-get update
    
    # Dépendances de compilation
    local build_deps=(
        build-essential cmake meson ninja-build
        libwayland-dev wayland-protocols libdrm-dev
        libegl1-mesa-dev libgles2-mesa-dev libgbm-dev
        libinput-dev libxkbcommon-dev libpixman-1-dev
        libcairo2-dev libpango1.0-dev
    )
    
    for dep in "${build_deps[@]}"; do
        install_package "$dep" true
    done
    
    # Vérification version Debian/Ubuntu pour backports
    if grep -q "bullseye\|bookworm\|jammy\|focal" /etc/os-release; then
        log "INFO" "Version stable détectée, utilisation des backports si disponibles"
        
        if [[ "$DISTRO_FAMILY" == "debian" ]]; then
            echo "deb http://deb.debian.org/debian $(lsb_release -cs)-backports main" | sudo tee /etc/apt/sources.list.d/backports.list
        elif [[ "$DISTRO_FAMILY" == "ubuntu" ]]; then
            sudo add-apt-repository ppa:hyprland/hyprland -y || log "WARNING" "PPA Hyprland non disponible"
        fi
        
        sudo apt-get update
    fi
    
    # Installation via package ou compilation
    if ! install_package "hyprland"; then
        log "WARNING" "Hyprland non disponible en package, compilation depuis les sources"
        compile_hyprland_from_source
    fi
    
    # Autres composants
    local other_packages=(
        waybar wofi kitty thunar dunst
        sddm pipewire pipewire-pulse wireplumber
        xdg-desktop-portal-wlr brightnessctl playerctl
        grim slurp fonts-jetbrains-mono papirus-icon-theme
    )
    
    for pkg in "${other_packages[@]}"; do
        install_package "$pkg"
    done
}

install_hyprland_fedora() {
    log "INFO" "Installation Hyprland sur Fedora"
    
    # Activation de RPM Fusion
    sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    
    # COPR pour Hyprland
    sudo dnf copr enable solopasha/hyprland -y
    
    # Installation des packages
    local hyprland_packages=(
        hyprland hyprpaper hyprlock hypridle
        waybar wofi kitty thunar dunst
        sddm pipewire pipewire-pulseaudio wireplumber
        xdg-desktop-portal-hyprland brightnessctl playerctl
        grim slurp jetbrains-mono-fonts-all papirus-icon-theme
    )
    
    for pkg in "${hyprland_packages[@]}"; do
        install_package "$pkg"
    done
}

install_hyprland_opensuse() {
    log "INFO" "Installation Hyprland sur openSUSE"
    
    # Ajout des dépôts Packman
    sudo zypper ar -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman
    
    # Pattern Wayland
    sudo zypper install -y patterns-base-wayland
    
    # Installation Hyprland
    local hyprland_packages=(
        hyprland waybar wofi kitty thunar dunst
        sddm pipewire pipewire-pulseaudio wireplumber
        brightnessctl playerctl grim slurp
        jetbrains-mono-fonts papirus-icon-theme
    )
    
    for pkg in "${hyprland_packages[@]}"; do
        install_package "$pkg"
    done
}

install_hyprland_void() {
    log "INFO" "Installation Hyprland sur Void Linux"
    
    # Mise à jour des dépôts
    sudo xbps-install -Su
    
    # Installation des packages
    local hyprland_packages=(
        hyprland waybar wofi kitty thunar dunst
        sddm pipewire wireplumber brightnessctl playerctl
        grim slurp font-jetbrains-mono papirus-icon-theme
    )
    
    for pkg in "${hyprland_packages[@]}"; do
        install_package "$pkg"
    done
}

install_hyprland_nixos() {
    log "WARNING" "NixOS détecté - configuration via configuration.nix recommandée"
    log "INFO" "Script d'aide pour configuration.nix généré"
    
    cat > "$HOME/hyprland-nixos-config.nix" << 'EOF'
# Configuration Hyprland pour NixOS
# À intégrer dans votre configuration.nix

{ config, pkgs, ... }:

{
    programs.hyprland = {
        enable = true;
        xwayland.enable = true;
    };

    environment.systemPackages = with pkgs; [
        waybar wofi kitty thunar dunst
        hyprpaper hyprlock hypridle
        pipewire wireplumber
        xdg-desktop-portal-hyprland
        brightnessctl playerctl grim slurp
        jetbrains-mono papirus-icon-theme
    ];

    services.greetd = {
        enable = true;
        settings = {
        default_session = {
            command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
            user = "greeter";
        };
        };
    };

    security.rtkit.enable = true;
    services.pipewire = {
        enable = true;
        pulse.enable = true;
    };
}
EOF
    
    log "SUCCESS" "Configuration NixOS générée: $HOME/hyprland-nixos-config.nix"
    exit 0
}

install_hyprland_gentoo() {
    log "WARNING" "Gentoo détecté - installation expérimentale"
    log "INFO" "Configuration des USE flags recommandée"
    
    # Configuration USE flags
    sudo tee -a /etc/portage/package.use/hyprland > /dev/null << 'EOF'
# Hyprland USE flags
gui-wm/hyprland X
media-libs/mesa wayland
dev-libs/wayland-protocols wayland
EOF

    # Installation via emerge
    sudo emerge --ask gui-wm/hyprland
    
    log "SUCCESS" "Installation Gentoo initiée - compilation en cours"
}

install_gpu_drivers_universal() {
    log "HEADER" "Installation des drivers GPU ($GPU_VENDOR) pour $DISTRO_FAMILY"
    
    case $GPU_TYPE in
        "nvidia")
            install_nvidia_drivers_universal
            ;;
        "amd")
            install_amd_drivers_universal
            ;;
        "intel")
            install_intel_drivers_universal
            ;;
        *)
            log "WARNING" "GPU générique détecté, drivers de base installés"
            ;;
    esac
}

install_nvidia_drivers_universal() {
    log "INFO" "Installation des drivers NVIDIA pour $DISTRO_FAMILY"
    
    case $DISTRO_FAMILY in
        "arch")
            local nvidia_packages=(
                nvidia-dkms nvidia-utils lib32-nvidia-utils
                nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader
            )
            for pkg in "${nvidia_packages[@]}"; do
                install_package "$pkg" true
            done
            configure_nvidia_arch
            ;;
        "debian")
            # Détection automatique du driver approprié
            if lspci | grep -i nvidia | grep -qi "rtx\|gtx 16\|gtx 20\|gtx 30\|gtx 40"; then
                install_package "nvidia-driver" true
            else
                install_package "nvidia-legacy-390xx-driver" 
            fi
            install_package "nvidia-settings"
            configure_nvidia_debian
            ;;
        "fedora")
            # Activation RPM Fusion si pas fait
            sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
            install_package "akmod-nvidia" true
            install_package "xorg-x11-drv-nvidia-cuda"
            configure_nvidia_fedora
            ;;
        "opensuse")
            sudo zypper ar -cfp 90 https://download.nvidia.com/opensuse/tumbleweed nvidia
            install_package "nvidia-glG05" true
            install_package "nvidia-computeG05"
            configure_nvidia_opensuse
            ;;
        *)
            log "WARNING" "Distribution non supportée pour l'installation automatique NVIDIA"
            ;;
    esac
}

install_amd_drivers_universal() {
    log "INFO" "Installation des drivers AMD pour $DISTRO_FAMILY"
    
    case $DISTRO_FAMILY in
        "arch")
            local amd_packages=(
                mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
                libva-mesa-driver lib32-libva-mesa-driver
                mesa-vdpau lib32-mesa-vdpau xf86-video-amdgpu
            )
            for pkg in "${amd_packages[@]}"; do
                install_package "$pkg" true
            done
            ;;
        "debian")
            local amd_packages=(
                mesa-vulkan-drivers libgl1-mesa-dri
                libva-drm2 libva2 vainfo
                firmware-amd-graphics
            )
            for pkg in "${amd_packages[@]}"; do
                install_package "$pkg"
            done
            ;;
        "fedora")
            install_package "mesa-dri-drivers" true
            install_package "mesa-vulkan-drivers"
            install_package "libva-utils"
            ;;
        "opensuse")
            install_package "Mesa-dri" true
            install_package "Mesa-vulkan-radeon"
            install_package "libva-utils"
            ;;
        *)
            log "WARNING" "Drivers AMD génériques installés"
            install_package "mesa-dri-drivers" || true
            ;;
    esac
    
    # Configuration AMD commune
    configure_amd_common
}

install_intel_drivers_universal() {
    log "INFO" "Installation des drivers Intel pour $DISTRO_FAMILY"
    
    case $DISTRO_FAMILY in
        "arch")
            local intel_packages=(
                mesa lib32-mesa vulkan-intel lib32-vulkan-intel
                intel-media-driver libva-intel-driver
                xf86-video-intel
            )
            for pkg in "${intel_packages[@]}"; do
                install_package "$pkg" true
            done
            ;;
        "debian")
            local intel_packages=(
                mesa-vulkan-drivers intel-media-va-driver
                vainfo i965-va-driver
            )
            for pkg in "${intel_packages[@]}"; do
                install_package "$pkg"
            done
            ;;
        "fedora"|"opensuse")
            install_package "mesa-dri-drivers" true
            install_package "intel-media-driver"
            install_package "libva-intel-driver"
            ;;
        *)
            install_package "mesa-dri-drivers" || true
            ;;
    esac
    
    # Configuration Intel commune
    configure_intel_common
}

# Configurations GPU spécifiques
configure_nvidia_arch() {
    log "INFO" "Configuration NVIDIA pour Arch Linux"
    
    # Modules kernel
    if ! grep -q "nvidia" /etc/mkinitcpio.conf; then
        sudo sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        sudo mkinitcpio -P
    fi
    
    # Hook NVIDIA
    sudo mkdir -p /etc/pacman.d/hooks
    sudo tee /etc/pacman.d/hooks/nvidia.hook > /dev/null << 'EOF'
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-dkms
Target=linux

[Action]
Description=Update NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF

    configure_nvidia_env
}

configure_nvidia_debian() {
    log "INFO" "Configuration NVIDIA pour Debian/Ubuntu"
    
    # Blacklist Nouveau
    echo "blacklist nouveau" | sudo tee -a /etc/modprobe.d/blacklist-nvidia-nouveau.conf
    echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nvidia-nouveau.conf
    sudo update-initramfs -u
    
    configure_nvidia_env
}

configure_nvidia_fedora() {
    log "INFO" "Configuration NVIDIA pour Fedora"
    
    # Attendre la compilation du module
    log "WARNING" "Les modules NVIDIA sont en cours de compilation, cela peut prendre plusieurs minutes..."
    sudo akmods --force --kernel $(uname -r) --akmod nvidia
    sudo dracut --force
    
    configure_nvidia_env
}

configure_nvidia_opensuse() {
    log "INFO" "Configuration NVIDIA pour openSUSE"
    configure_nvidia_env
}

configure_nvidia_env() {
    log "INFO" "Configuration des variables d'environnement NVIDIA"
    
    # Variables d'environnement globales
    sudo tee /etc/environment > /dev/null << 'EOF'
# Variables NVIDIA Wayland
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1
LIBVA_DRIVER_NAME=nvidia
XDG_SESSION_TYPE=wayland
GDK_BACKEND=wayland
QT_QPA_PLATFORM=wayland
EOF

    # Configuration spécifique Hyprland
    mkdir -p ~/.config/hypr
    if [[ ! -f ~/.config/hypr/nvidia.conf ]]; then
        cat > ~/.config/hypr/nvidia.conf << 'EOF'
# Configuration NVIDIA pour Hyprland
render {
    explicit_sync = 2
    explicit_sync_kms = 2
    direct_scanout = true
}
EOF
    fi
    
    log "SUCCESS" "Configuration NVIDIA terminée"
}

configure_amd_common() {
    log "INFO" "Configuration AMD commune"
    
    # Variables d'environnement AMD
    sudo tee -a /etc/environment > /dev/null << 'EOF'
# Variables AMD
RADV_PERFTEST=aco
AMD_VULKAN_ICD=RADV
WLR_DRM_NO_ATOMIC=1
EOF

    log "SUCCESS" "Configuration AMD terminée"
}

configure_intel_common() {
    log "INFO" "Configuration Intel commune"
    
    # Variables d'environnement Intel
    sudo tee -a /etc/environment > /dev/null << 'EOF'
# Variables Intel Graphics
WLR_NO_HARDWARE_CURSORS=1
WLR_DRM_NO_ATOMIC=1
INTEL_DEBUG=norbc
EOF

    log "SUCCESS" "Configuration Intel terminée"
}

configure_display_manager() {
    log "HEADER" "Configuration du gestionnaire d'affichage"
    
    case $DISTRO_FAMILY in
        "arch"|"void")
            configure_sddm_universal
            ;;
        "debian")
            # GDM par défaut sur Debian/Ubuntu, mais on peut proposer SDDM
            if confirm_action "Installer SDDM au lieu de GDM?"; then
                configure_sddm_universal
            else
                configure_gdm_wayland
            fi
            ;;
        "fedora")
            # GDM par défaut sur Fedora
            configure_gdm_wayland
            ;;
        "opensuse")
            # SDDM par défaut
            configure_sddm_universal
            ;;
        *)
            log "WARNING" "Configuration automatique du gestionnaire d'affichage non supportée"
            ;;
    esac
}

configure_sddm_universal() {
    log "INFO" "Configuration de SDDM pour Wayland"
    
    # Installation SDDM si nécessaire
    install_package "sddm"
    
    # Arrêt des autres gestionnaires d'affichage
    for dm in gdm lightdm lxdm xdm; do
        sudo systemctl disable "$dm" 2>/dev/null || true
        sudo systemctl stop "$dm" 2>/dev/null || true
    done
    
    # Configuration SDDM
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/wayland.conf > /dev/null << 'EOF'
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=Hyprland

[Theme]
Current=breeze

[Users]
MaximumUid=60513
MinimumUid=1000
EOF

    # Activation SDDM
    sudo systemctl enable sddm
    sudo systemctl set-default graphical.target
    
    log "SUCCESS" "SDDM configuré pour Wayland/Hyprland"
}

configure_gdm_wayland() {
    log "INFO" "Configuration de GDM pour Wayland"
    
    # S'assurer que Wayland est activé dans GDM
    if [[ -f /etc/gdm3/daemon.conf ]]; then
        sudo sed -i 's/#WaylandEnable=false/WaylandEnable=true/' /etc/gdm3/daemon.conf
    elif [[ -f /etc/gdm/daemon.conf ]]; then
        sudo sed -i 's/#WaylandEnable=false/WaylandEnable=true/' /etc/gdm/daemon.conf
    fi
    
    # Créer le fichier de session Hyprland
    sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
    
    log "SUCCESS" "GDM configuré pour Wayland"
}

# Configuration de Waybar
create_waybar_config() {
    log "HEADER" "Configuration de Waybar (élément central)"
    
    mkdir -p ~/.config/waybar
    
    # Détection automatique de la position
    if confirm_action "Préférez-vous la barre en haut (style macOS) ou en bas (style Windows)?" "y"; then
        WAYBAR_POSITION="top"
    else
        WAYBAR_POSITION="bottom"
    fi
    
    # Configuration principale
    cat > ~/.config/waybar/config << EOF
{
    "position": "$WAYBAR_POSITION",
    "layer": "top",
    "height": 34,
    "margin-top": 6,
    "margin-bottom": 0,
    "margin-left": 10,
    "margin-right": 10,
    "spacing": 5,
    "modules-left": ["custom/launcher", "hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "bluetooth", "battery", "cpu", "memory", "tray", "custom/power"],

    "custom/launcher": {
        "format": " ",
        "tooltip": false,
        "on-click": "wofi --show drun",
        "on-click-right": "killall wofi"
    },

    "hyprland/workspaces": {
        "format": "{icon}",
        "format-icons": {
            "1": "󰈹",
            "2": "󰅩",
            "3": "",
            "4": "󰙯",
            "5": "󰎆",
            "6": "󰋩",
            "7": "󰒱",
            "8": "󰐌",
            "9": "󰌠",
            "10": "󰽰"
        },
        "persistent_workspaces": {
            "1": [],
            "2": [],
            "3": [],
            "4": [],
            "5": []
        },
        "on-click": "activate",
        "sort-by-number": true
    },

    "hyprland/window": {
        "format": "{}",
        "max-length": 60,
        "separate-outputs": true
    },

    "clock": {
        "interval": 1,
        "format": "{:%H:%M:%S}",
        "format-alt": "{:%Y-%m-%d %H:%M:%S %Z}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "on-click": "~/.local/bin/calendar-popup"
    },

    "cpu": {
        "interval": 10,
        "format": " {}%",
        "max-length": 10,
        "on-click": "kitty -e htop"
    },

    "memory": {
        "interval": 30,
        "format": " {}%",
        "max-length": 10,
        "tooltip": true,
        "tooltip-format": "Memory used: {used:0.1f}G/{total:0.1f}G",
        "on-click": "kitty -e htop"
    },

    "network": {
        "interface": "wl*",
        "format-wifi": " {signalStrength}%",
        "format-ethernet": "󰈀 {ipaddr}",
        "format-linked": "󰈀 {ifname}",
        "format-disconnected": "󰤮 Disconnected",
        "tooltip-format": "{ifname}: {ipaddr}/{cidr}",
        "on-click": "~/.local/bin/network-menu"
    },

    "bluetooth": {
        "format": " {status}",
        "format-disabled": "󰂲",
        "format-off": "󰂲",
        "format-on": "",
        "format-connected": " {device_alias}",
        "tooltip-format": "{controller_alias}\t{controller_address}",
        "tooltip-format-connected": "{controller_alias}\t{controller_address}\n\n{device_enumerate}",
        "tooltip-format-enumerate-connected": "{device_alias}\t{device_address}",
        "on-click": "~/.local/bin/bluetooth-menu"
    },

    "pulseaudio": {
        "scroll-step": 5,
        "format": "{icon} {volume}%",
        "format-bluetooth": " {volume}%",
        "format-bluetooth-muted": " ",
        "format-muted": " ",
        "format-icons": {
            "headphone": "",
            "hands-free": "",
            "headset": "",
            "phone": "",
            "portable": "",
            "car": "",
            "default": ["", "", ""]
        },
        "on-click": "~/.local/bin/audio-menu",
        "on-scroll-up": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
        "on-scroll-down": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
    },

    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged": " {capacity}%",
        "format-alt": "{time} {icon}",
        "format-icons": ["", "", "", "", ""],
        "on-click": "~/.local/bin/power-menu"
    },

    "tray": {
        "icon-size": 18,
        "spacing": 10
    },

    "custom/power": {
        "format": "⏻",
        "tooltip": false,
        "on-click": "~/.local/bin/power-menu"
    }
}
EOF

    # Style CSS avancé
    create_waybar_styles
    
    log "SUCCESS" "Configuration Waybar créée (position: $WAYBAR_POSITION)"
}

create_waybar_styles() {
    log "INFO" "Création des styles CSS Waybar - Thème Arcane/Fallout"
    
    cat > ~/.config/waybar/style.css << 'EOF'

* {
    font-family: 'JetBrains Mono Nerd Font', 'Fira Code', monospace;
    font-size: 13px;
    font-weight: 500;
    transition: all 0.3s cubic-bezier(0.4, 0.0, 0.2, 1);
}

window#waybar {
    background: linear-gradient(135deg, 
        rgba(15, 15, 35, 0.95) 0%, 
        rgba(25, 25, 55, 0.92) 50%, 
        rgba(15, 15, 35, 0.95) 100%);
    border: 2px solid rgba(51, 204, 255, 0.6);
    border-radius: 16px;
    box-shadow: 
        0 8px 32px rgba(0, 0, 0, 0.4),
        0 0 0 1px rgba(51, 204, 255, 0.2) inset;
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    margin: 5px;
    padding: 0 10px;
}

/* Position adaptative */
window#waybar.top {
    border-top: 3px solid #33ccff;
    border-bottom: 1px solid rgba(51, 204, 255, 0.3);
}

window#waybar.bottom {
    border-bottom: 3px solid #33ccff;
    border-top: 1px solid rgba(51, 204, 255, 0.3);
}

#workspaces {
    background: linear-gradient(135deg, 
        rgba(0, 0, 0, 0.4) 0%, 
        rgba(51, 204, 255, 0.1) 100%);
    border-radius: 12px;
    margin: 2px 5px;
    padding: 2px 5px;
    box-shadow: 0 0 15px rgba(51, 204, 255, 0.2) inset;
}

#workspaces button {
    color: #ffffff;
    background: transparent;
    border: none;
    border-radius: 10px;
    margin: 0 2px;
    padding: 5px 10px;
    min-width: 35px;
    transition: all 0.3s ease;
}

#workspaces button:hover {
    background: linear-gradient(135deg, 
        rgba(51, 204, 255, 0.3) 0%, 
        rgba(0, 255, 153, 0.2) 100%);
    color: #33ccff;
    transform: scale(1.05);
    box-shadow: 0 0 20px rgba(51, 204, 255, 0.4);
}

#workspaces button.active {
    background: linear-gradient(135deg, 
        rgba(51, 204, 255, 0.8) 0%, 
        rgba(0, 255, 153, 0.6) 100%);
    color: #000000;
    font-weight: bold;
    box-shadow: 
        0 0 25px rgba(51, 204, 255, 0.6),
        0 0 0 2px rgba(255, 255, 255, 0.3) inset;
    transform: scale(1.1);
}

#workspaces button.urgent {
    background: linear-gradient(135deg, #ff5555, #ff7979);
    color: #ffffff;
    animation: pulse 2s infinite;
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.7; }
}

#window {
    color: #ffffff;
    background: linear-gradient(135deg, 
        rgba(0, 0, 0, 0.3) 0%, 
        rgba(51, 204, 255, 0.1) 100%);
    border-radius: 10px;
    margin: 2px 5px;
    padding: 5px 15px;
    font-weight: 500;
    max-width: 400px;
    overflow: hidden;
    text-overflow: ellipsis;
}

#clock {
    color: #33ccff;
    background: linear-gradient(135deg, 
        rgba(0, 0, 0, 0.6) 0%, 
        rgba(51, 204, 255, 0.15) 100%);
    border: 1px solid rgba(51, 204, 255, 0.4);
    border-radius: 12px;
    margin: 2px 10px;
    padding: 6px 20px;
    font-weight: bold;
    font-size: 14px;
    text-shadow: 0 0 10px rgba(51, 204, 255, 0.5);
    box-shadow: 
        0 0 20px rgba(51, 204, 255, 0.3) inset,
        0 4px 15px rgba(0, 0, 0, 0.3);
}

#clock:hover {
    background: linear-gradient(135deg, 
        rgba(0, 0, 0, 0.7) 0%, 
        rgba(51, 204, 255, 0.2) 100%);
    box-shadow: 
        0 0 30px rgba(51, 204, 255, 0.5) inset,
        0 6px 20px rgba(0, 0, 0, 0.4);
    transform: scale(1.02);
}

#cpu, #memory, #network, #pulseaudio, #bluetooth, #battery {
    color: #ffffff;
    background: linear-gradient(135deg, 
        rgba(0, 0, 0, 0.4) 0%, 
        rgba(68, 71, 90, 0.3) 100%);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 10px;
    margin: 2px 3px;
    padding: 5px 12px;
    min-width: 60px;
}

#cpu:hover, #memory:hover {
    background: linear-gradient(135deg, 
        rgba(255, 184, 108, 0.3) 0%, 
        rgba(255, 158, 51, 0.2) 100%);
    border-color: rgba(255, 184, 108, 0.5);
    color: #ffb86c;
}

#network {
    color: #50fa7b;
}

#network:hover {
    background: linear-gradient(135deg, 
        rgba(80, 250, 123, 0.3) 0%, 
        rgba(80, 250, 123, 0.1) 100%);
    border-color: rgba(80, 250, 123, 0.5);
}

#network.disconnected {
    color: #ff5555;
    background: linear-gradient(135deg, 
        rgba(255, 85, 85, 0.3) 0%, 
        rgba(255, 85, 85, 0.1) 100%);
}

#pulseaudio {
    color: #bd93f9;
}

#pulseaudio:hover {
    background: linear-gradient(135deg, 
        rgba(189, 147, 249, 0.3) 0%, 
        rgba(189, 147, 249, 0.1) 100%);
    border-color: rgba(189, 147, 249, 0.5);
}

#pulseaudio.muted {
    color: #6272a4;
    background: linear-gradient(135deg, 
        rgba(98, 114, 164, 0.3) 0%, 
        rgba(98, 114, 164, 0.1) 100%);
}

#bluetooth {
    color: #8be9fd;
}

#bluetooth:hover {
    background: linear-gradient(135deg, 
        rgba(139, 233, 253, 0.3) 0%, 
        rgba(139, 233, 253, 0.1) 100%);
    border-color: rgba(139, 233, 253, 0.5);
}

#bluetooth.disabled {
    color: #6272a4;
    opacity: 0.6;
}

#battery {
    color: #f1fa8c;
}

#battery:hover {
    background: linear-gradient(135deg, 
        rgba(241, 250, 140, 0.3) 0%, 
        rgba(241, 250, 140, 0.1) 100%);
    border-color: rgba(241, 250, 140, 0.5);
}

#battery.warning {
    color: #ffb86c;
    animation: warning-pulse 3s ease-in-out infinite;
}

#battery.critical {
    color: #ff5555;
    animation: critical-pulse 1s ease-in-out infinite;
}

@keyframes warning-pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.7; }
}

@keyframes critical-pulse {
    0%, 100% { 
        opacity: 1; 
        box-shadow: 0 0 20px rgba(255, 85, 85, 0.7);
    }
    50% { 
        opacity: 0.8;
        box-shadow: 0 0 30px rgba(255, 85, 85, 1.0);
    }
}

#battery.charging {
    color: #50fa7b;
    background: linear-gradient(135deg, 
        rgba(80, 250, 123, 0.3) 0%, 
        rgba(80, 250, 123, 0.1) 100%);
}

#tray {
    background: linear-gradient(135deg, 
        rgba(0, 0, 0, 0.4) 0%, 
        rgba(68, 71, 90, 0.3) 100%);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 10px;
    margin: 2px 5px;
    padding: 2px 8px;
}

#tray > .passive {
    -gtk-icon-effect: dim;
}

#tray > .needs-attention {
    -gtk-icon-effect: highlight;
    background-color: rgba(255, 85, 85, 0.3);
    border-radius: 8px;
}

#custom-launcher {
    color: #33ccff;
    background: linear-gradient(135deg, 
        rgba(51, 204, 255, 0.3) 0%, 
        rgba(0, 255, 153, 0.2) 100%);
    border: 1px solid rgba(51, 204, 255, 0.5);
    border-radius: 12px;
    margin: 2px 5px;
    padding: 5px 12px;
    font-size: 16px;
    text-shadow: 0 0 10px rgba(51, 204, 255, 0.5);
}

#custom-launcher:hover {
    background: linear-gradient(135deg, 
        rgba(51, 204, 255, 0.5) 0%, 
        rgba(0, 255, 153, 0.3) 100%);
    color: #000000;
    transform: scale(1.05);
    box-shadow: 0 0 25px rgba(51, 204, 255, 0.6);
}

#custom-power {
    color: #ff5555;
    background: linear-gradient(135deg, 
        rgba(255, 85, 85, 0.3) 0%, 
        rgba(255, 85, 85, 0.1) 100%);
    border: 1px solid rgba(255, 85, 85, 0.4);
    border-radius: 12px;
    margin: 2px 5px;
    padding: 5px 12px;
    font-size: 14px;
}

#custom-power:hover {
    background: linear-gradient(135deg, 
        rgba(255, 85, 85, 0.5) 0%, 
        rgba(255, 85, 85, 0.3) 100%);
    color: #ffffff;
    transform: scale(1.05);
    box-shadow: 0 0 20px rgba(255, 85, 85, 0.6);
}

/* Animation globale au survol */
#cpu:hover, #memory:hover, #network:hover, #pulseaudio:hover, 
#bluetooth:hover, #battery:hover, #tray:hover {
    transform: translateY(-2px) scale(1.02);
    box-shadow: 0 4px 20px rgba(51, 204, 255, 0.3);
}

/* Effet de brillance */
@keyframes shine {
    0% { background-position: -200px; }
    100% { background-position: 200px; }
}

#workspaces button.active::before {
    content: "";
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(
        90deg, 
        transparent, 
        rgba(255, 255, 255, 0.3), 
        transparent
    );
    animation: shine 2s infinite;
}

/* Responsive pour petits écrans */
@media (max-width: 1366px) {
    * {
        font-size: 12px;
    }
    
    #workspaces button {
        min-width: 30px;
        padding: 4px 8px;
    }
    
    #clock {
        padding: 5px 15px;
        font-size: 13px;
    }
    
    #cpu, #memory, #network, #pulseaudio, #bluetooth, #battery {
        min-width: 50px;
        padding: 4px 10px;
    }
}

/* Mode sombre adaptatif */
@media (prefers-color-scheme: dark) {
    window#waybar {
        background: linear-gradient(135deg, 
            rgba(5, 5, 15, 0.98) 0%, 
            rgba(15, 15, 25, 0.95) 50%, 
            rgba(5, 5, 15, 0.98) 100%);
    }
}

/* Support multi-moniteur */
window#waybar.DP-1, window#waybar.DP-2, window#waybar.HDMI-1 {
    opacity: 0.95;
}

window#waybar.eDP-1 {
    opacity: 1.0;
}
EOF

    log "SUCCESS" "Styles CSS Waybar créés avec thème Arcane/Fallout"
}

create_hyprland_config() {
    log "HEADER" "Configuration complète de Hyprland"
    
    mkdir -p ~/.config/hypr
    
    # Configuration principale
    cat > ~/.config/hypr/hyprland.conf << 'EOF'

# Variables d'environnement adaptatives
EOF

    # Ajout des variables spécifiques au GPU
    get_gpu_env_vars >> ~/.config/hypr/hyprland.conf
    
    cat >> ~/.config/hypr/hyprland.conf << 'EOF'

# Variables communes Wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = QT_AUTO_SCREEN_SCALE_FACTOR,1
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1

# Détection automatique des moniteurs
monitor=,preferred,auto,auto

# Workspaces par défaut
workspace = 1, monitor:DP-1, default:true
workspace = 2, monitor:DP-1
workspace = 3, monitor:DP-1
workspace = 4, monitor:DP-1
workspace = 5, monitor:DP-1

$terminal = kitty
$fileManager = thunar
$menu = wofi --show drun
$browser = firefox

input {
    kb_layout = fr
    kb_variant =
    kb_model =
    kb_options =
    kb_rules =

    follow_mouse = 1
    sensitivity = 0
    accel_profile = flat
    
    touchpad {
        natural_scroll = true
        disable_while_typing = true
        tap-to-click = true
        drag_lock = false
        clickfinger_behavior = true
        middle_button_emulation = true
        scroll_factor = 1.0
    }
}

device {
    name = epic-mouse-v1
    sensitivity = -0.5
}

general {
    gaps_in = 8
    gaps_out = 12
    border_size = 3
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(44475aaa)
    resize_on_border = true
    allow_tearing = true
    layout = dwindle
}

EOF

    # Ajout de la configuration GPU spécifique
    get_gpu_decoration_config >> ~/.config/hypr/hyprland.conf
    
    # Configuration commune (suite)
    cat >> ~/.config/hypr/hyprland.conf << 'EOF'

EOF
    
    get_gpu_animation_config >> ~/.config/hypr/hyprland.conf
    
    cat >> ~/.config/hypr/hyprland.conf << 'EOF'

dwindle {
    pseudotile = true
    preserve_split = true
    smart_split = true
    smart_resizing = true
    force_split = 0
    special_scale_factor = 0.8
}

master {
    new_is_master = true
    allow_small_split = false
    special_scale_factor = 0.8
    mfact = 0.55
}

gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 300
    workspace_swipe_invert = true
    workspace_swipe_min_speed_to_force = 30
    workspace_swipe_cancel_ratio = 0.5
    workspace_swipe_create_new = true
    workspace_swipe_use_r = false
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
    disable_splash_rendering = true
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
    vrr = 1
    animate_manual_resizes = true
    animate_mouse_windowdragging = true
    enable_swallow = true
    swallow_regex = ^(kitty)$
}

# Transparence adaptée au GPU
EOF

    get_gpu_window_rules >> ~/.config/hypr/hyprland.conf
    
    cat >> ~/.config/hypr/hyprland.conf << 'EOF'

# Règles spécifiques d'applications
windowrulev2 = float,class:^(pavucontrol)$
windowrulev2 = float,class:^(blueman-manager)$
windowrulev2 = float,class:^(nm-connection-editor)$
windowrulev2 = float,class:^(thunar)$,title:^(File Operation Progress)$

# Règles pour les jeux et applications fullscreen
windowrulev2 = fullscreen,class:^(steam_app_.*)$
windowrulev2 = immediate,class:^(steam_app_.*)$
windowrulev2 = fullscreen,class:^(gamescope)$

# Applications de développement
windowrulev2 = workspace 2,class:^(code|Code)$
windowrulev2 = workspace 3,class:^(firefox|google-chrome|brave-browser)$
windowrulev2 = workspace 4,class:^(discord|Discord|telegram-desktop)$
windowrulev2 = workspace 5,class:^(spotify|Spotify)$

# Règles de taille
windowrulev2 = size 800 600,class:^(pavucontrol)$
windowrulev2 = size 600 400,class:^(wofi)$
windowrulev2 = center,class:^(wofi)$

$mainMod = SUPER

# Applications principales
bind = $mainMod, Q, exec, $terminal
bind = $mainMod, E, exec, $fileManager  
bind = $mainMod, R, exec, $menu
bind = $mainMod, B, exec, $browser
bind = $mainMod, M, exec, code

# Contrôle des fenêtres
bind = $mainMod, C, killactive,
bind = $mainMod SHIFT, M, exit,
bind = $mainMod, V, togglefloating,
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,
bind = $mainMod, F, fullscreen
bind = $mainMod SHIFT, F, fullscreen, 1
bind = $mainMod, L, exec, hyprlock

# Navigation des fenêtres
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Navigation avec les touches fléchées (HJKL vim-style)
bind = $mainMod, H, movefocus, l
bind = $mainMod, L, movefocus, r
bind = $mainMod, K, movefocus, u  
bind = $mainMod, J, movefocus, d

# Redimensionnement des fenêtres
bind = $mainMod SHIFT, left, resizeactive, -20 0
bind = $mainMod SHIFT, right, resizeactive, 20 0
bind = $mainMod SHIFT, up, resizeactive, 0 -20
bind = $mainMod SHIFT, down, resizeactive, 0 20

# Déplacement des fenêtres
bind = $mainMod CTRL, left, movewindow, l
bind = $mainMod CTRL, right, movewindow, r
bind = $mainMod CTRL, up, movewindow, u
bind = $mainMod CTRL, down, movewindow, d

# Workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Déplacer vers workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Workspace spécial (scratchpad)
bind = $mainMod, S, togglespecialworkspace, magic
bind = $mainMod SHIFT, S, movetoworkspace, special:magic

# Navigation workspaces avec molette
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Captures d'écran
bind = , Print, exec, ~/.local/bin/screenshot-menu
bind = SHIFT, Print, exec, grim -g "$(slurp)" - | wl-copy
bind = $mainMod, Print, exec, grim - | wl-copy

# Contrôles audio
bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bind = , XF86AudioPlay, exec, playerctl play-pause
bind = , XF86AudioNext, exec, playerctl next
bind = , XF86AudioPrev, exec, playerctl previous

# Contrôles de luminosité
bind = , XF86MonBrightnessUp, exec, brightnessctl set 10%+
bind = , XF86MonBrightnessDown, exec, brightnessctl set 10%-

# Raccourcis utilitaires
bind = $mainMod, T, exec, ~/.local/bin/toggle-waybar
bind = $mainMod SHIFT, R, exec, hyprctl reload
bind = $mainMod SHIFT, W, exec, ~/.config/hypr/scripts/wallpaper.sh
bind = $mainMod SHIFT, T, exec, ~/.local/bin/theme-switcher
bind = $mainMod, SPACE, exec, ~/.local/bin/app-launcher

# Gestion de l'énergie
bind = $mainMod SHIFT, L, exec, ~/.local/bin/power-menu
bind = $mainMod SHIFT, P, exec, systemctl suspend

# Déplacement/redimensionnement avec la souris
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Variables pour les performances gaming
env = WLR_DRM_NO_ATOMIC,1
env = __GL_VRR_ALLOWED,1
env = WLR_NO_HARDWARE_CURSORS,1

# Optimisations tearing pour les jeux
windowrulev2 = immediate,class:^(steam_app_.*)$
windowrulev2 = immediate,class:^(gamescope)$
windowrulev2 = immediate,class:^(cs2|csgo|dota2)$

exec-once = ~/.config/hypr/scripts/autostart.sh
exec-once = waybar
exec-once = dunst
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = ~/.config/hypr/scripts/wallpaper.sh random
exec-once = hypridle

EOF

    log "SUCCESS" "Configuration Hyprland créée et optimisée pour $GPU_VENDOR"
}

# Fonctions de configuration GPU spécifique
get_gpu_env_vars() {
    case $GPU_TYPE in
        "nvidia")
            cat << 'EOF'
# Variables NVIDIA Wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1
env = LIBVA_DRIVER_NAME,nvidia
env = __GL_VRR_ALLOWED,1
EOF
            ;;
        "amd")
            cat << 'EOF' 
# Variables AMD optimisées
env = RADV_PERFTEST,aco
env = AMD_VULKAN_ICD,RADV
env = WLR_DRM_NO_ATOMIC,1
env = __GL_VRR_ALLOWED,1
EOF
            ;;
        "intel")
            cat << 'EOF'
# Variables Intel Graphics
env = WLR_NO_HARDWARE_CURSORS,1
env = WLR_DRM_NO_ATOMIC,1
env = INTEL_DEBUG,norbc
EOF
            ;;
        *)
            cat << 'EOF'
# Variables génériques
env = WLR_NO_HARDWARE_CURSORS,1
EOF
            ;;
    esac
}

get_gpu_decoration_config() {
    case $GPU_TYPE in
        "nvidia")
            cat << 'EOF'
decoration {
    rounding = 12
    active_opacity = 0.95
    inactive_opacity = 0.85
    
    blur {
        enabled = true
        size = 10
        passes = 4
        new_optimizations = true
        xray = true
        ignore_opacity = false
        noise = 0.0117
        contrast = 1.1
        brightness = 1.2
    }
    
    drop_shadow = true
    shadow_range = 6
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
    shadow_offset = 0 2
    
    dim_inactive = false
    dim_strength = 0.1
}
EOF
            ;;
        "amd")
            cat << 'EOF'
decoration {
    rounding = 12
    active_opacity = 0.95
    inactive_opacity = 0.90
    
    blur {
        enabled = true
        size = 8
        passes = 3
        new_optimizations = true
        xray = true
        ignore_opacity = false
        noise = 0.0117
        contrast = 1.0
        brightness = 1.0
    }
    
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
    
    dim_inactive = false
}
EOF
            ;;
        "intel")
            cat << 'EOF'
decoration {
    rounding = 10
    active_opacity = 1.0
    inactive_opacity = 0.95
    
    blur {
        enabled = true
        size = 4
        passes = 2
        new_optimizations = true
        xray = false
        ignore_opacity = true
    }
    
    drop_shadow = false
    shadow_range = 2
    shadow_render_power = 2
    col.shadow = rgba(1a1a1aee)
    
    dim_inactive = true
    dim_strength = 0.05
}
EOF
            ;;
        *)
            cat << 'EOF'
decoration {
    rounding = 10
    active_opacity = 0.98
    inactive_opacity = 0.92
    
    blur {
        enabled = true
        size = 6
        passes = 2
        new_optimizations = true
        xray = false
        ignore_opacity = false
    }
    
    drop_shadow = true
    shadow_range = 3
    shadow_render_power = 2
    col.shadow = rgba(1a1a1aee)
}
EOF
            ;;
    esac
}

get_gpu_animation_config() {
    case $GPU_TYPE in
        "nvidia")
            cat << 'EOF'
animations {
    enabled = true
    
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    bezier = easeOutQuart, 0.25, 1, 0.5, 1
    bezier = easeInOutCubic, 0.65, 0, 0.35, 1
    
    animation = windows, 1, 8, myBezier
    animation = windowsOut, 1, 8, default, popin 80%
    animation = border, 1, 12, default
    animation = borderangle, 1, 10, default
    animation = fade, 1, 8, default
    animation = workspaces, 1, 8, easeOutQuart
    animation = specialWorkspace, 1, 8, easeInOutCubic, slidevert
}
EOF
            ;;
        "amd")
            cat << 'EOF'
animations {
    enabled = true
    
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    bezier = easeOut, 0.25, 1, 0.5, 1
    
    animation = windows, 1, 6, myBezier
    animation = windowsOut, 1, 6, default, popin 80%
    animation = border, 1, 8, default
    animation = borderangle, 1, 7, default
    animation = fade, 1, 6, default
    animation = workspaces, 1, 6, easeOut
}
EOF
            ;;
        "intel")
            cat << 'EOF'
animations {
    enabled = true
    
    bezier = simple, 0.16, 1, 0.3, 1
    
    animation = windows, 1, 4, simple
    animation = windowsOut, 1, 4, default, popin 80%
    animation = border, 1, 5, default
    animation = borderangle, 1, 5, default
    animation = fade, 1, 4, default
    animation = workspaces, 1, 4, simple
}
EOF
            ;;
        *)
            cat << 'EOF'
animations {
    enabled = true
    
    bezier = balanced, 0.25, 0.46, 0.45, 0.94
    
    animation = windows, 1, 5, balanced
    animation = windowsOut, 1, 5, default, popin 80%
    animation = border, 1, 6, default
    animation = borderangle, 1, 6, default
    animation = fade, 1, 5, default
    animation = workspaces, 1, 5, balanced
}
EOF
            ;;
    esac
}

get_gpu_window_rules() {
    case $GPU_TYPE in
        "nvidia")
            cat << 'EOF'
# Règles de transparence optimisées NVIDIA
windowrulev2 = opacity 0.95 0.95,class:^(code|Code)$
windowrulev2 = opacity 0.92 0.92,class:^(kitty)$
windowrulev2 = opacity 0.88 0.88,class:^(thunar)$
windowrulev2 = opacity 0.95 0.95,class:^(spotify|Spotify)$
windowrulev2 = opacity 0.90 0.90,class:^(discord|Discord)$
EOF
            ;;
        "intel")
            cat << 'EOF'
# Règles de transparence allégées Intel
windowrulev2 = opacity 1.0 1.0,class:^(code|Code)$
windowrulev2 = opacity 0.98 0.98,class:^(kitty)$
windowrulev2 = opacity 1.0 1.0,class:^(thunar)$
windowrulev2 = opacity 1.0 1.0,class:^(spotify|Spotify)$
windowrulev2 = opacity 1.0 1.0,class:^(discord|Discord)$
EOF
            ;;
        *)
            cat << 'EOF'
# Règles de transparence équilibrées
windowrulev2 = opacity 0.98 0.98,class:^(code|Code)$
windowrulev2 = opacity 0.94 0.94,class:^(kitty)$
windowrulev2 = opacity 0.92 0.92,class:^(thunar)$
windowrulev2 = opacity 0.98 0.98,class:^(spotify|Spotify)$
windowrulev2 = opacity 0.96 0.96,class:^(discord|Discord)$
EOF
            ;;
    esac
}
