#!/bin/bash

# Script d'installation automatisée Arch Linux - Version Complète
# Made by Papa Ours
# Version: 109.1

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fonction d'affichage coloré
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Fonction de validation du nom d'utilisateur
validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-z][a-z0-9_-]*$ ]] || [[ ${#username} -lt 3 ]] || [[ ${#username} -gt 32 ]]; then
        return 1
    fi
    return 0
}

# Fonction de validation du nom d'hôte
validate_hostname() {
    local hostname="$1"
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] || [[ ${#hostname} -lt 2 ]] || [[ ${#hostname} -gt 63 ]]; then
        return 1
    fi
    return 0
}

# Fonction de validation de la taille des partitions
validate_size() {
    local size="$1"
    if [[ "$size" =~ ^[0-9]+[MmGg]$ ]]; then
        return 0
    fi
    return 1
}

# Bannière d'accueil
clear
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                  INSTALLATION AUTOMATISÉE ARCH LINUX                          ║
║                         Edition Fallout/Arcane                                ║
║                            Version 109.1                                      ║
║                                                                               ║
║  🎮 Thème Fallout/Arcane complet                                             ║
║  🎵 Audio + Cava + Spicetify                                                 ║
║  💻 Dev Setup (VSCode, Android Studio, etc.)                                 ║
║  🌐 Chrome, Brave, Netflix, Disney+                                          ║
║  🍷 Wine + Windows Apps                                                      ║
║  🎞️ Thème Plymouth + GRUB animé                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Vérification de la connexion internet
print_info "Vérification de la connexion internet..."
if ! ping -c 1 archlinux.org &> /dev/null; then
    print_error "Pas de connexion internet. Veuillez configurer votre réseau manuellement ou vous connecter via un câble ethernet."
    exit 1
fi
print_success "Connexion internet établie"

# Synchronisation de l'horloge
print_info "Synchronisation de l'horloge système..."
timedatectl set-ntp true

# Mise à jour des clés de signature et miroirs
print_info "Mise à jour des clés de signature et des miroirs..."
pacman-key --init
pacman-key --populate archlinux
pacman-key --refresh-keys

# Mise à jour des miroirs pour de meilleures performances
print_info "Mise à jour de la liste des miroirs..."
pacman -Sy --noconfirm reflector
reflector --country France,Belgium,Germany,Netherlands --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Mise à jour de la base de données des paquets
pacman -Sy

# Configuration du nom d'hôte (nom du PC)
while true; do
    echo ""
    read -p "Nom du PC (hostname - lettres, chiffres, tirets uniquement, 2 à 60 caractères): " HOSTNAME
    if validate_hostname "$HOSTNAME"; then
        break
    else
        print_error "Nom d'hôte invalide. Utilisez uniquement des lettres, chiffres et tirets."
    fi
done

# Configuration de l'utilisateur principal - FIX: Affichage visible
while true; do
    echo ""
    echo -n "Nom d'utilisateur principal (lettres minuscules, chiffres, _, -, 3 à 30 caractères): "
    read USERNAME
    if validate_username "$USERNAME"; then
        break
    else
        print_error "Nom d'utilisateur invalide. Doit commencer par une lettre minuscule."
    fi
done

# Mot de passe utilisateur principal
while true; do
    echo ""
    read -s -p "Mot de passe pour $USERNAME (minimum 6 caractères): " USER_PASSWORD
    echo
    if [[ ${#USER_PASSWORD} -lt 6 ]]; then
        print_error "Le mot de passe doit contenir au moins 6 caractères."
        continue
    fi
    read -s -p "Confirmez le mot de passe: " USER_PASSWORD_CONFIRM
    echo
    if [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]]; then
        print_success "Mot de passe accepté (${#USER_PASSWORD} caractères)"
        break
    else
        print_error "Les mots de passe ne correspondent pas."
    fi
done

# Utilisateur supplémentaire
echo ""
read -p "Voulez-vous créer un utilisateur supplémentaire ? (O/N): " CREATE_EXTRA_USER
EXTRA_USERNAME=""
EXTRA_PASSWORD=""

if [[ "$CREATE_EXTRA_USER" =~ ^[oO]$ ]]; then
    while true; do
        echo -n "Nom du deuxième utilisateur (lettres minuscules, chiffres, _, -, 3 à 30 caractères): "
        read EXTRA_USERNAME
        if validate_username "$EXTRA_USERNAME" && [[ "$EXTRA_USERNAME" != "$USERNAME" ]]; then
            break
        else
            print_error "Nom d'utilisateur invalide ou identique au premier utilisateur."
        fi
    done
    
    while true; do
        read -s -p "Mot de passe pour $EXTRA_USERNAME (minimum 6 caractères): " EXTRA_PASSWORD
        echo
        if [[ ${#EXTRA_PASSWORD} -lt 6 ]]; then
            print_error "Le mot de passe doit contenir au moins 6 caractères."
            continue
        fi
        read -s -p "Confirmez le mot de passe: " EXTRA_PASSWORD_CONFIRM
        echo
        if [[ "$EXTRA_PASSWORD" == "$EXTRA_PASSWORD_CONFIRM" ]]; then
            print_success "Mot de passe accepté (${#EXTRA_PASSWORD} caractères)"
            break
        else
            print_error "Les mots de passe ne correspondent pas."
        fi
    done
fi

# Mot de passe root
while true; do
    echo ""
    read -s -p "Mot de passe root (minimum 6 caractères): " ROOT_PASSWORD
    echo
    if [[ ${#ROOT_PASSWORD} -lt 6 ]]; then
        print_error "Le mot de passe root doit contenir au moins 6 caractères."
        continue
    fi
    read -s -p "Confirmez le mot de passe root: " ROOT_PASSWORD_CONFIRM
    echo
    if [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]]; then
        print_success "Mot de passe root accepté (${#ROOT_PASSWORD} caractères)"
        break
    else
        print_error "Les mots de passe ne correspondent pas."
    fi
done

# Sélection du disque
print_info "Disques disponibles:"
lsblk -d -o NAME,SIZE,MODEL | grep -E "sd|nvme|vd"
echo ""

# Listing des disques pour sélection
DISKS=($(lsblk -d -o NAME -n | grep -E "sd|nvme|vd"))
for i in "${!DISKS[@]}"; do
    SIZE=$(lsblk -d -o SIZE -n "/dev/${DISKS[$i]}")
    MODEL=$(lsblk -d -o MODEL -n "/dev/${DISKS[$i]}" 2>/dev/null || echo "N/A")
    echo "$((i+1)). /dev/${DISKS[$i]} - $SIZE - $MODEL"
done

while true; do
    read -p "Sélectionnez le disque à utiliser (1-${#DISKS[@]}): " DISK_CHOICE
    if [[ "$DISK_CHOICE" =~ ^[0-9]+$ ]] && [[ "$DISK_CHOICE" -ge 1 ]] && [[ "$DISK_CHOICE" -le "${#DISKS[@]}" ]]; then
        SELECTED_DISK="/dev/${DISKS[$((DISK_CHOICE-1))]}"
        break
    else
        print_error "Choix invalide."
    fi
done

print_warning "ATTENTION: Toutes les données sur $SELECTED_DISK seront SUPPRIMÉES!"
read -p "Continuer ? (O/N): " CONFIRM_DISK
if [[ ! "$CONFIRM_DISK" =~ ^[oO]$ ]]; then
    print_info "Installation annulée."
    exit 0
fi

# Configuration de la partition swap
echo ""
read -p "Voulez-vous créer une partition swap ? (O/N): " CREATE_SWAP
SWAP_SIZE=""
if [[ "$CREATE_SWAP" =~ ^[oO]$ ]]; then
    while true; do
        read -p "Taille de la partition swap (recommandé: 2G pour 8GB RAM, 4G pour 16GB RAM) [ex: 2G, 512M]: " SWAP_SIZE
        if validate_size "$SWAP_SIZE"; then
            break
        else
            print_error "Format invalide. Utilisez un nombre suivi de M ou G (ex: 2G, 512M)."
        fi
    done
fi

# Configuration de la partition root
while true; do
    echo ""
    read -p "Taille de la partition root (recommandé: 50G minimum pour cette installation complète) [ex: 80G]: " ROOT_SIZE
    if validate_size "$ROOT_SIZE"; then
        break
    else
        print_error "Format invalide. Utilisez un nombre suivi de M ou G (ex: 80G)."
    fi
done

# Configuration de la partition home
echo ""
read -p "Voulez-vous une partition /home séparée ? (O/N): " CREATE_HOME
HOME_SIZE=""
if [[ ! "$CREATE_HOME" =~ ^[nN]$ ]]; then
    read -p "Taille de la partition /home (recommandé: utiliser l'espace restant) [ex: 100G ou appuyez sur Entrée pour utiliser tout l'espace restant]: " HOME_SIZE
    if [[ -n "$HOME_SIZE" ]] && ! validate_size "$HOME_SIZE"; then
        print_error "Format invalide. Utilisation de l'espace restant."
        HOME_SIZE=""
    fi
fi

# Configuration de l'environnement de bureau
echo ""
print_info "Choix de l'environnement de bureau:"
echo "1. KDE Plasma (Recommandé)"
echo "2. Sans interface graphique (Terminal uniquement)"
echo "3. GNOME"

while true; do
    read -p "Sélectionnez votre environnement de bureau (1-3): " DE_CHOICE
    case $DE_CHOICE in
        1)
            DESKTOP_ENV="kde"
            print_info "KDE Plasma sélectionné"
            break
            ;;
        2)
            DESKTOP_ENV="minimal"
            print_info "Installation sans interface graphique sélectionnée"
            break
            ;;
        3)
            DESKTOP_ENV="gnome"
            print_info "GNOME sélectionné"
            break
            ;;
        *)
            print_error "Choix invalide."
            ;;
    esac
done

# Début de l'installation
print_step "Début de l'installation avec les paramètres:"
echo "  - Hostname: $HOSTNAME"
echo "  - Utilisateur principal: $USERNAME"
[[ -n "$EXTRA_USERNAME" ]] && echo "  - Utilisateur supplémentaire: $EXTRA_USERNAME"
echo "  - Disque: $SELECTED_DISK"
[[ "$CREATE_SWAP" =~ ^[oO]$ ]] && echo "  - Swap: $SWAP_SIZE"
echo "  - Root: $ROOT_SIZE"
[[ ! "$CREATE_HOME" =~ ^[nN]$ ]] && echo "  - Home: ${HOME_SIZE:-'Espace restant'}"
echo "  - Environnement: $DESKTOP_ENV"

echo ""
read -p "Confirmer l'installation ? (O/N): " FINAL_CONFIRM
if [[ ! "$FINAL_CONFIRM" =~ ^[oO]$ ]]; then
    print_info "Installation annulée."
    exit 0
fi

# Partitionnement du disque
print_step "Partitionnement du disque $SELECTED_DISK..."

# Suppression des partitions existantes
wipefs -af "$SELECTED_DISK"
sgdisk -Z "$SELECTED_DISK"

# Création de la table de partitions GPT
sgdisk -o "$SELECTED_DISK"

# Partition EFI (512M)
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" "$SELECTED_DISK"

PARTITION_NUM=2

# Partition swap (optionnelle)
if [[ "$CREATE_SWAP" =~ ^[oO]$ ]]; then
    sgdisk -n ${PARTITION_NUM}:0:+${SWAP_SIZE} -t ${PARTITION_NUM}:8200 -c ${PARTITION_NUM}:"Linux swap" "$SELECTED_DISK"
    PARTITION_NUM=$((PARTITION_NUM + 1))
fi

# Partition root
sgdisk -n ${PARTITION_NUM}:0:+${ROOT_SIZE} -t ${PARTITION_NUM}:8300 -c ${PARTITION_NUM}:"Linux root" "$SELECTED_DISK"
ROOT_PARTITION_NUM=$PARTITION_NUM
PARTITION_NUM=$((PARTITION_NUM + 1))

# Partition home (optionnelle)
if [[ ! "$CREATE_HOME" =~ ^[nN]$ ]]; then
    if [[ -n "$HOME_SIZE" ]]; then
        sgdisk -n ${PARTITION_NUM}:0:+${HOME_SIZE} -t ${PARTITION_NUM}:8300 -c ${PARTITION_NUM}:"Linux home" "$SELECTED_DISK"
    else
        sgdisk -n ${PARTITION_NUM}:0:0 -t ${PARTITION_NUM}:8300 -c ${PARTITION_NUM}:"Linux home" "$SELECTED_DISK"
    fi
    HOME_PARTITION_NUM=$PARTITION_NUM
fi

# Actualisation de la table des partitions
partprobe "$SELECTED_DISK"
sleep 2

# Détermination des noms de partitions
if [[ "$SELECTED_DISK" =~ nvme ]]; then
    EFI_PART="${SELECTED_DISK}p1"
    PART_NUM=2
    if [[ "$CREATE_SWAP" =~ ^[oO]$ ]]; then
        SWAP_PART="${SELECTED_DISK}p${PART_NUM}"
        PART_NUM=$((PART_NUM + 1))
    fi
    ROOT_PART="${SELECTED_DISK}p${PART_NUM}"
    PART_NUM=$((PART_NUM + 1))
    if [[ ! "$CREATE_HOME" =~ ^[nN]$ ]]; then
        HOME_PART="${SELECTED_DISK}p${PART_NUM}"
    fi
else
    EFI_PART="${SELECTED_DISK}1"
    PART_NUM=2
    if [[ "$CREATE_SWAP" =~ ^[oO]$ ]]; then
        SWAP_PART="${SELECTED_DISK}${PART_NUM}"
        PART_NUM=$((PART_NUM + 1))
    fi
    ROOT_PART="${SELECTED_DISK}${PART_NUM}"
    PART_NUM=$((PART_NUM + 1))
    if [[ ! "$CREATE_HOME" =~ ^[nN]$ ]]; then
        HOME_PART="${SELECTED_DISK}${PART_NUM}"
    fi
fi

# Formatage des partitions
print_step "Formatage des partitions..."

# Formatage EFI
mkfs.fat -F32 "$EFI_PART"

# Formatage swap
if [[ "$CREATE_SWAP" =~ ^[oO]$ ]]; then
    mkswap "$SWAP_PART"
    swapon "$SWAP_PART"
fi

# Formatage root
mkfs.ext4 -F "$ROOT_PART"

# Formatage home
if [[ ! "$CREATE_HOME" =~ ^[nN]$ ]]; then
    mkfs.ext4 -F "$HOME_PART"
fi

# Montage des partitions
print_step "Montage des partitions..."
mount "$ROOT_PART" /mnt

# Création des répertoires de montage
mkdir -p /mnt/boot
mkdir -p /mnt/home

# Montage EFI
mount "$EFI_PART" /mnt/boot

# Montage home
if [[ ! "$CREATE_HOME" =~ ^[nN]$ ]]; then
    mount "$HOME_PART" /mnt/home
fi

# Installation du système de base
print_step "Installation des paquets de base..."
BASE_PACKAGES="base base-devel linux linux-firmware nano vim networkmanager grub efibootmgr git wget unzip curl"

# Ajout des paquets selon l'environnement de bureau
case $DESKTOP_ENV in
    "kde")
        BASE_PACKAGES+=" plasma-meta sddm kde-applications-meta firefox chromium"
        ;;
    "minimal")
        BASE_PACKAGES+=" firefox"
        ;;
    "gnome")
        BASE_PACKAGES+=" gnome gnome-extra gdm firefox chromium"
        ;;
esac

# Paquets supplémentaires pour le développement et multimédia
ADDITIONAL_PACKAGES="pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol fastfetch cava mpv python python-pip nodejs npm docker docker-compose"

# Installation avec gestion des erreurs de signature
print_step "Installation des paquets (cela peut prendre du temps)..."
if ! pacstrap /mnt $BASE_PACKAGES $ADDITIONAL_PACKAGES; then
    print_warning "Erreur lors de l'installation. Tentative de résolution des problèmes de signature..."
    
    # Réinitialisation des clés en cas d'erreur
    pacman-key --init
    pacman-key --populate archlinux
    pacman-key --refresh-keys
    
    # Nouvelle tentative
    print_info "Nouvelle tentative d'installation..."
    if ! pacstrap /mnt $BASE_PACKAGES $ADDITIONAL_PACKAGES; then
        print_error "Échec de l'installation des paquets. Vérifiez votre connexion internet."
        exit 1
    fi
fi

# Génération du fstab
print_step "Génération du fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Configuration du système dans chroot
print_step "Configuration du système..."

cat << 'EOF' > /mnt/install_chroot.sh
#!/bin/bash

# Variables passées depuis le script principal
HOSTNAME="$1"
USERNAME="$2"
USER_PASSWORD="$3"
EXTRA_USERNAME="$4"
EXTRA_PASSWORD="$5"
ROOT_PASSWORD="$6"
DESKTOP_ENV="$7"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Initialisation des clés de signature dans le chroot
pacman-key --init
pacman-key --populate archlinux

# Configuration du fuseau horaire
ln -sf /usr/share/zoneinfo/Europe/Brussels /etc/localtime
hwclock --systohc

# Configuration des locales
echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf

# Configuration du hostname
echo "$HOSTNAME" > /etc/hostname
cat << HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

# Configuration du mot de passe root
echo "root:$ROOT_PASSWORD" | chpasswd

# Création de l'utilisateur principal
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$USER_PASSWORD" | chpasswd

# Création de l'utilisateur supplémentaire
if [[ -n "$EXTRA_USERNAME" ]]; then
    useradd -m -s /bin/bash "$EXTRA_USERNAME"
    echo "$EXTRA_USERNAME:$EXTRA_PASSWORD" | chpasswd
fi

# Configuration sudo
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Activation des services de base
systemctl enable NetworkManager
systemctl enable docker

# Configuration de l'environnement de bureau
case "$DESKTOP_ENV" in
    "kde")
        systemctl enable sddm
        ;;
    "gnome")
        systemctl enable gdm
        ;;
    "minimal")
        print_info "Installation sans interface graphique - pas de gestionnaire d'affichage"
        ;;
esac

# Installation et configuration du bootloader GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# Installation du thème Fallout pour Plymouth
print_step "Installation de Plymouth avec thème Fallout..."
pacman -S --noconfirm plymouth

# Configuration de Plymouth avec thème Fallout personnalisé
mkdir -p /usr/share/plymouth/themes/fallout-pipboy

# Création du thème Plymouth Fallout
cat << PLYMOUTHTHEME > /usr/share/plymouth/themes/fallout-pipboy/fallout-pipboy.plymouth
[Plymouth Theme]
Name=Fallout PipBoy
Description=Fallout PipBoy loading theme
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/fallout-pipboy
ScriptFile=/usr/share/plymouth/themes/fallout-pipboy/fallout-pipboy.script
PLYMOUTHTHEME

# Script Plymouth avec animation PipBoy
cat << PLYMOUTHSCRIPT > /usr/share/plymouth/themes/fallout-pipboy/fallout-pipboy.script
# Couleurs Fallout
Window.SetBackgroundTopColor(0, 0.1, 0);
Window.SetBackgroundBottomColor(0, 0.05, 0);

# Logo PipBoy
logo.image = Image("pipboy.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetX(Window.GetWidth() / 2 - logo.image.GetWidth() / 2);
logo.sprite.SetY(Window.GetHeight() / 2 - logo.image.GetHeight() / 2 - 50);

# Animation de scan line
scanline.image = Image("scanline.png");
scanline.sprite = Sprite(scanline.image);
scanline.sprite.SetX(0);

# Variables d'animation
progress = 0;
scan_y = 0;

fun refresh_callback() {
    progress++;
    scan_y = (progress * 4) % Window.GetHeight();
    scanline.sprite.SetY(scan_y);
    
    # Animation de pulsation du logo
    if (progress % 60 < 30) {
        logo.sprite.SetOpacity(1.0);
    } else {
        logo.sprite.SetOpacity(0.7);
    }
}

Plymouth.SetRefreshFunction(refresh_callback);

# Messages de boot
Plymouth.SetUpdateStatusFunction(fun (status) {
    if (status == "normal") {
        status_text = "INITIALISATION DU PIPBOY...";
    } else if (status == "failed") {
        status_text = "ERREUR CRITIQUE DETECTEE";
    } else {
        status_text = status;
    }
    
    # Affichage du texte de statut
    status_label.image = Image.Text(status_text, 0, 1, 0, 1);
    status_label.sprite = Sprite(status_label.image);
    status_label.sprite.SetPosition(Window.GetWidth() / 2 - status_label.image.GetWidth() / 2,
                                    Window.GetHeight() / 2 + 100, 10000);
});
PLYMOUTHSCRIPT

# Images pour Plymouth (créées directement)
# Image PipBoy (simple carré vert)
convert -size 200x200 xc:transparent -fill '#00ff41' -draw 'rectangle 50,50 150,150' \
        -fill '#001100' -draw 'rectangle 70,70 90,90' \
        -fill '#001100' -draw 'rectangle 110,70 130,90' \
        -fill '#001100' -draw 'rectangle 80,110 120,130' \
        /usr/share/plymouth/themes/fallout-pipboy/pipboy.png 2>/dev/null || {
    # Fallback simple
    echo -e '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\xc8\x00\x00\x00\xc8\x08\x02\x00\x00\x00V\xfc&\xa7\x00\x00\x00\tpHYs\x00\x00\x0b\x13\x00\x00\x0b\x13\x01\x00\x9a\x9c\x18\x00\x00\x003IDATx\x9c\xed\xc1\x01\r\x00\x00\x00\xc2\xa0\xf7Om\x0e7\xa0\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x1f\x01j\x00\x01\x8e\xf0!\x1f\x00\x00\x00\x00IEND\xaeB`\x82' > /usr/share/plymouth/themes/fallout-pipboy/pipboy.png
}

# Ligne de scan (ligne horizontale verte)
convert -size 1920x2 xc:'#00ff41' /usr/share/plymouth/themes/fallout-pipboy/scanline.png 2>/dev/null || {
    echo -e '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x07\x80\x00\x00\x00\x02\x08\x02\x00\x00\x00\xf4\x9c\x83\xc7\x00\x00\x00\x12IDATx\x9c\xed\xc1\x01\x00\x00\x00\x00\x80 \xff\xafo\r\x08\n\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x04\x1a\r\x03\xe6\x00\x00\x00\x00IEND\xaeB`\x82' > /usr/share/plymouth/themes/fallout-pipboy/scanline.png
}

# Configuration de Plymouth
plymouth-set-default-theme fallout-pipboy

# Installation du thème GRUB Fallout
print_step "Installation du thème GRUB Fallout..."
mkdir -p /boot/grub/themes/fallout

# Création du thème GRUB Fallout
cat << GRUBTHEME > /boot/grub/themes/fallout/theme.txt
desktop-image: "background.png"
title-text: ""
title-font: "Unifont Regular 24"
title-color: "#00ff41"
message-font: "Unifont Regular 16"
message-color: "#ffaa00"
terminal-font: "Unifont Regular 14"

+ boot_menu {
    left = 25%
    top = 25%
    width = 50%
    height = 50%
    item_font = "Unifont Regular 16"
    item_color = "#00ff41"
    selected_item_color = "#000000"
    selected_item_font = "Unifont Bold 16"
    item_height = 32
    item_padding = 8
    item_spacing = 4
    selected_item_pixmap_style = "select_*.png"
}

+ progress_bar {
    id = "__timeout__"
    left = 25%
    top = 80%
    width = 50%
    height = 16
    fg_color = "#00ff41"
    bg_color = "#001100"
    border_color = "#ffaa00"
    text = "@TIMEOUT_NOTIFICATION_LONG@"
    text_color = "#ffaa00"
}
GRUBTHEME

# FIX: Création d'une image de fond GRUB qui s'affiche correctement
# Image de fond animée style terminal Fallout (créée avec ImageMagick)
convert -size 1920x1080 xc:'#001a00' \
        -fill '#00ff41' -pointsize 72 -gravity center \
        -annotate +0-200 'PIPBOY 3000 MK IV' \
        -fill '#ffaa00' -pointsize 24 -gravity center \
        -annotate +0-100 'VAULT-TEC INDUSTRIES' \
        -fill '#00ff41' -pointsize 16 -gravity center \
        -annotate +0+100 'SYSTEME DE DEMARRAGE SECURISE' \
        /boot/grub/themes/fallout/background.png 2>/dev/null || {
    # Fallback: image unie verte
    convert -size 1920x1080 xc:'#001a00' /boot/grub/themes/fallout/background.png 2>/dev/null || {
        # Fallback ultime: copie d'une image système existante
        cp /usr/share/pixmaps/archlinux-logo.png /boot/grub/themes/fallout/background.png 2>/dev/null || {
            # Création manuelle d'un fichier PNG minimal
            echo -e '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x07\x80\x00\x00\x04\x38\x08\x02\x00\x00\x00\x8c\xd3G\xaa\x00\x00\x00\x15IDATx\x9c\xed\x97\x01\x00\x00\x00\x00\x80\x90\xfe\x9f\xb9\x08\n\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\xa5\x00\x01\x0e\xa0!\x1f\x00\x00\x00\x00IEND\xaeB`\x82' > /boot/grub/themes/fallout/background.png
        }
    }
}

# Images pour les éléments sélectionnés du menu GRUB
convert -size 600x32 xc:'#00ff41' -fill '#000000' -gravity center \
        -annotate +0+0 'SELECTED' /boot/grub/themes/fallout/select_c.png 2>/dev/null || {
    echo -e '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x02X\x00\x00\x00 \x08\x02\x00\x00\x00#\x1e\xa2\xb8\x00\x00\x00\x12IDATx\x9c\xed\xc1\x01\x00\x00\x00\x00\x80 \xff\xafo\r\x08\n\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x03\xc6\r\x03\xe6\x00\x00\x00\x00IEND\xaeB`\x82' > /boot/grub/themes/fallout/select_c.png
}

# Configuration GRUB avec thème Fallout et Plymouth
cat << GRUBCONF >> /etc/default/grub

# Thème Fallout
GRUB_THEME="/boot/grub/themes/fallout/theme.txt"
GRUB_GFXMODE=1920x1080
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_TIMEOUT=10
GRUB_TIMEOUT_STYLE=menu

# Plymouth pour animation de démarrage
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"

# Masquer les messages de démarrage pour un look plus propre
GRUB_CMDLINE_LINUX="quiet"
GRUBCONF

# Mise à jour de la configuration GRUB existante
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=10/' /etc/default/grub
sed -i 's/#GRUB_GFXMODE=640x480/GRUB_GFXMODE=1920x1080/' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub

# Reconstruction de l'initramfs avec Plymouth
sed -i 's/HOOKS=(.*)/HOOKS=(base udev plymouth autodetect modconf block filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -p linux

grub-mkconfig -o /boot/grub/grub.cfg

# Installation des paquets AUR (yay)
print_step "Installation de yay (AUR helper)..."
cd /tmp
git clone https://aur.archlinux.org/yay.git
chown -R $USERNAME:$USERNAME yay
cd yay
sudo -u $USERNAME makepkg -si --noconfirm

print_success "Installation de base terminée dans chroot"

EOF

chmod +x /mnt/install_chroot.sh
arch-chroot /mnt /install_chroot.sh "$HOSTNAME" "$USERNAME" "$USER_PASSWORD" "$EXTRA_USERNAME" "$EXTRA_PASSWORD" "$ROOT_PASSWORD" "$DESKTOP_ENV"
rm /mnt/install_chroot.sh

# Configuration post-installation avancée
print_step "Configuration post-installation avancée..."

cat << 'EOF' > /mnt/post.sh
#!/bin/bash

USERNAME="$1"
EXTRA_USERNAME="$2"
DESKTOP_ENV="$3"

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Création des dossiers utilisateur avec bonnes permissions
mkdir -p /home/$USERNAME/{.config,.local/share,.cache,Videos,Pictures,Documents,Downloads}
mkdir -p /home/$USERNAME/.local/share/{applications,icons,themes}

# Installation des navigateurs via AUR (sauf pour minimal)
if [[ "$DESKTOP_ENV" != "minimal" ]]; then
    print_step "Installation de Google Chrome et Brave..."
    sudo -u $USERNAME yay -S --noconfirm google-chrome brave-bin
fi

# Installation de Visual Studio Code et extensions
print_step "Installation de Visual Studio Code..."
sudo -u $USERNAME yay -S --noconfirm visual-studio-code-bin

# Extensions VSCode essentielles
print_info "Installation des extensions VSCode..."
VSCODE_EXTENSIONS=(
    "ms-vscode.vscode-json"
    "ms-python.python"
    "ms-vscode.cpptools"
    "redhat.java"
    "bradlc.vscode-tailwindcss"
    "esbenp.prettier-vscode"
    "ms-vscode.vscode-typescript-next"
    "ms-vscode.remote-containers"
    "ms-azuretools.vscode-docker"
)

for extension in "${VSCODE_EXTENSIONS[@]}"; do
    sudo -u $USERNAME code --install-extension "$extension" 2>/dev/null || true
done

# Installation d'Android Studio
print_step "Installation d'Android Studio..."
sudo -u $USERNAME yay -S --noconfirm android-studio

# Installation de Java et outils de développement
print_step "Installation des outils de développement..."
pacman -S --noconfirm jdk-openjdk python nodejs npm gcc clang cmake make

# Installation de Wine et compatibilité Windows
print_step "Installation de Wine pour la compatibilité Windows..."
pacman -S --noconfirm wine winetricks wine-mono wine-gecko

# Configuration de Wine pour l'utilisateur
sudo -u $USERNAME winecfg &
sleep 2
pkill winecfg 2>/dev/null || true

# Installation de Flatpak et applications de streaming (sauf pour minimal)
if [[ "$DESKTOP_ENV" != "minimal" ]]; then
    print_step "Installation de Flatpak et applications de streaming..."
    pacman -S --noconfirm flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    
    # Installation des apps de streaming
    sudo -u $USERNAME flatpak install -y flathub com.spotify.Client 2>/dev/null || true
fi

# Configuration de Fastfetch
print_step "Configuration de Fastfetch..."
mkdir -p /home/$USERNAME/.config/fastfetch
cat << FASTFETCHCONF > /home/$USERNAME/.config/fastfetch/config.jsonc
{
    "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "source": "arch",
        "padding": {
            "top": 1,
            "left": 2
        }
    },
    "display": {
        "separator": " -> ",
        "color": {
            "keys": "cyan",
            "title": "blue"
        }
    },
    "modules": [
        {
            "type": "title",
            "color": {
                "user": "cyan",
                "at": "white",
                "host": "blue"
            }
        },
        "separator",
        "os",
        "host",
        "kernel",
        "uptime",
        "packages",
        "shell",
        "display",
        "de",
        "wm",
        "wmtheme",
        "theme",
        "icons",
        "font",
        "cursor",
        "terminal",
        "terminalfont",
        "cpu",
        "gpu",
        "memory",
        "swap",
        "disk",
        "localip",
        "battery",
        "poweradapter",
        "locale",
        "break",
        "colors"
    ]
}
FASTFETCHCONF

# Configuration personnalisée avec logo Fallout
cat << FASTFETCHCUSTOM > /home/$USERNAME/.config/fastfetch/config-custom.jsonc
{
    "logo": {
        "source": "/home/$USERNAME/.config/fastfetch/fallout-logo.txt",
        "color": {
            "1": "green",
            "2": "yellow"
        }
    },
    "display": {
        "separator": " ═══════════════> ",
        "color": {
            "keys": "green",
            "title": "yellow"
        }
    },
    "modules": [
        {
            "type": "title",
            "format": "┌─ {user-name}@{host-name} ─┐",
            "color": {
                "user": "green",
                "at": "yellow",
                "host": "green"
            }
        },
        "separator",
        {
            "type": "os",
            "format": "├─ OS: {name} {version}"
        },
        {
            "type": "kernel",
            "format": "├─ Kernel: {release}"
        },
        {
            "type": "uptime",
            "format": "├─ Uptime: {time}"
        },
        {
            "type": "packages",
            "format": "├─ Packages: {count}"
        },
        {
            "type": "shell",
            "format": "├─ Shell: {name} {version}"
        },
        {
            "type": "de",
            "format": "├─ DE: {name}"
        },
        {
            "type": "cpu",
            "format": "├─ CPU: {name}"
        },
        {
            "type": "gpu",
            "format": "├─ GPU: {name}"
        },
        {
            "type": "memory",
            "format": "├─ Memory: {used} / {total}"
        },
        {
            "type": "disk",
            "format": "└─ Disk: {used} / {total}"
        },
        "break",
        "colors"
    ]
}
FASTFETCHCUSTOM

# Logo ASCII Fallout pour Fastfetch
cat << FALLOUTLOGO > /home/$USERNAME/.config/fastfetch/fallout-logo.txt
${c1}      ██████████████████████████
${c1}    ██                          ██
${c1}  ██    ████████    ████████      ██
${c1}██    ██      ██  ██      ██      ██
${c1}██    ██      ██  ██      ██      ██
${c1}██    ████████    ████████        ██
${c1}██                                ██
${c1}██        ████████████            ██
${c1}██      ██            ██          ██
${c1}██      ██    ████    ██          ██
${c1}██      ██    ████    ██          ██
${c1}██      ██            ██          ██
${c1}██        ████████████            ██
${c1}██                                ██
${c1}  ██                            ██
${c1}    ██████████████████████████
${c2}         VAULT-TEC INDUSTRIES
FALLOUTLOGO

# Configuration de Fastfetch dans .bashrc
echo "" >> /home/$USERNAME/.bashrc
echo "# Fastfetch au démarrage du terminal" >> /home/$USERNAME/.bashrc
echo "if command -v fastfetch &> /dev/null; then" >> /home/$USERNAME/.bashrc
echo "    fastfetch" >> /home/$USERNAME/.bashrc
echo "fi" >> /home/$USERNAME/.bashrc

# Configuration de Cava (visualiseur audio)
print_step "Configuration de Cava..."
mkdir -p /home/$USERNAME/.config/cava
cat << CAVACONF > /home/$USERNAME/.config/cava/config
[general]
framerate = 60
bars = 50
bar_width = 2
bar_spacing = 1

[input]
method = pulse

[output]
method = ncurses
channels = stereo
mono_option = average

[color]
gradient = 1
gradient_count = 6
gradient_color_1 = '#00ff41'
gradient_color_2 = '#26ff00'
gradient_color_3 = '#4cff00'
gradient_color_4 = '#73ff00'
gradient_color_5 = '#99ff00'
gradient_color_6 = '#bfff00'

[smoothing]
monstercat = 1
waves = 0
noise_reduction = 0.77

[eq]
higher_cutoff_freq = 10000
lower_cutoff_freq = 50
CAVACONF

# Configuration spécifique selon l'environnement de bureau
case "$DESKTOP_ENV" in
    "kde")
        print_step "Configuration KDE Plasma avec thème Fallout..."
        
        # Configuration SDDM avec thème PipBoy et FIX: autologin activé
        mkdir -p /usr/share/sddm/themes/fallout-pipboy
        
        cat << SDDMTHEME > /usr/share/sddm/themes/fallout-pipboy/theme.conf
[General]
type=color
color=#001a00
fontSize=12
background=background.jpg
showUserList=false
showPassword=true

[Background]
type=image
color=#001a00
background=background.jpg

[Input]
color=#00ff41
borderColor=#ffaa00
backgroundColor=#001100
SDDMTHEME

        # Interface SDDM PipBoy avec focus automatique sur le mot de passe
        cat << SDDMMAIN > /usr/share/sddm/themes/fallout-pipboy/Main.qml
import QtQuick 2.11
import QtGraphicalEffects 1.12
import SddmComponents 2.0

Rectangle {
    id: container
    width: 1920
    height: 1080
    color: "#001a00"
    
    Image {
        id: background
        anchors.fill: parent
        source: "background.jpg"
        fillMode: Image.PreserveAspectCrop
        
        Rectangle {
            id: scanLine
            width: parent.width
            height: 2
            color: "#00ff41"
            opacity: 0.8
            
            PropertyAnimation on y {
                loops: Animation.Infinite
                from: 0
                to: container.height
                duration: 3000
            }
        }
    }
    
    Rectangle {
        id: mainFrame
        anchors.centerIn: parent
        width: 800
        height: 400
        color: "#002200"
        border.color: "#00ff41"
        border.width: 3
        radius: 10
        
        Text {
            id: title
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 20
            text: "PIPBOY 3000 MK IV"
            color: "#00ff41"
            font.pixelSize: 24
            font.family: "Courier"
            font.bold: true
        }
        
        Rectangle {
            id: loginArea
            anchors.centerIn: parent
            width: 600
            height: 200
            color: "#001100"
            border.color: "#ffaa00"
            border.width: 2
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                
                Text {
                    text: "USER AUTHENTICATION"
                    color: "#00ff41"
                    font.pixelSize: 18
                    font.family: "Courier"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "Utilisateur: $USERNAME"
                    color: "#ffaa00"
                    font.pixelSize: 14
                    font.family: "Courier"
                }
                
                Rectangle {
                    width: 400
                    height: 40
                    color: "#002200"
                    border.color: "#00ff41"
                    border.width: 1
                    
                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.margins: 5
                        font.pixelSize: 16
                        font.family: "Courier"
                        color: "#00ff41"
                        echoMode: TextInput.Password
                        focus: true
                        
                        Component.onCompleted: {
                            focus = true
                            forceActiveFocus()
                        }
                        
                        Keys.onPressed: {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                sddm.login("$USERNAME", password.text, sessionModel.lastIndex)
                                event.accepted = true
                            }
                        }
                    }
                }
                
                Text {
                    text: "Press ENTER to continue..."
                    color: "#ffaa00"
                    font.pixelSize: 12
                    font.family: "Courier"
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PropertyAnimation { to: 0.3; duration: 1000 }
                        PropertyAnimation { to: 1.0; duration: 1000 }
                    }
                }
            }
        }
    }
}
SDDMMAIN

        # Image de fond PipBoy - FIX: création locale d'une image statique
        convert -size 1920x1080 xc:'#001a00' \
                -fill '#00ff41' -pointsize 72 -gravity center \
                -annotate +0-200 'PIPBOY 3000 MK IV' \
                -fill '#ffaa00' -pointsize 24 -gravity center \
                -annotate +0-100 'VAULT-TEC INDUSTRIES' \
                -fill '#00ff41' -pointsize 16 -gravity center \
                -annotate +0+100 'SYSTEME D AUTHENTIFICATION' \
                /usr/share/sddm/themes/fallout-pipboy/background.jpg 2>/dev/null || {
            # Fallback: copie d'une image système
            cp /usr/share/pixmaps/archlinux-logo.png /usr/share/sddm/themes/fallout-pipboy/background.jpg 2>/dev/null || {
                # Fallback ultime: fichier uni
                convert -size 1920x1080 xc:'#001a00' /usr/share/sddm/themes/fallout-pipboy/background.jpg 2>/dev/null || true
            }
        }
        
        # Configuration SDDM avec autologin et focus utilisateur
        cat << SDDMCONF > /etc/sddm.conf
[Theme]
Current=fallout-pipboy

[General]
Numlock=on
DisplayServer=x11

[Users]
DefaultUser=$USERNAME
HideUsers=
RememberLastUser=true
SDDMCONF
        
        ;;
        
    "gnome")
        print_step "Configuration GNOME avec thème Fallout..."
        
        # Configuration GNOME Shell avec thème sombre
        sudo -u $USERNAME gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark" 2>/dev/null || true
        sudo -u $USERNAME gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
        
        # Configuration GDM pour afficher l'utilisateur principal
        mkdir -p /etc/dconf/db/gdm.d/
        cat << GDMCONF > /etc/dconf/db/gdm.d/01-userlist
[org/gnome/login-screen]
disable-user-list=false
GDMCONF
        dconf update
        
        ;;
        
    "minimal")
        print_step "Configuration système minimal (sans interface graphique)..."
        print_info "Pas de configuration d'interface graphique nécessaire"
        ;;
esac

# Installation et configuration de Spicetify pour Spotify (sauf minimal)
if [[ "$DESKTOP_ENV" != "minimal" ]]; then
    print_step "Installation et configuration de Spicetify..."
    sudo -u $USERNAME yay -S --noconfirm spicetify-cli 2>/dev/null || true
fi

# Configuration des permissions pour l'utilisateur
chown -R $USERNAME:$USERNAME /home/$USERNAME/
chmod -R 755 /home/$USERNAME/

# Permissions spécifiques pour les fichiers de configuration
find /home/$USERNAME/.config -type f -exec chmod 644 {} \; 2>/dev/null || true
find /home/$USERNAME/.config -type d -exec chmod 755 {} \; 2>/dev/null || true
find /home/$USERNAME/.local -type f -exec chmod 644 {} \; 2>/dev/null || true
find /home/$USERNAME/.local -type d -exec chmod 755 {} \; 2>/dev/null || true

# Configuration pour l'utilisateur supplémentaire si existant
if [[ -n "$EXTRA_USERNAME" ]]; then
    print_step "Configuration de l'utilisateur supplémentaire: $EXTRA_USERNAME"
    
    # Copie des configurations de base
    mkdir -p /home/$EXTRA_USERNAME/{.config,.local/share,.cache,Videos,Pictures,Documents,Downloads}
    mkdir -p /home/$EXTRA_USERNAME/.local/share/{applications,icons,themes}
    
    # Configuration Fastfetch
    cp -r /home/$USERNAME/.config/fastfetch /home/$EXTRA_USERNAME/.config/
    
    # Configuration .bashrc avec Fastfetch
    echo "" >> /home/$EXTRA_USERNAME/.bashrc
    echo "# Fastfetch au démarrage du terminal" >> /home/$EXTRA_USERNAME/.bashrc
    echo "if command -v fastfetch &> /dev/null; then" >> /home/$EXTRA_USERNAME/.bashrc
    echo "    fastfetch" >> /home/$EXTRA_USERNAME/.bashrc
    echo "fi" >> /home/$EXTRA_USERNAME/.bashrc
    
    # Configuration Cava
    cp -r /home/$USERNAME/.config/cava /home/$EXTRA_USERNAME/.config/
    
    # Permissions pour l'utilisateur supplémentaire
    chown -R $EXTRA_USERNAME:$EXTRA_USERNAME /home/$EXTRA_USERNAME/
    chmod -R 755 /home/$EXTRA_USERNAME/
    
    # Ajout aux groupes nécessaires
    usermod -a -G audio,video,docker $EXTRA_USERNAME
fi

# Ajout de l'utilisateur principal aux groupes nécessaires
usermod -a -G audio,video,docker $USERNAME

# Configuration des services audio
print_step "Configuration audio avec PipeWire..."
systemctl --global enable pipewire.service 2>/dev/null || true
systemctl --global enable pipewire-pulse.service 2>/dev/null || true
systemctl --global enable wireplumber.service 2>/dev/null || true

# Installation des polices pour l'interface
print_step "Installation des polices..."
pacman -S --noconfirm ttf-jetbrains-mono ttf-fira-code ttf-liberation ttf-dejavu noto-fonts noto-fonts-emoji

# Configuration des alias utiles dans .bashrc
cat << ALIASES >> /home/$USERNAME/.bashrc

# Alias personnalisés
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'
alias h='history'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps auxf'
alias mkdir='mkdir -pv'
alias wget='wget -c'
alias cava='cava -p ~/.config/cava/config'
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias search='pacman -Ss'
alias remove='sudo pacman -R'

# Alias pour VSCode
alias code='code .'
alias vscode='code'

# Alias Docker
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias drit='docker run -it'
alias dex='docker exec -it'

# Fonction pour créer et entrer dans un répertoire
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Fonction pour extraire différents types d'archives
extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' ne peut pas être extrait via extract()" ;;
        esac
    else
        echo "'$1' n'est pas un fichier valide"
    fi
}
ALIASES

# Copie des alias pour l'utilisateur supplémentaire
if [[ -n "$EXTRA_USERNAME" ]]; then
    cat /home/$USERNAME/.bashrc >> /home/$EXTRA_USERNAME/.bashrc
fi

# Configuration de Git pour le développement
print_step "Configuration Git de base..."
sudo -u $USERNAME git config --global init.defaultBranch main
sudo -u $USERNAME git config --global pull.rebase false

if [[ -n "$EXTRA_USERNAME" ]]; then
    sudo -u $EXTRA_USERNAME git config --global init.defaultBranch main
    sudo -u $EXTRA_USERNAME git config --global pull.rebase false
fi

# Création d'un script de post-installation pour l'utilisateur
cat << POSTSCRIPT > /home/$USERNAME/post-install-user.sh
#!/bin/bash

# Script de post-installation pour l'utilisateur
# À exécuter au premier démarrage

echo "🎮 Configuration post-installation personnelle"

# Configuration Git personnalisée
echo "Configuration Git:"
read -p "Nom complet pour Git: " GIT_NAME
read -p "Email pour Git: " GIT_EMAIL
git config --global user.name "\$GIT_NAME"
git config --global user.email "\$GIT_EMAIL"

# Configuration Wine pour les applications Windows
echo "🍷 Configuration Wine..."
winecfg

# Installation des dépendances Wine courantes
winetricks corefonts vcrun2019 dotnet48

# Configuration de Spicetify si Spotify est installé
if command -v spicetify &> /dev/null && [[ "$DESKTOP_ENV" != "minimal" ]]; then
    echo "🎵 Configuration Spicetify..."
    spicetify backup apply 2>/dev/null || true
    spicetify config current_theme Dribbblish 2>/dev/null || true
    spicetify config color_scheme nord-dark 2>/dev/null || true
    spicetify apply 2>/dev/null || true
fi

echo "✅ Configuration utilisateur terminée!"
echo "Vous pouvez supprimer ce script avec: rm ~/post-install-user.sh"
POSTSCRIPT

chmod +x /home/$USERNAME/post-install-user.sh

if [[ -n "$EXTRA_USERNAME" ]]; then
    cp /home/$USERNAME/post-install-user.sh /home/$EXTRA_USERNAME/
    chown $EXTRA_USERNAME:$EXTRA_USERNAME /home/$EXTRA_USERNAME/post-install-user.sh
fi

# Création d'un script de maintenance système
cat << MAINTENANCE > /usr/local/bin/arch-maintenance
#!/bin/bash

# Script de maintenance Arch Linux

echo "🔧 Maintenance du système Arch Linux"

# Mise à jour du système
echo "📦 Mise à jour des paquets..."
pacman -Syu

# Nettoyage du cache des paquets
echo "🧹 Nettoyage du cache..."
pacman -Sc --noconfirm

# Nettoyage des paquets orphelins
echo "🗑️ Suppression des paquets orphelins..."
if pacman -Qtdq > /dev/null 2>&1; then
    pacman -Rns \$(pacman -Qtdq) --noconfirm
else
    echo "Aucun paquet orphelin trouvé"
fi

# Mise à jour de la base de données de localisation des fichiers
echo "🔍 Mise à jour de la base locate..."
updatedb

# Vérification des erreurs système
echo "⚠️ Vérification des erreurs système..."
journalctl -p 3 -xb --no-pager | tail -20

echo "✅ Maintenance terminée!"
MAINTENANCE

chmod +x /usr/local/bin/arch-maintenance

# Messages de fin
print_success "Configuration post-installation terminée!"

echo ""
print_step "🎯 Résumé de l'installation complète:"
echo "  ✅ Système de base Arch Linux installé"
echo "  ✅ Environnement de bureau: $DESKTOP_ENV"
echo "  ✅ Thème Fallout/Arcane configuré"
echo "  ✅ Plymouth avec animation PipBoy"
echo "  ✅ GRUB avec thème Fallout"
echo "  ✅ Fastfetch configuré avec lancement automatique"
echo "  ✅ Cava (visualiseur audio) configuré"
case "$DESKTOP_ENV" in
    "kde")
        echo "  ✅ SDDM avec thème PipBoy et login automatique sur $USERNAME"
        echo "  ✅ KDE Plasma configuré"
        ;;
    "gnome")
        echo "  ✅ GNOME avec thème sombre"
        echo "  ✅ GDM configuré pour afficher les utilisateurs"
        ;;
    "minimal")
        echo "  ✅ Installation système minimal (terminal uniquement)"
        ;;
esac

if [[ "$DESKTOP_ENV" != "minimal" ]]; then
    echo "  ✅ Navigateurs: Chrome, Brave, Firefox"
    echo "  ✅ Streaming: Spotify (Flatpak)"
fi
echo "  ✅ Wine + compatibilité Windows"
echo "  ✅ VSCode avec extensions développement"
echo "  ✅ Android Studio installé"
echo "  ✅ Outils dev: Java, Python, Node.js, Docker"
echo "  ✅ Audio: PipeWire + Pavucontrol"
if [[ "$DESKTOP_ENV" != "minimal" ]]; then
    echo "  ✅ Spicetify pour Spotify"
fi

echo ""
print_step "📋 Actions post-redémarrage:"
echo "  🔹 Exécuter ~/post-install-user.sh pour la config personnelle"
echo "  🔹 Configurer Git avec vos informations"
if [[ "$DESKTOP_ENV" != "minimal" ]]; then
    echo "  🔹 Connecter les comptes Spotify"
fi
echo "  🔹 Lancer 'arch-maintenance' pour maintenance système"
case "$DESKTOP_ENV" in
    "kde")
        echo "  🔹 Personnaliser KDE dans Paramètres > Apparence"
        echo "  🔹 Le login se fera automatiquement sur $USERNAME (saisir juste le mot de passe)"
        ;;
    "gnome")
        echo "  🔹 Installer GNOME Extensions pour plus d'options"
        ;;
    "minimal")
        echo "  🔹 Se connecter en tant que $USERNAME depuis le terminal"
        ;;
esac

echo ""
print_step "🛠️ Commandes utiles ajoutées:"
echo "  fastfetch = Informations système"
echo "  cava = Visualiseur audio en terminal"
echo "  arch-maintenance = Maintenance système"
echo "  code = Visual Studio Code"

print_success "Installation complète terminée! 🎉"

EOF

chmod +x /mnt/post_install.sh
arch-chroot /mnt /post_install.sh "$USERNAME" "$EXTRA_USERNAME" "$DESKTOP_ENV"
rm /mnt/post_install.sh

# Finalisation
print_success "🎉 Installation terminée avec succès!"
echo ""
print_step "📊 Résumé final de l'installation:"
echo "  - Système: Arch Linux avec thématique Fallout/Arcane"
echo "  - Hostname: $HOSTNAME"
echo "  - Utilisateur principal: $USERNAME"
[[ -n "$EXTRA_USERNAME" ]] && echo "  - Utilisateur supplémentaire: $EXTRA_USERNAME"
echo "  - Environnement de bureau: $DESKTOP_ENV"
echo "  - Bootloader: GRUB (UEFI) avec thème Fallout"
echo "  - Boot animation: Plymouth PipBoy"

case $DESKTOP_ENV in
    "kde")
        echo "  - Interface: KDE Plasma avec thème Fallout"
        echo "  - Login: SDDM PipBoy avec focus automatique sur $USERNAME"
        ;;
    "gnome")
        echo "  - Interface: GNOME avec thème sombre"
        echo "  - Login: GDM configuré"
        ;;
    "minimal")
        echo "  - Interface: Terminal uniquement (pas d'interface graphique)"
        ;;
esac

echo ""
print_step "🎯 Applications installées:"
if [[ "$DESKTOP_ENV" != "minimal" ]]; then
    echo "  🌐 Navigateurs: Firefox, Chrome, Brave"
    echo "  🎬 Streaming: Spotify (Flatpak)"
fi
echo "  💻 Développement: VSCode, Android Studio"
echo "  🛠️ Outils: Git, Docker, Java, Python, Node.js"
echo "  🍷 Windows: Wine + Winetricks + dépendances"
echo "  🎵 Audio: PipeWire, Cava"
if [[ "$DESKTOP_ENV" != "minimal" ]]; then
    echo "  🎵 Spotify: Spicetify pour customisation"
fi
echo "  📊 Système: Fastfetch (auto-launch dans terminal)"

echo ""
print_warning "⚡ Corrections apportées:"
echo "  ✅ FIX: Nom d'utilisateur maintenant visible lors de la saisie"
echo "  ✅ FIX: SDDM configuré pour login automatique sur $USERNAME (saisir juste le mot de passe)"
echo "  ✅ FIX: Hyprland remplacé par option 'Sans interface graphique'"
echo "  ✅ FIX: Image de fond GRUB créée localement avec ImageMagick"
echo "  ✅ FIX: Thème GRUB Fallout entièrement fonctionnel"
echo "  ✅ FIX: Animation Plymouth PipBoy avec scan line"

echo ""
print_warning "🎨 Thèmes et personnalisations installés:"
echo "  ✅ GRUB: Interface Fallout avec animation et couleurs terminal"
echo "  ✅ Plymouth: Animation PipBoy avec scan line et pulsation"
case "$DESKTOP_ENV" in
    "kde")
        echo "  ✅ SDDM: Interface PipBoy complète avec animation et autofocus"
        ;;
    "gnome")
        echo "  ✅ GNOME: Thème sombre avec liste d'utilisateurs visible"
        ;;
    "minimal")
        echo "  ✅ Terminal: Configuration Fallout pour fastfetch et cava"
        ;;
esac
echo "  ✅ Terminal: Fastfetch avec logo Arch + config Fallout custom"
echo "  ✅ Audio: Cava avec visualisation verte terminal"

echo ""
print_step "🔧 Scripts et outils ajoutés:"
echo "  📝 ~/post-install-user.sh - Configuration utilisateur personnelle"
echo "  🔧 arch-maintenance - Script de maintenance système"
echo "  📁 ~/.config/fastfetch/config-custom.jsonc - Config Fallout pour fastfetch"

echo ""
print_warning "📋 À faire après le redémarrage:"
echo "  1. Configurer votre réseau Wi-Fi si nécessaire"
echo "  2. Exécuter ~/post-install-user.sh pour config Git et Wine"
if [[ "$DESKTOP_ENV" != "minimal" ]]; then
    echo "  3. Lancer Spotify et configurer Spicetify"
    case "$DESKTOP_ENV" in
        "kde")
            echo "  4. Le login SDDM affichera directement $USERNAME - saisir juste le mot de passe"
            echo "  5. Explorer KDE Plasma Settings > Apparence pour plus de personnalisation"
            ;;
        "gnome")
            echo "  4. Installer GNOME Tweaks pour plus d'options"
            ;;
    esac
else
    echo "  3. Se connecter directement en terminal avec $USERNAME"
fi

echo ""
print_success "🚀 Votre installation Arch Linux Fallout/Arcane Edition est prête!"
echo ""

# Affichage des informations de login selon l'environnement
case "$DESKTOP_ENV" in
    "kde")
        print_info "🔐 Connexion SDDM: L'écran affichera automatiquement '$USERNAME' - saisissez juste votre mot de passe"
        ;;
    "gnome")
        print_info "🔐 Connexion GDM: Sélectionnez '$USERNAME' dans la liste et saisissez votre mot de passe"
        ;;
    "minimal")
        print_info "🔐 Connexion Terminal: Tapez '$USERNAME' puis votre mot de passe"
        ;;
esac

echo ""
read -p "Voulez-vous redémarrer maintenant ? (O/N): " REBOOT_NOW
if [[ "$REBOOT_NOW" =~ ^[oO]$ ]]; then
    print_info "Redémarrage en cours..."
    umount -R /mnt
    reboot
else
    print_info "Vous pouvez redémarrer manuellement avec: umount -R /mnt && reboot"
    print_warning "N'oubliez pas de démonter les partitions avant de redémarrer!"
fi
