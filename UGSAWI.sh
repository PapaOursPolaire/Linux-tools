#!/bin/bash
export GIT_TERMINAL_PROMPT=0

### UNIVERSAL GRUB + SOUND + ANIMATED WALLPAPER INSTALLER ###

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

# --- CLEAN GIT CONFIG TO AVOID LOGIN PROMPTS ---
git config --global --unset credential.helper
git config --global credential.helper ""

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

  if [[ -d "$TMP_DIR/$name" ]]; then
    echo "⏭️ $name déjà cloné, on saute..."
  else
    git clone --depth=1 "$url" "$TMP_DIR/$name" || {
      echo "❌ Échec du clonage de $name"
      continue
    }
  fi

  if [[ -d "$GRUB_DIR/themes/$name" ]]; then
    echo "🎨 $name déjà présent dans GRUB, on saute la copie."
  else
    sudo cp -r "$TMP_DIR/$name" "$GRUB_DIR/themes/"
  fi
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

# --- DETECT DE AND CONFIGURE ANIMATED WALLPAPER ---
VIDEO_DIR="$HOME/Videos/wallpapers"
VIDEO_FILE="$VIDEO_DIR/custom-wallpaper.mp4"
mkdir -p "$VIDEO_DIR"

echo "🖼️ Détection de l'environnement de bureau..."
DE=""
if [[ "$XDG_CURRENT_DESKTOP" == *"KDE"* ]]; then
  DE="kde"
elif [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]]; then
  DE="gnome"
elif [[ "$XDG_SESSION_TYPE" == "wayland" && "$XDG_CURRENT_DESKTOP" == *"Hyprland"* ]]; then
  DE="hyprland"
elif [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
  DE="x11"
fi

echo "🧠 Choisissez une vidéo pour le fond animé (mp4 recommandé)..."
install_pkg zenity
SELECTED_VIDEO=$(zenity --file-selection --title="Choisissez une vidéo animée de fond")
if [[ ! -f "$SELECTED_VIDEO" ]]; then
  echo "❌ Aucune vidéo sélectionnée."
else
  cp "$SELECTED_VIDEO" "$VIDEO_FILE"
  echo "✅ Vidéo copiée dans $VIDEO_FILE"

  case "$DE" in
    kde)
      echo "🎥 Intégration fond animé dans KDE..."
      qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
      var allDesktops = desktops();
      for (i=0;i<allDesktops.length;i++) {
        d = allDesktops[i];
        d.wallpaperPlugin = 'org.kde.video';
        d.currentConfigGroup = Array('Wallpaper', 'org.kde.video', 'General');
        d.writeConfig('Video', '$VIDEO_FILE');
      }"
      ;;
    gnome)
      echo "🎥 Intégration fond animé dans GNOME (sans son, en image statique de secours)..."
      gsettings set org.gnome.desktop.background picture-uri "file://$VIDEO_FILE"
      ;;
    hyprland)
      echo "⚠️ Hyprland détecté. Veuillez installer et configurer 'mpvpaper' manuellement."
      echo "Exemple : mpvpaper '*' \"$VIDEO_FILE\""
      ;;
    x11)
      echo "🎥 Intégration fond animé via xwinwrap..."
      install_pkg xwinwrap
      pkill xwinwrap &>/dev/null || true
      xwinwrap -g 1920x1080+0+0 -ni -fs -s -st -sp -b -nf -- mpv --wid=WID --loop --no-audio --panscan=1.0 --no-osc --no-input-default-bindings "$VIDEO_FILE" &
      ;;
    *)
      echo "❌ Environnement de bureau non détecté ou non pris en charge automatiquement."
      ;;
  esac
fi
