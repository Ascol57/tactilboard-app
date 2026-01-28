#!/bin/bash
# curl -sSL https://raw.githubusercontent.com/Ascol57/tactilboard-app/master/setup.sh | bash
# --- CONFIGURATION ---
REPO_URL="https://github.com/Ascol57/tactilboard-app"
APP_DIR_NAME="tactilboard-app"
APP_DIR="/home/$USER/$APP_DIR_NAME"

echo "🚀 Déploiement du Kiosk TactilDeck..."

# 1. MISE À JOUR ET DÉPENDANCES
sudo apt update && sudo apt upgrade -y
sudo apt install -y --no-install-recommends \
    xserver-xorg x11-xserver-utils xinit openbox \
    unclutter git curl feh \
    libnss3 libgtk-3-0 libasound2 libgbm1

# Installation Node.js 20
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# 2. INSTALLATION DE L'APPLICATION
cd /home/$USER
if [ ! -d "$APP_DIR" ]; then
    git clone $REPO_URL
fi
cd "$APP_DIR"
npm install
npm run build # On build ici, pendant le setup, pour que ce soit prêt au premier boot


# 4. DROITS SUDO POUR L'AUTOSTART
echo "🔓 Autorisation sudo pour les updates en arrière-plan..."
echo "$USER ALL=(ALL) NOPASSWD: /usr/sbin/update-initramfs, /usr/bin/cp" | sudo tee /etc/sudoers.d/kiosk-updates

# 5. CONFIGURATION AUTOSTART (Optimisé pour l'alimentation)
mkdir -p ~/.config/openbox
cat <<EOF > ~/.config/openbox/autostart
#!/bin/bash
APP_DIR="/home/\$USER/tactilboard-app"
exec > >(tee -a ~/kiosk.log) 2>&1

# Splash feh pour la transition
feh --bg-fill "\$APP_DIR/splash.png" &
xset s off -dpms
xset s noblank
unclutter -idle 0 &

# LANCEMENT APP IMMÉDIAT
echo "🚀 Lancement Electron..."
export NODE_ENV=production
cd "\$APP_DIR"
./node_modules/.bin/electron . --no-sandbox & 

# UPDATE DÉCALÉ (On attend 60s pour laisser le Pi se calmer après le boot)
(
    sleep 60
    if ping -c 1 8.8.8.8 &> /dev/null; then
        git remote update > /dev/null
        LOCAL=\$(git rev-parse HEAD)
        REMOTE=\$(git rev-parse origin/main)

        if [ "\$LOCAL" != "\$REMOTE" ]; then
            echo "📥 Mise à jour trouvée..."
            git pull origin main
            npm install
            npm run build
        fi
    fi
) &
EOF
chmod +x ~/.config/openbox/autostart

# 6. CONFIGURATION LOGIN ET X11
cat <<EOF > ~/.bash_profile
if [ -z "\$DISPLAY" ] && [ "\$XDG_VTNR" -eq 1 ]; then
  exec startx -- -nocursor
fi
EOF

touch ~/.hushlogin
sudo raspi-config nonint do_boot_behaviour B2

echo "✅ Setup terminé. Le Pi va rebooter dans 5 secondes."
sleep 5
sudo reboot