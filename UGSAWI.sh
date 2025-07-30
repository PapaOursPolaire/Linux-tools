#!/bin/bash

# ───── CORRECTION GIT POUR ÉVITER L’AUTHENTIFICATION ─────
git config --global --unset credential.helper 2>/dev/null
git config --global credential.helper ""
git config --global --unset user.name 2>/dev/null
git config --global --unset user.password 2>/dev/null
unset GIT_ASKPASS
unset SSH_ASKPASS

### UNIVERSAL GRUB + BOOT SOUND + THEME SELECTOR ###

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

# --- INSTALL GRUB THEMES ---
echo "🎮 Installation des thèmes GRUB..."
THEMES=(
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
  echo "➡️ Clonage du thème : $name"

  if [[ -d "$TMP_DIR/$name" ]]; then
    echo "⏭️ $name déjà présent temporairement, on saute..."
  else
    git clone --depth=1 "$url" "$TMP_DIR/$name" || {
      echo "❌ Échec du clonage de $name"
      continue
    }
  fi

  if [[ -d "$GRUB_DIR/themes/$name" ]]; then
    echo "🎨 $name déjà installé dans GRUB, on saute la copie."
  else
    sudo cp -r "$TMP_DIR/$name" "$GRUB_DIR/themes/"
  fi
done

# --- APPLY DEFAULT THEME ---
echo "🎨 Application du thème par défaut : BSOL"
sudo sed -i '/^GRUB_THEME=/d' /etc/default/grub
sudo bash -c "echo 'GRUB_THEME=\"$GRUB_DIR/themes/bsol/theme.txt\"' >> /etc/default/grub"
$GRUB_MKCONFIG -o "$GRUB_DIR/grub.cfg"

# --- BOOT SOUND ---
echo "🔈 Installation du son de démarrage..."
BOOT_SOUND_DIR="/usr/share/sounds/boot"
BOOT_SOUND="$BOOT_SOUND_DIR/boot-sound.mp3"
sudo mkdir -p "$BOOT_SOUND_DIR"
wget -qO "$BOOT_SOUND" https://github.com/PapaOursPolaire/fallout-linux-assets/raw/main/boot-sound.mp3

if pidof systemd &>/dev/null; then
  echo "🛠️ Création du service systemd pour le son..."
  sudo bash -c "cat > /etc/systemd/system/boot-sound.service <<EOF
[Unit]
Description=Boot Sound
After=sound.target

[Service]
Type=oneshot
ExecStart=/usr/bin/mpv --no-video --quiet --really-quiet $BOOT_SOUND

[Install]
WantedBy=multi-user.target
EOF"
  sudo systemctl daemon-reload
  sudo systemctl enable boot-sound.service
else
  echo "⚠️ systemd non détecté. Impossible d'activer le son de démarrage."
fi

# --- GRUB THEME MENU ---
echo "🎮 Sélection d'un thème GRUB :"
select entry in "${THEMES[@]%%|*}"; do
  if [[ -n "$entry" ]]; then
    echo "🎨 Activation de : $entry"
    sudo sed -i '/^GRUB_THEME=/d' /etc/default/grub
    sudo bash -c "echo 'GRUB_THEME=\"$GRUB_DIR/themes/$entry/theme.txt\"' >> /etc/default/grub"
    $GRUB_MKCONFIG -o "$GRUB_DIR/grub.cfg"
    echo "✅ Thème $entry activé."
    break
  fi
done
