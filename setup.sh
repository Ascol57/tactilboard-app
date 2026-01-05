#!/bin/bash
# curl -sSL https://raw.githubusercontent.com/Ascol57/tactilboard-app/master/setup.sh | bash
# --- CONFIGURATION ---
REPO_URL="https://github.com/Ascol57/tactilboard-app"
APP_DIR_NAME="tactilboard-app"
APP_DIR="/home/$USER/$APP_DIR_NAME"
# ---------------------

echo "🚀 Déploiement du Kiosk TactilDeck (Boot + Splash + App)..."

# 1. MISE À JOUR ET DÉPENDANCES
# ---------------------------------------------------------
sudo apt update && sudo apt upgrade -y
sudo apt install -y --no-install-recommends \
    xserver-xorg x11-xserver-utils xinit openbox \
    unclutter git curl lightdm feh \
    plymouth plymouth-themes initramfs-tools

# Installation Node.js 20
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# 2. INSTALLATION DE L'APPLICATION
# ---------------------------------------------------------
cd /home/$USER
if [ ! -d "$APP_DIR" ]; then
    git clone $REPO_URL
fi
cd "$APP_DIR"
npm install
npm run build

# 3. CONFIGURATION DU THÈME DE BOOT (PLYMOUTH)
# ---------------------------------------------------------
echo "🎨 Configuration du thème de boot..."

sudo mkdir -p /usr/share/plymouth/themes/tactilboard
sudo cp -r $APP_DIR/plymouth/* /usr/share/plymouth/themes/tactilboard/

# Forcer le chargement des pilotes vidéo au démarrage (très important pour Plymouth)
if ! grep -q "vc4" /etc/initramfs-tools/modules; then
    echo -e "vc4\ndrm" | sudo tee -a /etc/initramfs-tools/modules
fi

# Configurer cmdline.txt pour cacher le texte (quiet splash)
# On nettoie la ligne pour éviter les doublons
sudo sed -i 's/console=tty1//g' /boot/firmware/cmdline.txt
CUR_CMD=$(cat /boot/firmware/cmdline.txt)
echo "$CUR_CMD quiet splash plymouth.ignore-serial-consoles logo.nologo vt.global_cursor_default=0 console=tty3" | sudo tee /boot/firmware/cmdline.txt

# Régénérer l'image de boot (prend du temps)
sudo plymouth-set-default-theme tactilboard
sudo update-initramfs -u

# 4. CONFIGURATION DE L'AUTOSTART (OPENBOX + FEH)
# ---------------------------------------------------------
echo "⚙️ Configuration de l'autostart..."
mkdir -p ~/.config/openbox
cat <<EOF > ~/.config/openbox/autostart
#!/bin/bash
# 1. Affichage immédiat du Splash FEH pour la transition
feh --bg-fill "$APP_DIR/splash.png" &

# 2. Paramètres écran
xset s off -dpms
xset s noblank
unclutter -idle 0 &

# 3. Update intelligent
cd "$APP_DIR"
if ping -c 1 8.8.8.8 &> /dev/null; then
    git fetch origin main
    LOCAL=\$(git rev-parse HEAD)
    REMOTE=\$(git rev-parse @{u})
    if [ "\$LOCAL" != "\$REMOTE" ]; then
        git pull origin main
        npm install
        npm run build
    fi
fi

# 4. Lancement App
export NODE_ENV=production
npm run electron -- --no-sandbox
EOF
chmod +x ~/.config/openbox/autostart

# 5. CONFIGURATION DU .BASH_PROFILE ET AUTO-LOGIN
# ---------------------------------------------------------
echo "👤 Configuration du login et de X11..."

# On s'assure que .bash_profile lance startx proprement
cat <<EOF > ~/.bash_profile
# Lancement automatique de l'interface graphique sur TTY1
if [ -z "\$DISPLAY" ] && [ "\$XDG_VTNR" -eq 1 ]; then
  exec startx -- -nocursor
fi
EOF

# Désactiver le message de bienvenue (IP address, etc.) pour un boot propre
touch ~/.hushlogin

# Activer l'Auto-login console via raspi-config
sudo raspi-config nonint do_boot_behaviour B2

echo "✅ Tout est prêt ! Redémarrage pour appliquer le thème..."
sleep 3
sudo reboot