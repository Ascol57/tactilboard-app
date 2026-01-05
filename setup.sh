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
#!/bin/bash

# 1. PARAMÈTRES ÉCRAN
xset s off
xset s noblank
xset -dpms
unclutter -idle 0 &

# 2. ON DÉFINIT LE CHEMIN EN DUR
# (Vérifie bien que ton dossier s'appelle exactement comme ça)
REAL_PATH="/home/constant/$APP_DIR"
export NODE_ENV=production

# 3. AFFICHAGE DU SPLASH (si présent)
if [ -f "$REAL_PATH/splash.png" ]; then
    feh --bg-fill "$REAL_PATH/splash.png" &
fi

# 4. ENTRER DANS LE DOSSIER
cd "$REAL_PATH" || exit

# 5. VÉRIFICATION RÉSEAU ET MAJ
for i in {1..10}; do
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo "🌐 Internet OK"
        git fetch origin main
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse @{u})
        if [ "$LOCAL" != "$REMOTE" ]; then
            git pull origin main
            npm install
            npm run build
        fi
        break
    fi
    sleep 1
done

# 6. LANCEMENT SÉCURISÉ
echo "🚀 Lancement de TactilDeck..."

# On s'assure que le dossier dist existe avant de lancer
if [ ! -d "dist" ]; then
    npm run build
fi

# Boucle pour relancer l'app si elle crash
while true; do
    /usr/bin/npm run electron -- --no-sandbox
    echo "App fermée, relance dans 5s..."
    sleep 5
done
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