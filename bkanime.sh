#!/bin/bash

# === Configuration ===
WALLPAPER_URL="https://raw.githubusercontent.com/LuMarans30/FalloutPipBoy-Plasma6-Splashscreen/main/FalloutPipBoy-Loading-Plasma6/contents/splash/images/pipboyanim.gif"
WALLPAPER_DIR="$HOME/Videos/wallpapers"
WALLPAPER_FILE="$WALLPAPER_DIR/fallout-wallpaper.mp4"

# Crée le dossier si absent
mkdir -p "$WALLPAPER_DIR"

# Téléchargement + conversion GIF → MP4 (si besoin)
if [[ ! -f "$WALLPAPER_FILE" ]]; then
    echo "📥 Téléchargement du fond animé Fallout..."
    wget -O "$WALLPAPER_DIR/fallout.gif" "$WALLPAPER_URL"
    echo "🎞️ Conversion GIF en MP4..."
    ffmpeg -y -i "$WALLPAPER_DIR/fallout.gif" -vf "scale=1920:1080" -c:v libx264 -pix_fmt yuv420p "$WALLPAPER_FILE"
fi

# === Détection de l’environnement ===
ENVIRONMENT=$(loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Desktop --value)
DISPLAY_SERVER=$(echo "$XDG_SESSION_TYPE")

echo "🔍 Environnement détecté : $ENVIRONMENT"
echo "🔍 Affichage : $DISPLAY_SERVER"

# === Conditions ===

# mpvpaper pour Hyprland ou wlroots compatibles → éviter ici
if [[ "$ENVIRONMENT" == "Hyprland" || "$DISPLAY_SERVER" == "wayland" ]]; then
    echo "❌ mpvpaper ou animation non supportée ici (Wayland non compatible avec KDE/GNOME)"
    exit 0
fi

# Vérifie si xwinwrap est installé
if ! command -v xwinwrap &>/dev/null; then
    echo "📦 Installation de xwinwrap (nécessaire)"
    yay -S --noconfirm xwinwrap-git || {
        echo "❌ Échec installation xwinwrap. Abandon."
        exit 1
    }
fi

# Vérifie si mpv est installé
if ! command -v mpv &>/dev/null; then
    echo "📦 mpv manquant. Installation..."
    sudo pacman -S --noconfirm mpv
fi

# === Lancer fond animé avec xwinwrap + mpv ===

echo "🚀 Lancement du fond animé sur le bureau..."

# Tue les instances précédentes
pkill xwinwrap &>/dev/null

# Lancer fond animé avec transparence et sans contrôle
xwinwrap -g 1920x1080+0+0 -ni -fs -s -st -sp -b -nf -- mpv --wid=WID --loop --no-audio --panscan=1.0 --no-osc --no-input-default-bindings "$WALLPAPER_FILE" &

echo "✅ Fond animé en cours (xwinwrap + mpv)"
