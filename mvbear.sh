#!/bin/bash
# Script compatible KDE & Hyprland pour fond animé (.mp4)
# Testé sur : Fedora, Ubuntu, Arch, Debian — devrait fonctionner ailleurs aussi

# Détection de l’environnement graphique
detect_environment() {
    if [[ $XDG_CURRENT_DESKTOP == *"KDE"* || $DESKTOP_SESSION == *"plasma"* ]]; then
        echo "kde"
    elif [[ $XDG_SESSION_DESKTOP == "hyprland" || $XDG_CURRENT_DESKTOP == *"Hyprland"* ]]; then
        echo "hyprland"
    else
        echo "unsupported"
    fi
}

# Installation des dépendances manquantes
install_dependencies() {
    local env="$1"
    local missing=()

    # Gestionnaire de paquets
    if command -v apt &>/dev/null; then
        pkg_manager="apt install -y"
    elif command -v dnf &>/dev/null; then
        pkg_manager="dnf install -y"
    elif command -v pacman &>/dev/null; then
        pkg_manager="pacman -S --noconfirm"
    elif command -v zypper &>/dev/null; then
        pkg_manager="zypper install -y"
    else
        zenity --error --text="Aucun gestionnaire de paquets compatible détecté"
        exit 1
    fi

    # Dépendances communes
    for dep in zenity realpath; do
        command -v "$dep" &>/dev/null || missing+=("$dep")
    done

    # KDE : qdbus
    if [[ "$env" == "kde" ]]; then
        command -v qdbus &>/dev/null || missing+=("qdbus")
    fi

    # Hyprland : mpvpaper, hyprctl, jq
    if [[ "$env" == "hyprland" ]]; then
        for dep in mpvpaper hyprctl jq; do
            command -v "$dep" &>/dev/null || missing+=("$dep")
        done
    fi

    # Installation
    if [[ ${#missing[@]} -gt 0 ]]; then
        zenity --info --text="Installation de : ${missing[*]}"
        sudo $pkg_manager "${missing[@]}" || {
            zenity --error --text="Échec de l'installation de : ${missing[*]}"
            exit 1
        }
    fi
}

# Appliquer fond vidéo sous KDE
setup_kde() {
    local video_path
    video_path=$(realpath "$1")

    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
    var allDesktops = desktops();
    for (i=0; i<allDesktops.length; i++) {
        d = allDesktops[i];
        d.wallpaperPlugin = 'org.kde.video';
        d.currentConfigGroup = Array('Wallpaper', 'org.kde.video', 'General');
        d.writeConfig('Video', 'file://$video_path');
    }"

    zenity --info --text="Fond vidéo KDE appliqué avec succès !\nRedémarrez Plasma si besoin (Alt+F2 → 'plasmashell --replace')"
}

# Appliquer fond vidéo sous Hyprland
setup_hyprland() {
    pkill mpvpaper 2>/dev/null
    screens=$(hyprctl monitors -j | jq -r '.[].name')

    for screen in $screens; do
        mpvpaper -o "no-audio loop" "$screen" "$1" &
    done

    zenity --info --text="Fond vidéo Hyprland appliqué sur : $screens"
}

# Sélecteur de fichier avec détection de langue
get_video_file() {
    default_dir="$HOME/Videos"
    [[ ! -d "$default_dir" ]] && default_dir="$HOME/Vidéos"

    zenity --file-selection \
        --title="Choisissez une vidéo MP4" \
        --file-filter="*.mp4" \
        --filename="$default_dir/"
}

# Main
env=$(detect_environment)

case "$env" in
    kde|hyprland)
        install_dependencies "$env"
        video=$(get_video_file)
        [[ -z "$video" ]] && exit 0

        if [[ "$env" == "kde" ]]; then
            setup_kde "$video"
        else
            setup_hyprland "$video"
        fi
        ;;
    *)
        zenity --error --text="Environnement non pris en charge : $XDG_CURRENT_DESKTOP"
        exit 1
        ;;
esac
