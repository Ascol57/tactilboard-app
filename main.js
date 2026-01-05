import { app, BrowserWindow, ipcMain, WebContentsView, globalShortcut } from 'electron';
import path from 'path';
import { fileURLToPath } from 'url';
import wifi from 'node-wifi';
import { execSync } from 'child_process';
import os from 'os';
import axios from 'axios';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let mainWindow;
let captivePortalView = null;

// Initialiser node-wifi
wifi.init({
  iface: null
});

// Fonction pour détecter un portail captif
const checkCaptivePortal = async () => {
  const testUrls = [
    'http://connectivitycheck.gstatic.com/generate_204',
    'http://captive.apple.com/hotspot-detect.html',
    'http://www.msftconnecttest.com/connecttest.txt'
  ];
  
  for (const url of testUrls) {
    try {
      const response = await axios.get(url, {
        timeout: 5000,
        maxRedirects: 0,
        validateStatus: (status) => status < 400
      });
      
      // Si on est redirigé (code 3xx) ou si le contenu n'est pas celui attendu
      if (response.status >= 300 || response.request.res.responseUrl !== url) {
        console.log('Portail captif détecté:', response.request.res.responseUrl);
        return response.request.res.responseUrl;
      }
    } catch (error) {
      if (error.response && error.response.status >= 300 && error.response.status < 400) {
        const redirectUrl = error.response.headers.location;
        console.log('Portail captif détecté (redirect):', redirectUrl);
        return redirectUrl;
      }
    }
  }
  
  return null;
};

// Fonction pour ouvrir la WebContentsView du portail captif
const openCaptivePortalView = (url) => {
  if (!mainWindow) return;
  
  // Fermer la vue existante si elle existe
  if (captivePortalView) {
    mainWindow.contentView.removeChildView(captivePortalView);
    captivePortalView = null;
  }
  
  // Créer une nouvelle WebContentsView
  captivePortalView = new WebContentsView({
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true
    }
  });
  
  // Ajouter la vue à la fenêtre
  mainWindow.contentView.addChildView(captivePortalView);
  
  // Définir les dimensions (plein écran)
  const bounds = mainWindow.getBounds();
  captivePortalView.setBounds({ x: 0, y: 0, width: bounds.width, height: bounds.height });
  
  // Charger l'URL du portail captif
  captivePortalView.webContents.loadURL(url);
  
  // Détecter quand la connexion est réussie
  captivePortalView.webContents.on('did-finish-load', async () => {
    const currentUrl = captivePortalView.webContents.getURL();
    console.log('Page chargée:', currentUrl);
    
    // Vérifier périodiquement si on a passé le portail captif
    const checkInterval = setInterval(async () => {
      const stillCaptive = await checkCaptivePortal();
      if (!stillCaptive) {
        console.log('Portail captif passé avec succès');
        closeCaptivePortalView();
        clearInterval(checkInterval);
        
        // Notifier le renderer
        mainWindow.webContents.send('captive-portal-success');
      }
    }, 3000);
    
    // Arrêter la vérification après 5 minutes
    setTimeout(() => clearInterval(checkInterval), 300000);
  });
  
  console.log('WebContentsView du portail captif ouverte');
};

// Fonction pour fermer la WebContentsView du portail captif
const closeCaptivePortalView = () => {
  if (captivePortalView && mainWindow) {
    mainWindow.contentView.removeChildView(captivePortalView);
    captivePortalView = null;
    console.log('WebContentsView du portail captif fermée');
  }
};

const createWindow = () => {
  mainWindow = new BrowserWindow({
    fullscreen: true,
    frame: false,
    // kiosk: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
    },
  });

  mainWindow.webContents.on('before-input-event', (event, input) => {
    // On vérifie : Ctrl + Alt + K (input.key est insensible à la casse ici)
    if (input.control && input.alt && input.key.toLowerCase() === 'k') {
      console.log('🚨 Sortie de secours activée via before-input-event');
      app.quit();
    }
  });

  const ret = globalShortcut.register('CommandOrControl+Alt+K', () => {
    console.log('Raccourci de secours activé : Fermeture...')
    app.quit()
  })

  if (!ret) {
    console.log('Échec de l\'enregistrement du raccourci')
  }

  // En développement, charge depuis le serveur Vite
  if (process.env.NODE_ENV !== 'production') {
    mainWindow.loadURL('http://localhost:5173');
    mainWindow.webContents.openDevTools();
  } else {
    // En production, charge depuis les fichiers buildés
    mainWindow.loadFile(path.join(__dirname, 'dist/index.html'));
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
};

app.on('will-quit', () => {
  // Toujours nettoyer les raccourcis en quittant
  globalShortcut.unregisterAll()
})

// Fonction helper pour normaliser les données WiFi
const normalizeNetworks = (networks) => {
  return networks
    .filter(n => n.ssid && n.ssid.trim() !== '')
    .map(n => ({
      ssid: n.ssid.trim(),
      bssid: n.bssid || '',
      signal: Math.max(0, Math.min(100, Math.round((n.signal_level + 100) * 2))),
      security: n.security && n.security.length > 0 ? n.security[0] : 'Open'
    }))
    .filter((n, idx, arr) => arr.findIndex(x => x.bssid ? x.bssid === n.bssid : x.ssid === n.ssid) === idx); // Dédupliquer par BSSID si disponible
};

// Scan WiFi sur Linux avec nmcli
const scanWifiLinux = () => {
  try {
    const output = execSync('nmcli -t -f SSID,BSSID,SIGNAL,SECURITY dev wifi', { 
      encoding: 'utf8',
      env: { ...process.env, LANG: 'C.UTF-8', LC_ALL: 'C.UTF-8' }
    });
    const networks = output.split('\n')
      .filter(line => line.trim())
      .map(line => {
        // Le BSSID contient des ":", donc on doit parser différemment
        // Format: SSID:AA:BB:CC:DD:EE:FF:SIGNAL:SECURITY
        const parts = line.split(':');
        if (parts.length >= 9) { // SSID + 6 parts du BSSID + SIGNAL + SECURITY
          const ssid = parts[0];
          const bssid = parts.slice(1, 7).join(':'); // Reconstituer le BSSID (AA:BB:CC:DD:EE:FF)
          const signal = parseInt(parts[7]);
          const security = parts.slice(8).join(':'); // Au cas où le security contient aussi des ":"
          
          return {
            ssid: ssid,
            bssid: bssid,
            signal_level: signal - 100, // nmcli donne 0-100, convertir en -100 à 0
            security: security
          };
        }
        return null;
      })
      .filter(n => n !== null);
    
    return normalizeNetworks(networks);
  } catch (error) {
    console.error('Erreur scan nmcli:', error.message);
    return [];
  }
};

// Scan WiFi sur macOS avec airport
const scanWifiMacOS = () => {
  try {
    const output = execSync('/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -s', { encoding: 'utf8' });
    const networks = output.split('\n')
      .slice(1)
      .filter(line => line.trim())
      .map(line => {
        const parts = line.trim().split(/\s+/);
        if (parts.length >= 7) {
          return {
            ssid: parts[0],
            signal_level: parseInt(parts[6]),
            security: parts.slice(7).join(' ')
          };
        }
        return null;
      })
      .filter(n => n !== null);
    
    return normalizeNetworks(networks);
  } catch (error) {
    console.error('Erreur scan airport:', error.message);
    return [];
  }
};

// Scan WiFi sur Windows
const scanWifiWindows = () => {
  try {
    const output = execSync('netsh wlan show networks mode=Bssid', { encoding: 'utf8' });
    const networks = [];
    const lines = output.split('\n');
    
    let currentSSID = '';
    for (const line of lines) {
      if (line.includes('SSID')) {
        const match = line.match(/SSID\s*:\s*(.+)/);
        if (match) currentSSID = match[1].trim();
      }
      if (line.includes('Signal') && currentSSID) {
        const match = line.match(/Signal\s*:\s*(\d+)%/);
        if (match) {
          networks.push({
            ssid: currentSSID,
            signal_level: parseInt(match[1]) - 100,
            security: 'WPA2'
          });
          currentSSID = '';
        }
      }
    }
    
    return normalizeNetworks(networks);
  } catch (error) {
    console.error('Erreur scan Windows:', error.message);
    return [];
  }
};

// IPC pour scanner les réseaux WiFi
ipcMain.handle('scan-wifi', async (event) => {
  try {
    let networks = [];
    const platform = os.platform();
    
    console.log(`Scan WiFi sur ${platform}`);
    
    // Essayer d'abord la méthode native selon la plateforme
    if (platform === 'linux') {
      networks = scanWifiLinux();
      // Fallback avec node-wifi si nmcli ne fonctionne pas
      if (networks.length === 0) {
        const nodewifiNetworks = await wifi.scan();
        networks = normalizeNetworks(nodewifiNetworks);
      }
    } else if (platform === 'darwin') {
      networks = scanWifiMacOS();
      if (networks.length === 0) {
        const nodewifiNetworks = await wifi.scan();
        networks = normalizeNetworks(nodewifiNetworks);
      }
    } else if (platform === 'win32') {
      networks = scanWifiWindows();
      if (networks.length === 0) {
        const nodewifiNetworks = await wifi.scan();
        networks = normalizeNetworks(nodewifiNetworks);
      }
    } else {
      const nodewifiNetworks = await wifi.scan();
      networks = normalizeNetworks(nodewifiNetworks);
    }
    
    console.log(`${networks.length} réseaux trouvés`);
    return networks;
  } catch (error) {
    console.error('Erreur lors du scan WiFi:', error);
    return [];
  }
});

// IPC pour se connecter à un réseau WiFi
ipcMain.handle('connect-wifi', async (event, ssid, password = '', bssid = '') => {
  const platform = os.platform();
  
  // Fonction pour échapper les caractères spéciaux pour le shell
  const escapeShell = (str) => {
    return str.replace(/'/g, "'\\''");
  };
  
  try {
    // Utiliser nmcli directement sur Linux pour une meilleure compatibilité
    if (platform === 'linux') {
      try {
        // Rescan pour obtenir le SSID exact avec encodage correct
        execSync('nmcli device wifi rescan', { encoding: 'utf8' });
        await new Promise(resolve => setTimeout(resolve, 2000)); // Attendre 2s pour le scan
        
        // Obtenir la liste complète avec BSSID pour identifier le bon réseau
        const output = execSync('nmcli -t -f SSID,BSSID,SECURITY dev wifi', { 
          encoding: 'utf8',
          env: { ...process.env, LANG: 'C.UTF-8', LC_ALL: 'C.UTF-8' }
        });
        
        // Trouver le réseau correspondant
        let targetBssid = bssid; // Utiliser le BSSID passé en paramètre s'il existe
        
        if (!targetBssid) {
          const lines = output.split('\n');
          for (const line of lines) {
            const parts = line.split(':');
            if (parts.length >= 2 && parts[0].trim() === ssid.trim()) {
              targetBssid = parts[1].trim();
              break;
            }
          }
        }
        
        console.log(`Connexion à SSID: ${ssid}, BSSID: ${targetBssid || 'non trouvé'}`);
        
        const escapedPassword = escapeShell(password);
        
        // Toujours utiliser le BSSID si disponible (plus fiable)
        // Note: Le BSSID ne doit PAS être échappé car c'est une adresse MAC (format AA:BB:CC:DD:EE:FF)
        if (targetBssid) {
          if (!password || password.trim() === '') {
            execSync(`nmcli device wifi connect ${targetBssid}`, { 
              encoding: 'utf8',
              env: { ...process.env, LANG: 'C.UTF-8', LC_ALL: 'C.UTF-8' }
            });
          } else {
            execSync(`nmcli device wifi connect ${targetBssid} password '${escapedPassword}'`, { 
              encoding: 'utf8',
              env: { ...process.env, LANG: 'C.UTF-8', LC_ALL: 'C.UTF-8' }
            });
          }
        } else {
          // Fallback sur le SSID
          const escapedSsid = escapeShell(ssid);
          if (!password || password.trim() === '') {
            execSync(`nmcli device wifi connect '${escapedSsid}'`, { encoding: 'utf8' });
          } else {
            execSync(`nmcli device wifi connect '${escapedSsid}' password '${escapedPassword}'`, { encoding: 'utf8' });
          }
        }
        
        // Vérifier si un portail captif est nécessaire
        const captivePortalUrl = await checkCaptivePortal();
        
        return { success: true, message: `Connecté à ${ssid}`, captivePortalUrl };
      } catch (error) {
        // Si l'erreur mentionne key-mgmt, essayer avec des paramètres explicites
        if (error.message.includes('key-mgmt')) {
          try {
            const escapedSsid = escapeShell(ssid);
            const escapedPassword = escapeShell(password);
            
            // Supprimer l'ancienne connexion si elle existe
            try {
              execSync(`nmcli connection delete '${escapedSsid}'`, { encoding: 'utf8' });
            } catch (e) {
              // Ignorer si la connexion n'existe pas
            }
            
            // Créer une nouvelle connexion avec les bons paramètres
            if (password && password.trim() !== '') {
              execSync(`nmcli device wifi connect '${escapedSsid}' password '${escapedPassword}' wep-key-type key`, { encoding: 'utf8' });
            } else {
              execSync(`nmcli device wifi connect '${escapedSsid}'`, { encoding: 'utf8' });
            }
            return { success: true, message: `Connecté à ${ssid}` };
          } catch (retryError) {
            console.error('Erreur après réessai:', retryError);
            return { success: false, message: 'Impossible de se connecter. Vérifiez le mot de passe.' };
          }
        }
        throw error;
      }
    } else {
      // Utiliser node-wifi pour les autres plateformes
      await wifi.connect({ ssid, password });
      return { success: true, message: `Connecté à ${ssid}` };
    }
  } catch (error) {
    console.error('Erreur de connexion WiFi:', error);
    return { success: false, message: error.message || 'Erreur de connexion' };
  }
});

// IPC pour obtenir le réseau actuel
ipcMain.handle('get-current-wifi', async (event) => {
  const platform = os.platform();
  
  try {
    // Sur Linux, utiliser nmcli pour obtenir la connexion active
    if (platform === 'linux') {
      try {
        const output = execSync('nmcli -t -f NAME connection show --active', { 
          encoding: 'utf8',
          env: { ...process.env, LANG: 'C.UTF-8', LC_ALL: 'C.UTF-8' }
        });
        
        const connections = output.split('\n').filter(line => line.trim());
        
        // Obtenir les détails de chaque connexion active
        for (const connName of connections) {
          try {
            const details = execSync(`nmcli connection show "${connName}"`, { encoding: 'utf8' });
            
            // Vérifier si c'est une connexion WiFi
            if (details.includes('type:.*802-11-wireless') || details.includes('802-11-wireless')) {
              // Extraire le SSID de la connexion
              const ssidMatch = connName.match(/^(.*?)$/);
              if (ssidMatch) {
                console.log('WiFi connecté trouvé:', connName);
                return connName;
              }
            }
          } catch (e) {
            // Ignorer les erreurs de parsing
          }
        }
        
        // Si on n'a pas trouvé via nmcli, fallback sur le scan
        const networks = await wifi.scan();
        const currentSsid = networks.find(n => n.signal_level > -50)?.ssid || '';
        if (currentSsid) {
          console.log('WiFi détecté par signal:', currentSsid);
          return currentSsid;
        }
      } catch (error) {
        console.log('Erreur nmcli, fallback sur wifi.scan:', error.message);
        // Fallback sur node-wifi
        const networks = await wifi.scan();
        const currentSsid = networks.find(n => n.signal_level > -50)?.ssid || '';
        if (currentSsid) {
          return currentSsid;
        }
      }
    } else {
      // Pour les autres plateformes, utiliser node-wifi
      const networks = await wifi.scan();
      const currentSsid = networks.find(n => n.signal_level > -50)?.ssid || '';
      return currentSsid;
    }
    
    return '';
  } catch (error) {
    console.error('Erreur lors de la récupération du WiFi actuel:', error);
    return '';
  }
});

// IPC pour ouvrir le portail captif
ipcMain.handle('open-captive-portal', async (event, url) => {
  try {
    openCaptivePortalView(url);
    return { success: true };
  } catch (error) {
    console.error('Erreur ouverture portail captif:', error);
    return { success: false, message: error.message };
  }
});

// IPC pour fermer le portail captif
ipcMain.handle('close-captive-portal', async (event) => {
  try {
    closeCaptivePortalView();
    return { success: true };
  } catch (error) {
    console.error('Erreur fermeture portail captif:', error);
    return { success: false, message: error.message };
  }
});

// IPC pour sauvegarder les paramètres de connexion
ipcMain.handle('save-connection-settings', async (event, settings) => {
  try {
    const settingsPath = path.join(app.getPath('userData'), 'connection-settings.json');
    fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf8');
    console.log('Paramètres de connexion sauvegardés:', settingsPath);
    return { success: true };
  } catch (error) {
    console.error('Erreur lors de la sauvegarde des paramètres:', error);
    return { success: false, message: error.message };
  }
});

// IPC pour charger les paramètres de connexion
ipcMain.handle('load-connection-settings', async (event) => {
  try {
    const settingsPath = path.join(app.getPath('userData'), 'connection-settings.json');
    if (fs.existsSync(settingsPath)) {
      const data = fs.readFileSync(settingsPath, 'utf8');
      const settings = JSON.parse(data);
      console.log('Paramètres de connexion chargés');
      return { success: true, settings };
    }
    return { success: true, settings: null };
  } catch (error) {
    console.error('Erreur lors du chargement des paramètres:', error);
    return { success: false, message: error.message };
  }
});

ipcMain.on('clicked', (event, id) => {
  console.log(`Button ${id} clicked in renderer process`);
});

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
