set -euo pipefail

#Variables
REPO_URL="https://github.com/fastfetch-cli/fastfetch.git"
CLONE_DIR="$HOME/fastfetch_build"
CONFIG_DIR="$HOME/.config/fastfetch"
CONFIG_FILE="$CONFIG_DIR/config.conf"

echo "Détection de la distribution..."
if command -v pacman &>/dev/null; then
  INSTALLER="sudo pacman -Sy --noconfirm"
  DEPS="git cmake gcc make libpng pango freetype2"
elif command -v apt &>/dev/null; then
  INSTALLER="sudo apt update && sudo apt install -y"
  DEPS="git cmake build-essential libpng-dev libpango1.0-dev libfreetype6-dev"
elif command -v dnf &>/dev/null; then
  INSTALLER="sudo dnf install -y"
  DEPS="git cmake gcc make libpng pango freetype"
elif command -v zypper &>/dev/null; then
  INSTALLER="sudo zypper install -y"
  DEPS="git cmake gcc make libpng pango freetype2"
else
  echo "Distribution inconnue"
  exit 1
fi

echo "Installation des dépendances..."
eval "$INSTALLER $DEPS"

echo "Nettoyage..."
rm -rf "$CLONE_DIR"
git clone "$REPO_URL" "$CLONE_DIR"

echo "Compilation avec CMake..."
cd "$CLONE_DIR"
mkdir -p build
cd build
cmake ..
make -j$(nproc)
sudo make install

echo "Configuration graphique..."
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" << 'EOF'
#FASTFETCH CONFIGURATION

logo = "arch"
logo_type = "ascii"
logo_width = 34

# Pour image personnalisée :
# logo = "/chemin/vers/image.png"
# logo_type = "kitty"

color = "mediumorchid"
color_keys = "darkviolet"
color_title = "violet"
color_bold = "mediumorchid"

padding_top = 1
padding_left = 2
align = "left"

structure = "title os kernel de wm shell terminal cpu gpu memory disk battery uptime"
EOF

echo "Ajout de fastfetch au terminal..."
if [[ "$SHELL" == */bash ]]; then
  [[ -f ~/.bashrc ]] && echo -e "\nfastfetch" >> ~/.bashrc
elif [[ "$SHELL" == */zsh ]]; then
  [[ -f ~/.zshrc ]] && echo -e "\nfastfetch" >> ~/.zshrc
else
  echo "Shell inconnu. Ajoutez 'fastfetch' manuellement."
fi

echo "Installation terminée. Lancez fastfetch ou redémarrez le terminal."
