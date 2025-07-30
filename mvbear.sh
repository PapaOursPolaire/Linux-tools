#!/bin/bash

# Vérifier si le script est exécuté en tant que root
if [ "$(id -u)" -eq 0 ]; then
    echo "Ce script ne doit pas être exécuté avec les droits root/sudo."
    exit 1
fi

# Détection de l'environnement de bureau
detect_desktop_environment() {
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]'
    else
        echo "${XDG_DATA_DIRS}" | grep -Eo 'xfce|kde|gnome|mate|cinnamon|lxde' | sort -u | head -1
    fi
}

DE=$(detect_desktop_environment)
echo "Environnement détecté : $DE"

# Détection du gestionnaire de paquets
detect_package_manager() {
    if [ -x "$(command -v apt)" ]; then
        echo "apt"
    elif [ -x "$(command -v dnf)" ]; then
        echo "dnf"
    elif [ -x "$(command -v yum)" ]; then
        echo "yum"
    elif [ -x "$(command -v pacman)" ]; then
        echo "pacman"
    elif [ -x "$(command -v zypper)" ]; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

PM=$(detect_package_manager)
echo "Gestionnaire de paquets détecté : $PM"

# Installation des dépendances
install_dependencies() {
    case "$PM" in
        apt)
            sudo apt update
            sudo apt install -y x11-utils mpv ffmpeg zenity git make gcc libx11-dev
            ;;
        dnf|yum)
            sudo $PM install -y libX11-devel mpv ffmpeg zenity git gcc
            ;;
        pacman)
            sudo pacman -Sy --noconfirm xorg-server-devel mpv ffmpeg zenity git gcc
            ;;
        zypper)
            sudo zypper in -y x11-devel mpv ffmpeg zenity git gcc
            ;;
        *)
            echo "Gestionnaire de paquets non supporté. Veuillez installer manuellement :"
            echo "- mpv, ffmpeg, zenity, git, gcc, libx11-dev"
            exit 1
            ;;
    esac
}

# Compilation de xwinwrap
compile_xwinwrap() {
    if ! command -v xwinwrap &> /dev/null; then
        echo "Compilation de xwinwrap..."
        git clone https://github.com/ujjwal96/xwinwrap.git
        cd xwinwrap
        make
        sudo make install
        cd ..
        rm -rf xwinwrap
    fi
}

# Fonction pour sélectionner la vidéo
select_video() {
    zenity --file-selection \
        --title="Sélectionnez une vidéo" \
        --file-filter="Vidéos | *.mp4 *.avi *.mov *.mkv *.flv *.webm *.wmv"
}

# Fonction pour démarrer le fond d'écran vidéo
start_video_background() {
    VIDEO_PATH="$1"
    xwinwrap -ni -ov -fs -- \
        mpv -wid WID --loop --no-audio --no-osc --no-osd-bar --input-vo-keyboard=no \
        --really-quiet "$VIDEO_PATH" >/dev/null 2>&1 &
}

# Fonction pour KDE Plasma
setup_kde() {
    if ! command -v plasma-change-wallpaper &> /dev/null; then
        echo "Installation de l'extension Plasma Video Wallpaper..."
        sudo $PM install -y plasma5-wallpapers-dynamic
    fi
    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
        var allDesktops = desktops();
        for (i=0;i<allDesktops.length;i++) {{
            d = allDesktops[i];
            d.wallpaperPlugin = 'org.kde.videowallpaper';
            d.currentConfigGroup = Array('Wallpaper', 'org.kde.videowallpaper', 'General');
            d.writeConfig('Image', 'file://$VIDEO_PATH')
        }}
    "
}

# Fonction pour GNOME (expérimental)
setup_gnome() {
    gsettings set org.gnome.desktop.background picture-uri "file://$VIDEO_PATH"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$VIDEO_PATH"
    echo "Remarque : GNOME ne supporte pas nativement les fonds vidéo."
    echo "Utilisation de xwinwrap comme solution alternative."
    start_video_background "$VIDEO_PATH"
}

# Installation des dépendances
echo "Installation des dépendances..."
install_dependencies
compile_xwinwrap

# Sélection de la vidéo
VIDEO=$(select_video)
[ -z "$VIDEO" ] && exit 0

# Configuration selon l'environnement
case "$DE" in
    *kde*)
        setup_kde "$VIDEO"
        ;;
    *gnome*)
        setup_gnome "$VIDEO"
        ;;
    *)
        echo "Utilisation de la méthode générique (xwinwrap)"
        start_video_background "$VIDEO"
        ;;
esac

echo "Fond d'écran vidéo activé !"
echo "Pour stopper : pkill xwinwrap && pkill mpv"