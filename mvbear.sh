#!/bin/bash
#Version 23.0

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
    
    # Créer un script wrapper pour gérer les chemins avec espaces
    local wrapper_script="$HOME/.config/video-wallpaper-wrapper.sh"
    cat > "$wrapper_script" <<EOL
#!/bin/bash
"$0" --start "$video_path" $audio_enabled
EOL
    chmod +x "$wrapper_script"
    
    cat > "$HOME/.config/autostart/video-wallpaper.desktop" <<EOL
[Desktop Entry]
Name=Fond d'écran vidéo
Exec="$wrapper_script"
Type=Application
Hidden=false
X-GNOME-Autostart-enabled=true
EOL

    echo "Configuration automatique activée pour la session : $USER"
}

# Démarrage du fond vidéo avec MPV
start_video_background() {
    local VIDEO_PATH="$1"
    local AUDIO_ENABLED="$2"
    
    # Vérifier si le processus est déjà en cours d'exécution
    pkill -f "xwinwrap.*$(basename "$VIDEO_PATH")"
    pkill -f "mpv.*$(basename "$VIDEO_PATH")"
    
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
        --hwdec=auto \
        --vo=gpu \
        --gpu-context=x11 \
        --no-border \
        --no-keepaspect"
    
    # Forcer l'utilisation de MPV comme lecteur vidéo
    xwinwrap -ni -ov -fs -- mpv -wid WID $AUDIO_OPT $BEHAVIOR_OPTS "$VIDEO_PATH" >/dev/null 2>&1 &
    
    echo "Fond vidéo démarré avec MPV (PID $!)"
}

# Fonction pour KDE Plasma
setup_kde() {
    local VIDEO_PATH="$1"
    local AUDIO_ENABLED="$2"
    
    # Solution de repli si qdbus n'est pas disponible
    if ! command -v qdbus &> /dev/null; then
        echo "qdbus non disponible, utilisation de la méthode MPV"
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
    
    # Vérifier si la configuration a réussi
    sleep 2
    if ! pgrep -f "plasma-video" >/dev/null; then
        echo "La méthode KDE native a échoué, basculement sur MPV"
        start_video_background "$VIDEO_PATH" "$AUDIO_ENABLED"
    fi
}

# Tester si mpv fonctionne avec la vidéo
test_video_playback() {
    local VIDEO_PATH="$1"
    
    timeout 3 mpv --no-config --vo=null --ao=null "$VIDEO_PATH" >/dev/null 2>&1
    return $?
}

# Vérifier l'association MIME
check_mime_association() {
    local video_path="$1"
    local mime_type=$(xdg-mime query filetype "$video_path")
    
    # Vérifier si MPV est associé à ce type MIME
    if ! xdg-mime query default "$mime_type" | grep -qi "mpv"; then
        echo "Le type MIME $mime_type n'est pas associé à MPV"
        
        # Essayer d'associer MPV
        if command -v xdg-mime &> /dev/null; then
            echo "Tentative d'association de MPV avec $mime_type..."
            xdg-mime default mpv.desktop "$mime_type"
        fi
        
        return 1
    fi
    
    return 0
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
    
    # Attendre que l'environnement de bureau soit prêt
    sleep 5
    
    DE=$(detect_desktop_environment)
    
    # Vérifier l'association MIME
    check_mime_association "$VIDEO_PATH"
    
    # Tester la lecture vidéo
    if ! test_video_playback "$VIDEO_PATH"; then
        echo "Échec de la lecture de la vidéo, tentative de correction..."
        sudo apt install --reinstall -y ffmpeg mpv || \
        sudo dnf reinstall -y ffmpeg mpv || \
        sudo pacman -S --noconfirm ffmpeg mpv
    fi
    
    case "$DE" in
        *kde*)
            setup_kde "$VIDEO_PATH" "$AUDIO_ENABLED"
            ;;
        *)
            start_video_background "$VIDEO_PATH" "$AUDIO_ENABLED"
            ;;
    esac
    
    # Vérifier si le processus est en cours d'exécution
    sleep 3
    if ! pgrep -f "mpv.*$(basename "$VIDEO_PATH")" >/dev/null; then
        echo "Échec du démarrage avec MPV, essai avec FFmpeg..."
        # Solution alternative avec FFmpeg
        xwinwrap -ni -ov -fs -- ffmpeg -re -i "$VIDEO_PATH" -vf "scale=iw:-1" -c:v rawvideo -pix_fmt yuv420p -f v4l2 /dev/null >/dev/null 2>&1 &
    fi
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

# Vérifier l'association MIME
check_mime_association "$VIDEO"

# Configuration selon l'environnement
case "$DE" in
    *kde*)
        setup_kde "$VIDEO" "$AUDIO_ENABLED"
        ;;
    *)
        start_video_background "$VIDEO" "$AUDIO_ENABLED"
        ;;
esac

# Attendre 3 secondes et vérifier si le processus est toujours en cours
sleep 3
if ! pgrep -f "mpv.*$(basename "$VIDEO")" >/dev/null; then
    echo "Échec du démarrage du fond vidéo, tentative avec FFmpeg..."
    pkill -f "xwinwrap.*$(basename "$VIDEO")"
    
    # Solution alternative avec FFmpeg
    xwinwrap -ni -ov -fs -- ffmpeg -re -i "$VIDEO" -vf "scale=iw:-1" -c:v rawvideo -pix_fmt yuv420p -f v4l2 /dev/null >/dev/null 2>&1 &
    
    # Si cela échoue aussi, utiliser une méthode de secours
    sleep 3
    if ! pgrep -f "ffmpeg.*$(basename "$VIDEO")" >/dev/null; then
        echo "Utilisation de la méthode de secours avec xvfb..."
        xvfb-run -a mpv --loop=inf "$VIDEO" >/dev/null 2>&1 &
    fi
fi

# Configuration du démarrage automatique
zenity --question \
    --title="Démarrage automatique" \
    --text="Voulez-vous démarrer automatiquement ce fond d'écran à l'ouverture de session ?" \
    --width=300
if [ $? -eq 0 ]; then
    setup_autostart "$VIDEO" "$AUDIO_ENABLED"
fi

echo "Fond d'écran vidéo activé !"
echo "Pour stopper : pkill -f 'xwinwrap|mpv|ffmpeg'"
