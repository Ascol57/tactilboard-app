#!/bin/bash
# --- CONFIGURATION ---
REPO_URL="https://github.com/Ascol57/tactilboard-app"
APP_DIR_NAME="tactilboard-app"
APP_DIR="/home/$USER/$APP_DIR_NAME"
# ---------------------

echo "🚀 Déploiement du Kiosk TactilDeck..."

# 1. DÉPENDANCES ET SYSTÈME
sudo apt update && sudo apt upgrade -y
sudo apt install -y --no-install-recommends \
    xserver-xorg x11-xserver-utils xinit openbox \
    unclutter git curl lightdm feh \
    plymouth plymouth-themes initramfs-tools

# Node.js 20
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# 2. INSTALLATION APP
cd /home/$USER
if [ ! -d "$APP_DIR" ]; then
    git clone $REPO_URL
fi
cd "$APP_DIR"
npm install
npm run build

# 3. THÈME PLYMOUTH & BOOT
echo "🎨 Config Plymouth..."
sudo mkdir -p /usr/share/plymouth/themes/tactilboard
sudo cp -r $APP_DIR/plymouth/* /usr/share/plymouth/themes/tactilboard/

# Modules et Cmdline
if ! grep -q "vc4" /etc/initramfs-tools/modules; then
    echo -e "vc4\ndrm" | sudo tee -a /etc/initramfs-tools/modules
fi

echo "coherent_pool=1M 8250.nr_uarts=1 snd_bcm2835.enable_headphones=1 root=PARTUUID=45a25dd2-02 rootfstype=ext4 fsck.repair=yes rootwait quiet splash plymouth.ignore-serial-consoles logo.nologo vt.global_cursor_default=0 console=tty3 video=HDMI-A-1:1024x600@60D" | sudo tee /boot/firmware/cmdline.txt

sudo plymouth-set-default-theme tactilboard
sudo update-initramfs -u

# --- AJOUT CRITIQUE : AUTORISATION SUDO SANS MOT DE PASSE ---
echo "🔓 Autorisation sudo pour les updates..."
echo "$USER ALL=(ALL) NOPASSWD: /usr/sbin/update-initramfs, /usr/bin/cp" | sudo tee /etc/sudoers.d/kiosk-updates

# 4. CONFIGURATION AUTOSTART
echo "⚙️ Config autostart..."
mkdir -p ~/.config/openbox
cat <<EOF > ~/.config/openbox/autostart
#!/bin/bash
APP_DIR="/home/\$USER/tactilboard-app"
exec > >(tee -a ~/kiosk.log) 2>&1

feh --bg-fill "\$APP_DIR/splash.png" &
xset s off -dpms
xset s noblank
unclutter -idle 0 &

echo "🚀 Lancement Electron..."
export NODE_ENV=production
cd "\$APP_DIR"
./node_modules/.bin/electron . --no-sandbox & 

(
    echo "🌐 Attente réseau..."
    CONNECTED=false
    for i in {1..30}; do
        if ping -c 1 8.8.8.8 &> /dev/null; then
            CONNECTED=true
            break
        fi
        sleep 1
    done

    if [ "\$CONNECTED" = true ]; then
        git remote update > /dev/null
        LOCAL=\$(git rev-parse HEAD)
        REMOTE=\$(git rev-parse origin/main)

        if [ "\$LOCAL" != "\$REMOTE" ]; then
            echo "📥 Update détecté..."
            git pull origin main
            npm install
            if [ -d "\$APP_DIR/plymouth" ]; then
                sudo cp -r "\$APP_DIR/plymouth/"* /usr/share/plymouth/themes/tactilboard/
                sudo update-initramfs -u & 
            fi
            npm run build
        fi
    fi
) &
EOF
chmod +x ~/.config/openbox/autostart

# 5. LOGIN ET X11
cat <<EOF > ~/.bash_profile
if [ -z "\$DISPLAY" ] && [ "\$XDG_VTNR" -eq 1 ]; then
  exec startx -- -nocursor
fi
EOF

touch ~/.hushlogin
sudo raspi-config nonint do_boot_behaviour B2

echo "✅ Terminé. Reboot..."
sleep 2
sudo reboot