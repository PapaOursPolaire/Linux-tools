#!/bin/bash

# Vérification des droits root
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
        dnf)
            sudo dnf install -y libX11-devel mpv ffmpeg zenity git gcc
            ;;
        yum)
            sudo yum install -y libX11-devel mpv ffmpeg zenity git gcc
            ;;
        pacman)
            sudo pacman -Sy --noconfirm xorg-server-devel mpv ffmpeg zenity git gcc
            ;;
        zypper)
            sudo zypper in -n libX11-devel mpv ffmpeg zenity git gcc
            ;;
        *)
            echo "Gestionnaire de paquets non supporté. Veuillez installer manuellement :"
            echo "- mpv, ffmpeg, zenity, git, gcc, libx11-dev"
            exit 1
            ;;
    esac
    
    # Installation spécifique pour KDE
    if [[ "$DE" == *kde* ]]; then
        case "$PM" in
            apt) 
                sudo apt install -y qdbus plasma-wallpapers-dynamic
                ;;
            dnf|yum) 
                sudo $PM install -y qt5-qdbus plasma5-wallpapers-dynamic
                ;;
            pacman) 
                sudo pacman -S --noconfirm qt5-tools plasma5-wallpapers-dynamic
                ;;
            zypper) 
                sudo zypper in -n libqt5-qdbus-5 plasma5-wallpapers-dynamic
                ;;
        esac
    fi
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

# Sélection de la vidéo
select_video() {
    zenity --file-selection \
        --title="Sélectionnez une vidéo" \
        --filename="$HOME/Vidéos/" \
        --file-filter="Vidéos | *.mp4 *.avi *.mov *.mkv *.flv *.webm *.wmv"
}

# Détection du son
detect_audio() {
    zenity --question \
        --title="Activation du son" \
        --text="Voulez-vous activer le son de l'arrière-plan ?" \
        --ok-label="Oui" \
        --cancel-label="Non"
    # Renvoie 0 pour Oui, 1 pour Non
}

# Configuration automatique du démarrage
setup_autostart() {
    local video_path="$1"
    local audio_enabled="$2"
    
    mkdir -p "$HOME/.config/autostart"
    
    cat > "$HOME/.config/autostart/video-wallpaper.desktop" <<EOL
[Desktop Entry]
Name=Fond d'écran vidéo
Exec="$0" --start "$video_path" $audio_enabled
Type=Application
Hidden=false
X-GNOME-Autostart-enabled=true
EOL

    echo "Configuration automatique activée pour la session : $USER"
}

# Démarrage du fond vidéo
start_video_background() {
    local VIDEO_PATH="$1"
    local AUDIO_ENABLED="$2"
    
    # Options audio
    local AUDIO_OPT="--no-audio"
    [ "$AUDIO_ENABLED" -eq 0 ] && AUDIO_OPT="--audio-device=auto --volume=50 --no-mute"
    
    # Options de comportement
    local BEHAVIOR_OPTS="
        --loop=inf \
        --no-osc \
        --no-osd-bar \
        --input-vo-keyboard=no \
        --really-quiet \
        --panscan=1.0 \
        --stop-screensaver \
        --no-input-default-bindings \
        --cursor-autohide=always \
        --no-keepaspect"
    
    # Démarrer le fond
    xwinwrap -ni -ov -fs -- mpv -wid WID $AUDIO_OPT $BEHAVIOR_OPTS "$VIDEO_PATH" >/dev/null 2>&1 &
}

# Fonction pour KDE Plasma
setup_kde() {
    local VIDEO_PATH="$1"
    local AUDIO_ENABLED="$2"
    
    # Solution de repli si qdbus n'est pas disponible
    if ! command -v qdbus &> /dev/null; then
        echo "qdbus non disponible, utilisation de la méthode xwinwrap"
        start_video_background "$VIDEO_PATH" "$AUDIO_ENABLED"
        return
    fi
    
    # Configuration avec qdbus
    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
        var allDesktops = desktops();
        for (i=0;i<allDesktops.length;i++) {
            d = allDesktops[i];
            d.wallpaperPlugin = 'org.kde.videowallpaper';
            d.currentConfigGroup = Array('Wallpaper', 'org.kde.videowallpaper', 'General');
            d.writeConfig('Image', 'file://$VIDEO_PATH');
            d.writeConfig('Playback', $AUDIO_ENABLED);
        }
    "
}

# --- Début de l'exécution principale ---

# Mode de démarrage automatique
if [ "$1" = "--start" ]; then
    VIDEO_PATH="$2"
    AUDIO_ENABLED="$3"
    
    if [ ! -f "$VIDEO_PATH" ]; then
        echo "Fichier vidéo introuvable: $VIDEO_PATH"
        exit 1
    fi
    
    DE=$(detect_desktop_environment)
    
    case "$DE" in
        *kde*)
            setup_kde "$VIDEO_PATH" "$AUDIO_ENABLED"
            ;;
        *)
            start_video_background "$VIDEO_PATH" "$AUDIO_ENABLED"
            ;;
    esac
    exit 0
fi

# Installation des dépendances
echo "Installation des dépendances..."
install_dependencies
compile_xwinwrap

# Sélection de la vidéo
VIDEO=$(select_video)
[ -z "$VIDEO" ] && exit 0

# Activation du son
detect_audio
AUDIO_ENABLED=$?

# Configuration selon l'environnement
case "$DE" in
    *kde*)
        setup_kde "$VIDEO" "$AUDIO_ENABLED"
        ;;
    *)
        start_video_background "$VIDEO" "$AUDIO_ENABLED"
        ;;
esac

# Configuration du démarrage automatique
zenity --question \
    --title="Démarrage automatique" \
    --text="Voulez-vous démarrer automatiquement ce fond d'écran à l'ouverture de session ?" \
    --width=300
if [ $? -eq 0 ]; then
    setup_autostart "$VIDEO" "$AUDIO_ENABLED"
fi

echo "Fond d'écran vidéo activé !"
echo "Pour stopper : pkill xwinwrap && pkill mpv"
