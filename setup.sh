#!/bin/bash

# --- CONFIGURATION ---
REPO_URL="REMPLACE_PAR_TON_URL_GITHUB"
APP_DIR="nom-de-ton-repo"
# ---------------------

echo "🚀 Début de l'installation du Kiosk..."

# 1. Mise à jour du système
sudo apt update && sudo apt upgrade -y

# 2. Installation des dépendances (X11, Openbox, Node.js)
echo "📦 Installation des paquets graphiques et Node.js..."
sudo apt install -y --no-install-recommends \
    xserver-xorg x11-xserver-utils xinit openbox \
    unclutter git curl lightdm

# Installation de Node.js (Version 20.x pour 2026)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 3. Clonage du dépôt et installation de l'app
echo "📂 Récupération de l'application..."
cd /home/$USER
git clone $REPO_URL
cd $APP_DIR
npm install

# 4. Configuration d'Openbox (Le gestionnaire de fenêtres)
echo "⚙️ Configuration de l'interface..."
mkdir -p ~/.config/openbox
cat <<EOF > ~/.config/openbox/autostart
# Désactiver la mise en veille et le curseur
xset s off
xset s noblank
xset -dpms
unclutter -idle 0 &

# Lancer l'app Electron (on force le mode sandbox-fix pour Linux)
cd /home/$USER/$APP_DIR
npm electron
EOF

# 5. Configuration du démarrage automatique (Auto-login)
echo "👤 Configuration de l'auto-login..."
sudo raspi-config nonint do_boot_behaviour B2 # B2 = Console Autologin

# 6. Lancement de X au démarrage via .bash_profile
cat <<EOF >> ~/.bash_profile
if [ -z "\$DISPLAY" ] && [ "\$XDG_VTNR" -eq 1 ]; then
  exec startx -- -nocursor
fi
EOF

echo "✅ Installation terminée ! Le Pi va redémarrer dans 5 secondes."
sleep 5
sudo reboot