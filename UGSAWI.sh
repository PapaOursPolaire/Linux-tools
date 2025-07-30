#!/bin/bash
#set -e

### UNIVERSAL GRUB + SOUND + ANIMATED WALLPAPER INSTALLER (UGSAWI) ###

# --- UTILITIES ---
install_pkg() {
  if command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm "$@"
  elif command -v apt &>/dev/null; then
    sudo apt update && sudo apt install -y "$@"
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y "$@"
  elif command -v zypper &>/dev/null; then
    sudo zypper install -y "$@"
  else
    echo "❌ Aucun gestionnaire de paquets compatible trouvé."
    exit 1
  fi
}

# --- DETECT GRUB PATH & COMMAND ---
if [[ -d /boot/grub2 ]]; then
  GRUB_DIR="/boot/grub2"
else
  GRUB_DIR="/boot/grub"
fi

if command -v grub2-mkconfig &>/dev/null; then
  GRUB_MKCONFIG="grub2-mkconfig"
else
  GRUB_MKCONFIG="grub-mkconfig"
fi

# --- INSTALL DEPENDENCIES ---
echo "📦 Installation des paquets nécessaires..."
install_pkg git wget mpv grub ffmpeg

# --- INSTALL THEMES ---
echo "🎮 Installation des thèmes GRUB..."
THEMES=(
  "fallout|https://github.com/shvchk/fallout-grub-theme"
  "bsol|https://github.com/Lxtharia/bsol-grub-theme"
  "minegrub|https://github.com/Lxtharia/minegrub-theme"
  "crt-amber|https://github.com/VandalByte/crt-amber-grub-theme"
  "arcade|https://github.com/VandalByte/arcade-grub-theme"
  "dark-matter|https://github.com/VandalByte/dark-matter-grub-theme"
  "arcane|https://github.com/arcane-themes/grub-arcane"
  "star-wars|https://github.com/VandalByte/star-wars-grub-theme"
  "lotr|https://github.com/VandalByte/lotr-grub-theme"
)

mkdir -p "$GRUB_DIR/themes"
TMP_DIR="/tmp/grub-themes"
mkdir -p "$TMP_DIR"

for entry in "${THEMES[@]}"; do
  IFS="|" read -r name url <<< "$entry"
  echo "➡️ Installation de $name"
  git clone --depth=1 "$url" "$TMP_DIR/$name"
  cp -r "$TMP_DIR/$name" "$GRUB_DIR/themes/"
done

# --- APPLY DEFAULT THEME ---
echo "🎨 Application du thème Fallout par défaut..."
sudo sed -i '/^GRUB_THEME=/d' /etc/default/grub
sudo bash -c "echo 'GRUB_THEME=\"$GRUB_DIR/themes/fallout/theme.txt\"' >> /etc/default/grub"
$GRUB_MKCONFIG -o "$GRUB_DIR/grub.cfg"

# --- BOOT SOUND ---
echo "🔈 Installation du bip sonore au démarrage..."
BOOT_SOUND_DIR="/usr/share/sounds/boot"
BOOT_SOUND="$BOOT_SOUND_DIR/boot-sound.mp3"
sudo mkdir -p "$BOOT_SOUND_DIR"
wget -qO "$BOOT_SOUND" https://github.com/PapaOursPolaire/fallout-linux-assets/raw/main/boot-sound.mp3

if pidof systemd &>/dev/null; then
  echo "🛠️ Création du service systemd..."
  sudo bash -c 'cat << EOF > /etc/systemd/system/boot-sound.service
[Unit]
Description=Boot Sound
After=sound.target

[Service]
Type=oneshot
ExecStart=/usr/bin/mpv --no-video --quiet --really-quiet '$BOOT_SOUND'

[Install]
WantedBy=multi-user.target
EOF'
  sudo systemctl daemon-reload
  sudo systemctl enable boot-sound.service
else
  echo "⚠️ Systemd non détecté. Son de démarrage désactivé."
fi

# --- GRUB THEME MENU ---
echo "🎮 Choisissez un thème GRUB :"
select entry in "${THEMES[@]%%|*}"; do
  if [[ -n "$entry" ]]; then
    echo "🎨 Activation de $entry..."
    sudo sed -i '/^GRUB_THEME=/d' /etc/default/grub
    sudo bash -c "echo 'GRUB_THEME=\"$GRUB_DIR/themes/$entry/theme.txt\"' >> /etc/default/grub"
    $GRUB_MKCONFIG -o "$GRUB_DIR/grub.cfg"
    echo "✅ Thème activé."
    break
  fi
done

# --- ANIMATED WALLPAPER ---
echo "🖼️ Configuration du fond animé (X11 uniquement)"
WALLPAPER_SCRIPT="$HOME/.config/animated-wallpaper.sh"
VIDEO_DIR="$HOME/Videos/wallpapers"
VIDEO_FILE="$VIDEO_DIR/custom-wallpaper.mp4"

install_pkg xwinwrap zenity
mkdir -p "$VIDEO_DIR"

if [[ -f "$WALLPAPER_SCRIPT" ]]; then
  echo "🔄 Script déjà existant. Mise à jour du fond..."
else
  echo "🧠 Création du script de fond animé..."
  cat << EOF > "$WALLPAPER_SCRIPT"
#!/bin/bash
pkill xwinwrap &>/dev/null || true
xwinwrap -g 1920x1080+0+0 -ni -fs -s -st -sp -b -nf -- mpv --wid=WID --loop --no-audio --panscan=1.0 --no-osc --no-input-default-bindings "$VIDEO_FILE" &
EOF
  chmod +x "$WALLPAPER_SCRIPT"
fi

if [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
  echo "🗂️ Choisissez une vidéo (format .mp4 recommandé)"
  SELECTED_VIDEO=$(zenity --file-selection --title="Choisissez une vidéo pour le fond d'écran")
  if [[ -f "$SELECTED_VIDEO" ]]; then
    cp "$SELECTED_VIDEO" "$VIDEO_FILE"
    bash "$WALLPAPER_SCRIPT"
    echo "✅ Fond d'écran animé mis à jour."
  else
    echo "❌ Aucune vidéo sélectionnée."
  fi
else
  echo "⚠️ Wayland détecté. mpvpaper requis (non couvert ici)."
fi
