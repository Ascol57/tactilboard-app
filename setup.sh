#!/bin/bash

# --- CONFIGURATION ---
REPO_URL="https://github.com/Ascol57/tactilboard-app"
APP_DIR="tactilboard-app"
# ---------------------

echo "🚀 Initialisation du Kiosk TactilDeck..."

# 1. Mise à jour système
sudo apt update && sudo apt upgrade -y

# 2. Dépendances (X11, Openbox, Node.js)
sudo apt install -y --no-install-recommends \
    xserver-xorg x11-xserver-utils xinit openbox \
    unclutter git curl lightdm

# Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 3. Installation de l'app
cd /home/$USER
git clone $REPO_URL
cd $APP_DIR
npm install
npm run build # Premier build pour être prêt

# 4. Config Openbox avec mise à jour intelligente
mkdir -p ~/.config/openbox
cat <<EOF > ~/.config/openbox/autostart
# Optimisations écran
xset s off
xset s noblank
xset -dpms
unclutter -idle 0 &

cd /home/$USER/$APP_DIR

# --- MISE À JOUR AU BOOT ---
# Attendre que le réseau soit là (max 20s) pour le git pull
for i in {1..20}; do
  if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "Réseau OK, mise à jour..."
    git pull origin main
    npm install # Au cas où tu as ajouté des dépendances
    npm run build # Re-génère le dossier /dist
    break
  fi
  sleep 1
done

# Lancer l'app Electron en mode production
export NODE_ENV=production
npm run electron -- --no-sandbox
EOF

# 5. Auto-login console
sudo raspi-config nonint do_boot_behaviour B2 

# 6. Lancement auto de X
if ! grep -q "startx" ~/.bash_profile; then
cat <<EOF >> ~/.bash_profile
if [ -z "\$DISPLAY" ] && [ "\$XDG_VTNR" -eq 1 ]; then
  exec startx -- -nocursor
fi
EOF
fi

echo "✅ Setup terminé. Reboot..."
sleep 2
sudo reboot