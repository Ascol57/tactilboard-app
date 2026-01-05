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

# --- CONFIGURATION ---
APP_DIR="/home/$USER/tactilboard-app"
SPLASH_IMAGE="$APP_DIR/splash.png" # Assure-toi que ce fichier existe
export NODE_ENV=production

# 1. OPTIMISATIONS ÉCRAN ET SOURIS
# ---------------------------------------------------------
xset s off          # Désactive l'économiseur d'écran
xset s noblank      # Empêche l'écran de devenir noir
xset -dpms          # Désactive la gestion d'énergie (veille)
unclutter -idle 0 & # Cache le curseur de la souris immédiatement

# 2. AFFICHAGE DU SPLASH SCREEN
# ---------------------------------------------------------
# On affiche l'image immédiatement pour couvrir le chargement
if [ -f "$SPLASH_IMAGE" ]; then
    feh --bg-fill "$SPLASH_IMAGE" &
else
    # Si pas d'image, on met un fond noir pour faire propre
    hsetroot -solid "#000000" &
fi

# 3. VÉRIFICATION DES MISES À JOUR (INTELLIGENTE)
# ---------------------------------------------------------
cd "$APP_DIR"

# Attendre que le réseau soit prêt (max 15 secondes)
for i in {1..15}; do
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo "🌐 Réseau détecté. Vérification GitHub..."
        
        # Récupérer les infos du dépôt sans télécharger les fichiers
        git fetch origin main
        
        # Comparer la version locale et la version distante
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse @{u})

        if [ "$LOCAL" != "$REMOTE" ]; then
            echo "📥 Mise à jour trouvée. Téléchargement..."
            git pull origin main
            
            # On ne réinstalle et re-build que s'il y a du nouveau
            npm install
            npm run build
        else
            echo "✅ Déjà à jour."
        fi
        break
    fi
    echo "⏳ Attente réseau... ($i)"
    sleep 1
done

# 4. LANCEMENT DE L'APPLICATION ELECTRON
# ---------------------------------------------------------
echo "🚀 Lancement de TactilDeck..."

# On lance l'application. 
# Le flag --no-sandbox est souvent requis sur les architectures ARM (Raspberry Pi)
npm run electron -- --no-sandbox

# 5. NETTOYAGE (Optionnel)
# ---------------------------------------------------------
# Une fois l'application fermée (si on utilise le raccourci de secours)
pkill feh
openbox --exit
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