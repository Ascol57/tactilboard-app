<template>
  <div id="app">
    <main>
      <!-- Panneau de connexion serveur rapide (si WiFi déjà connecté) -->
      <div v-if="connected && !wsConnected && !gridVisible" class="quick-connect-panel">
        <div class="quick-connect-container">
          <h2>Connecté à {{ connectedWifi }}</h2>
          <p>Connectez-vous au serveur pour continuer</p>
          
          <div class="form-group">
            <label>Adresse du serveur</label>
            <input 
              v-model="serverUrl" 
              type="text" 
              placeholder="ws://localhost:8080"
              class="input-field"
            />
          </div>
          
          <div class="form-group">
            <label>Token d'authentification</label>
            <input 
              v-model="authToken" 
              type="password" 
              placeholder="Entrez le token"
              class="input-field"
            />
          </div>
          
          <div class="form-group">
            <label>Salle disponible</label>
            <div class="room-selector">
              <select v-model="roomId" class="input-field">
                <option value="">-- Charger les salles --</option>
                <option v-for="room in availableRooms" :key="room" :value="room">
                  {{ room }}
                </option>
              </select>
              <button @click="loadAvailableRooms" :disabled="loadingRooms" class="load-rooms-btn">
                {{ loadingRooms ? '...' : '🔄' }}
              </button>
            </div>
          </div>
          
          <button @click="connectToServer" :disabled="connecting" class="connect-server-btn">
            {{ connecting ? 'Connexion...' : 'Connecter' }}
          </button>
          
          <button @click="resetWifi" class="back-btn">
            Changer de WiFi
          </button>
          
          <div v-if="wsError" class="error-message">
            {{ wsError }}
          </div>
        </div>
      </div>
      
      <!-- Panneau de connexion serveur complet -->
      <div v-if="showServerPanel && !wsConnected" class="server-panel">
        <div class="server-container">
          <h2>Connexion au serveur</h2>
          
          <div class="form-group">
            <label>Adresse du serveur</label>
            <input 
              v-model="serverUrl" 
              type="text" 
              placeholder="ws://localhost:8080"
              class="input-field"
            />
          </div>
          
          <div class="form-group">
            <label>Token d'authentification</label>
            <input 
              v-model="authToken" 
              type="password" 
              placeholder="Entrez le token"
              class="input-field"
            />
          </div>
          
          <div class="form-group">
            <label>ID de la salle</label>
            <input 
              v-model="roomId" 
              type="text" 
              placeholder="ex: room123"
              class="input-field"
            />
          </div>
          
          <button @click="connectToServer" :disabled="connecting" class="connect-server-btn">
            {{ connecting ? 'Connexion...' : 'Connecter' }}
          </button>
          
          <div v-if="wsError" class="error-message">
            {{ wsError }}
          </div>
        </div>
      </div>
      
      <!-- Panneau WiFi (accessible directement ou après connexion au serveur) -->
      <div v-if="network && !showServerPanel && !gridVisible && !connected" class="network-panel">
        <div class="network-container">
          <div class="network-header">
            <h2>Réseaux WiFi disponibles</h2>
            <button v-if="previousWifiName" @click="restorePreviousWifi" class="back-to-quick-btn">
              ← Retour
            </button>
          </div>
          
          <div class="wifi-list">
            <div 
              v-if="wifiList.length === 0" 
              class="no-wifi"
            >
              <p v-if="scanning">Scan en cours...</p>
              <p v-else>Aucun réseau trouvé</p>
            </div>
            
            <div 
              v-for="wifi in wifiList" 
              :key="wifi.bssid || wifi.ssid"
              class="wifi-item"
              :class="{ selected: selectedWifi && selectedWifi.bssid === wifi.bssid }"
              @click="selectWifi(wifi)"
            >
              <div class="wifi-name">{{ wifi.ssid }}</div>
              <div class="wifi-signal">
                <span class="signal-bars" :style="{ opacity: wifi.signal / 100 }">
                  ▓
                </span>
              </div>
              <div class="wifi-info">
                {{ wifi.signal }}% - {{ wifi.security }}
              </div>
            </div>
          </div>
          
          <div class="network-controls">
            <button @click="scanWifi" :disabled="scanning">
              {{ scanning ? 'Scan en cours...' : 'Actualiser' }}
            </button>
            <button 
              @click="showPasswordModal = true" 
              :disabled="!selectedWifi"
              class="connect-btn"
            >
              Connecter
            </button>
          </div>
          
          <!-- Modal pour le mot de passe WiFi -->
          <div v-if="showPasswordModal" class="modal-overlay" @click="showPasswordModal = false">
            <div class="modal-content" @click.stop>
              <h3>Mot de passe WiFi</h3>
              <p>Réseau : <strong>{{ selectedWifi ? selectedWifi.ssid : '' }}</strong></p>
              <input 
                v-model="wifiPassword" 
                type="password" 
                placeholder="Entrez le mot de passe"
                class="input-field"
                @keyup.enter="connectWifi"
              />
              <div class="modal-buttons">
                <button @click="showPasswordModal = false" class="cancel-btn">
                  Annuler
                </button>
                <button @click="connectWifi" class="confirm-btn">
                  Connecter
                </button>
              </div>
            </div>
          </div>
          
          <div v-if="connected" class="connected-info">
            <p class="connected-text">✓ Connecté à: {{ connectedWifi }}</p>
          </div>
          
          <div class="network-footer">
            <span v-if="wsConnected" class="server-status-connected">✓ Serveur connecté</span>
          </div>
        </div>
      </div>
      
      <!-- Panneau de paramètres -->
      <div v-if="showSettingsPanel && gridVisible" class="settings-panel">
        <div class="settings-container">
          <div class="settings-header">
            <div class="header-content">
              <button 
                v-if="settingsPanelType !== 'general'" 
                @click="settingsPanelType = 'general'" 
                class="back-nav-btn"
              >
                ← Retour
              </button>
              <h2>{{ settingsPanelType === 'general' ? 'Paramètres généraux' : settingsPanelType === 'wifi' ? 'WiFi' : 'Connexion' }}</h2>
            </div>
            <button @click="showSettingsPanel = false" class="close-settings-btn">
              ✕
            </button>
          </div>
          
          <div class="settings-content">
            <!-- Paramètres généraux -->
            <template v-if="settingsPanelType === 'general'">
              <div class="setting-item">
                <label>Largeur de la grille</label>
                <p>{{ width }} colonnes</p>
              </div>
              
              <div class="setting-item">
                <label>Hauteur de la grille</label>
                <p>{{ height }} lignes</p>
              </div>
              
              <div class="setting-item">
                <label>Page actuelle</label>
                <p>{{ currentPage + 1 }}</p>
              </div>

              <div class="settings-divider"></div>

              <button @click="showWifiModal = true" class="settings-nav-btn">
                📡 WiFi
              </button>

              <button @click="showConnectionModal = true" class="settings-nav-btn">
                🌐 Connexion serveur
              </button>
            </template>
          </div>
        </div>
      </div>

      <!-- Modal WiFi -->
      <div v-if="showWifiModal && gridVisible" class="settings-modal-overlay">
        <div class="settings-modal">
          <div class="modal-header">
            <h2>WiFi</h2>
            <button @click="showWifiModal = false" class="modal-close-btn">✕</button>
          </div>
          
          <div class="modal-content">
            <div class="setting-item">
              <label>WiFi actuel</label>
              <p class="wifi-status">{{ connectedWifi || 'Non connecté' }}</p>
            </div>
            
            <div class="setting-item">
              <label>Réseaux disponibles</label>
              <div class="network-list">
                <p v-if="wifiNetworks.length === 0" class="no-networks">
                  Aucun réseau trouvé. Veuillez rafraîchir.
                </p>
                <div v-for="network in wifiNetworks" :key="network.ssid" class="network-item-clickable">
                  <div class="network-info">
                    <span class="network-name">{{ network.ssid }}</span>
                    <span class="signal-strength">{{ network.level }}%</span>
                  </div>
                  <button @click="connectToWifi(network)" class="network-connect-btn">
                    Connecter
                  </button>
                </div>
              </div>
            </div>

            <div v-if="selectedWifi" class="setting-item">
              <label>Mot de passe pour {{ selectedWifi.ssid }}</label>
              <input 
                v-model="wifiPassword" 
                type="password" 
                placeholder="Entrez le mot de passe"
                class="wifi-password-input"
              />
              <button @click="confirmWifiConnection" class="setting-action-btn">
                Se connecter
              </button>
              <button @click="selectedWifi = null" class="cancel-btn">
                Annuler
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Modal Connexion -->
      <div v-if="showConnectionModal && gridVisible" class="settings-modal-overlay">
        <div class="settings-modal">
          <div class="modal-header">
            <h2>Connexion serveur</h2>
            <button @click="showConnectionModal = false" class="modal-close-btn">✕</button>
          </div>
          
          <div class="modal-content">
            <div class="setting-item">
              <label>État de la connexion</label>
              <p class="connection-status">
                {{ wsConnected ? '✓ Connecté' : '✗ Déconnecté' }}
              </p>
            </div>
            
            <div class="setting-item">
              <label>Serveur actuel</label>
              <p class="server-url">{{ serverUrl }}</p>
            </div>

            <div class="setting-item">
              <label>Adresse du serveur</label>
              <input 
                v-model="serverUrl" 
                type="text" 
                placeholder="ws://localhost:8080"
                class="wifi-password-input"
              />
            </div>

            <div class="setting-item">
              <label>Token d'authentification</label>
              <input 
                v-model="authToken" 
                type="password" 
                placeholder="Entrez le token"
                class="wifi-password-input"
              />
            </div>

            <div class="setting-item">
              <label>Salle</label>
              <select 
                v-model="roomId" 
                class="wifi-password-input"
              >
                <option value="">-- Sélectionner une salle --</option>
                <option v-for="room in availableRooms" :key="room" :value="room">
                  {{ room }}
                </option>
              </select>
              <button @click="loadAvailableRooms" class="load-rooms-btn">
                🔄 Actualiser
              </button>
            </div>

            <div class="setting-item button-group">
              <button @click="changeServer" class="setting-action-btn">
                Se connecter
              </button>
              <button @click="showConnectionModal = false" class="cancel-btn">
                Fermer
              </button>
            </div>

            <div class="setting-item">
              <label>État détaillé</label>
              <p v-if="wsConnected" class="connection-info">
                ✓ Connecté à {{ roomId }}
              </p>
              <p v-else class="connection-info error">
                Connexion perdue. Tentative de reconnexion...
              </p>
            </div>
          </div>
        </div>
      </div>
      
      <div class="grid" v-if="gridVisible" :style="{
        gridTemplateColumns: `repeat(${width}, 1fr)`,
        gridTemplateRows: `repeat(${height}, auto)`
      }">
        <div v-for="(item, index) in visibleData" :key="index" class="grid-item" :style="{
          gridColumnStart: item.gridColumnStart,
          gridColumnEnd: item.gridColumnEnd,
          gridRowStart: item.gridRowStart,
          gridRowEnd: item.gridRowEnd
        }" @click="item.action">
          {{ item.content }}
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, computed } from 'vue';

const network = ref(true);
const connected = ref(false);
const connectedWifi = ref('');
const gridVisible = ref(false);
const showServerPanel = ref(false); // Afficher le panneau serveur à la demande
const showSettingsPanel = ref(false); // Panneau de paramètres
const settingsPanelType = ref('general'); // Type de paramètres: 'general', 'wifi', 'connection'
const showWifiModal = ref(false); // Modal pour WiFi
const showConnectionModal = ref(false); // Modal pour Connection
const serverUrl = ref('ws://localhost:8080');
const authToken = ref('votre_cle_secrete_ici');
const roomId = ref(undefined);
const wsConnected = ref(false);
const connecting = ref(false);
const wsError = ref('');
let ws = null;

const width = ref(6);
const height = ref(6);

const wifiList = ref([]);
const wifiNetworks = ref([]);
const selectedWifi = ref(null); // Stocker l'objet wifi complet au lieu du SSID
const scanning = ref(false);
const wifiPassword = ref('');
const showPasswordModal = ref(false);

const availableRooms = ref([]);
const loadingRooms = ref(false);

const previousWifiName = ref(''); // Pour garder trace du WiFi avant de changer
const currentPage = ref(0); // Suivi de la page actuelle

// Variable réactive pour les données du grid
const data = ref([
  {
    content: 'A',
    gridColumnStart: 1,
    gridColumnEnd: 2,
    gridRowStart: 1,
    gridRowEnd: 1,
    page: 0,
    action: () => {
      electronAPI.sendClick(0);
    }
  }
]);

// Fonction pour reconstruire les actions à partir de la configuration reçue
const createActionHandler = (actionConfig) => {
  if (!actionConfig) {
    return () => console.log('Pas d\'action définie');
  }
  
  switch (actionConfig.type) {
    case 'send-id':
      return () => {
        console.log(`📤 Envoi ID: ${actionConfig.value}`);
        
        // Envoyer au serveur via WebSocket
        if (ws && ws.readyState === WebSocket.OPEN) {
          sendToServer({
            type: 'button-click',
            buttonId: actionConfig.value,
            currentPage: currentPage.value,
            timestamp: Date.now()
          });
        }
        
        // Logging local via IPC
        if (window.electronAPI && window.electronAPI.sendClick) {
          electronAPI.sendClick(actionConfig.value);
        }
      };
      
    case 'goto-page':
      return () => {
        console.log(`📄 Aller à la page: ${actionConfig.value}`);
        currentPage.value = actionConfig.value;
        // Mettre à jour le grid pour afficher les éléments de cette page
        updateGridForPage(actionConfig.value);
      };

    case 'page-navigate':
      return () => {
        console.log(actionConfig);
        // Si le plugin a un ID, envoyer au serveur pour calculer la page
        if (actionConfig.pluginId) {
          console.log(`📱 Navigation plugin: ${actionConfig.pluginId}`);
          
          // Envoyer au serveur pour qu'il calcule la page cible
          if (ws && ws.readyState === WebSocket.OPEN) {
            sendToServer({
              type: 'page-navigate-request',
              pluginId: actionConfig.pluginId,
              currentPage: currentPage.value,
              timestamp: Date.now()
            });
          }
        } else {
          // Ancien système avec delta
          const delta = actionConfig.delta ?? 0;
          const maxPage = data.value.reduce((max, item) => Math.max(max, item.page ?? 0), 0);
          const targetPage = Math.max(0, Math.min(maxPage, currentPage.value + delta));
          console.log(`📄 Navigation relative (${delta}) vers page ${targetPage}`);
          currentPage.value = targetPage;
          updateGridForPage(targetPage);
        }
      };
      
    case 'open-settings':
      return () => {
        const target = actionConfig.target || 'general';
        console.log('⚙️ Ouvrir les paramètres:', target);
        
        if (target === 'wifi') {
          showWifiModal.value = true;
        } else if (target === 'connection') {
          showConnectionModal.value = true;
        } else {
          settingsPanelType.value = target;
          showSettingsPanel.value = true;
        }
      };
      
    default:
      return () => console.log('Action inconnue:', actionConfig.type);
  }
};

// Fonction pour mettre à jour le grid en fonction de la page
const updateGridForPage = (pageNum) => {
  // Recalculer les éléments du grid selon la page
  console.log('Affichage de la page:', pageNum);
  currentPage.value = pageNum;
};

// Computed property pour filtrer les items selon la page actuelle
const visibleData = computed(() => {
  return data.value.filter(item => item.page === currentPage.value);
});

// Fonction pour scanner les WiFis
const scanWifi = async () => {
  scanning.value = true;
  selectedWifi.value = null;
  
  try {
    const networks = await window.electronAPI.scanWifi();
    wifiList.value = networks;
    
    // Notifier le serveur si connecté
    if (wsConnected.value && ws) {
      sendToServer({
        type: 'wifi-networks-updated',
        networks: wifiList.value,
        timestamp: Date.now()
      });
    }
  } catch (error) {
    console.error('Erreur lors du scan WiFi:', error);
    wifiList.value = [];
  }
  
  scanning.value = false;
};

// Fonction pour sélectionner un WiFi
const selectWifi = (wifi) => {
  selectedWifi.value = wifi;
};

// Fonction pour se connecter au WiFi sélectionné
const connectWifi = async () => {
  if (selectedWifi.value) {
    showPasswordModal.value = false; // Fermer le modal
    
    try {
      const result = await window.electronAPI.connectWifi(
        selectedWifi.value.ssid, 
        wifiPassword.value, 
        selectedWifi.value.bssid
      );
      if (result.success) {
        connected.value = true;
        connectedWifi.value = selectedWifi.value.ssid;
        wifiPassword.value = ''; // Réinitialiser le mot de passe
        console.log('Connecté à:', selectedWifi.value.ssid);
        
        // Si déjà connecté au serveur, afficher la grille
        if (wsConnected.value) {
          gridVisible.value = true;
        }
        
        // Vérifier si un portail captif est requis
        if (result.captivePortalUrl) {
          console.log('Portail captif détecté, ouverture...', result.captivePortalUrl);
          await window.electronAPI.openCaptivePortal(result.captivePortalUrl);
        }
        
        // Notifier le serveur si connecté
        if (wsConnected.value && ws) {
          sendToServer({
            type: 'wifi-connected',
            ssid: connectedWifi.value,
            success: true,
            timestamp: Date.now()
          });
        }
      } else {
        console.error('Erreur de connexion:', result.message);
        alert('Erreur de connexion: ' + result.message);
        wifiPassword.value = ''; // Réinitialiser le mot de passe
        showPasswordModal.value = true; // Réouvrir le modal pour réessayer
        
        // Notifier l'échec au serveur
        if (wsConnected.value && ws) {
          sendToServer({
            type: 'wifi-connection-failed',
            ssid: selectedWifi.value.ssid,
            error: result.message,
            timestamp: Date.now()
          });
        }
      }
    } catch (error) {
      console.error('Erreur lors de la connexion:', error);
      alert('Erreur: ' + error.message);
      wifiPassword.value = ''; // Réinitialiser le mot de passe
    }
  }
};

// Charger le WiFi actuel au montage du composant
const loadCurrentWifi = async () => {
  try {
    const current = await window.electronAPI.getCurrentWifi();
    if (current) {
      connected.value = true;
      connectedWifi.value = current;
    }
  } catch (error) {
    console.error('Erreur lors de la récupération du WiFi actuel:', error);
  }
};

// Fonction pour réinitialiser la connexion WiFi
const resetWifi = () => {
  previousWifiName.value = connectedWifi.value; // Sauvegarder le WiFi précédent
  connected.value = false;
  connectedWifi.value = '';
  selectedWifi.value = null;
  wifiPassword.value = '';
  showPasswordModal.value = false;
};

// Fonction pour restaurer la connexion WiFi précédente
const restorePreviousWifi = () => {
  if (previousWifiName.value) {
    connectedWifi.value = previousWifiName.value;
    connected.value = true;
    selectedWifi.value = null;
    wifiPassword.value = '';
    showPasswordModal.value = false;
    previousWifiName.value = ''; // Réinitialiser après restauration
  }
};

// Fonction pour sauvegarder les paramètres de connexion
const saveConnectionSettings = async () => {
  try {
    await window.electronAPI.saveConnectionSettings({
      serverUrl: serverUrl.value,
      authToken: authToken.value,
      roomId: roomId.value,
    });
    console.log('Paramètres sauvegardés');
  } catch (error) {
    console.error('Erreur lors de la sauvegarde:', error);
  }
};

// Fonction pour charger les paramètres de connexion
const loadConnectionSettings = async () => {
  try {
    const result = await window.electronAPI.loadConnectionSettings();
    if (result.success && result.settings) {
      serverUrl.value = result.settings.serverUrl || 'ws://localhost:8080';
      authToken.value = result.settings.authToken || 'votre_cle_secrete_ici';
      roomId.value = result.settings.roomId || undefined;
      console.log('Paramètres chargés');
    }
  } catch (error) {
    console.error('Erreur lors du chargement:', error);
  }
};

// Watcher pour sauvegarder automatiquement les paramètres
watch([serverUrl, authToken, roomId], () => {
  saveConnectionSettings();
}, { deep: true });

// Initialiser au montage
onMounted(async () => {
  await loadConnectionSettings();
  await loadCurrentWifi();
  scanWifi();
  
  // Écouter l'événement de succès du portail captif
  window.electronAPI.onCaptivePortalSuccess(() => {
    console.log('Portail captif validé avec succès');
    // Vous pouvez afficher une notification ou mettre à jour l'UI ici
  });
  
  // Tenter la connexion automatique si WiFi connecté et paramètres présents
  if (connected.value && serverUrl.value && authToken.value && roomId.value) {
    console.log('🔄 Tentative de connexion automatique au serveur...');
    setTimeout(() => {
      connectToServer();
    }, 1000); // Délai pour laisser le temps au WiFi de se stabiliser
  }
});

// Fonction pour charger les salles disponibles
const loadAvailableRooms = async () => {
  if (!serverUrl.value || !authToken.value) {
    wsError.value = 'Veuillez d\'abord entrer les détails du serveur';
    return;
  }
  
  loadingRooms.value = true;
  wsError.value = '';
  
  try {
    const httpUrl = serverUrl.value.replace('ws://', 'http://').replace('wss://', 'https://');
    const response = await fetch(`${httpUrl}/rooms?token=${authToken.value}`);
    
    if (!response.ok) {
      throw new Error(`Erreur serveur: ${response.status}`);
    }
    
    const data = await response.json();
    availableRooms.value = data.availableRooms || [];
    
    if (availableRooms.value.length === 0) {
      wsError.value = 'Aucune salle disponible';
    }
  } catch (error) {
    console.error('Erreur lors du chargement des salles:', error);
    wsError.value = 'Impossible de charger les salles: ' + error.message;
  } finally {
    loadingRooms.value = false;
  }
};

// Fonction pour se connecter au serveur WebSocket
const connectToServer = async () => {
  if (!serverUrl.value || !authToken.value || !roomId.value) {
    wsError.value = 'Veuillez remplir tous les champs';
    return;
  }
  
  connecting.value = true;
  wsError.value = '';
  
  try {
    const url = `${serverUrl.value}?token=${authToken.value}&roomId=${roomId.value}&role=client`;
    ws = new WebSocket(url);
    
    ws.onopen = () => {
      wsConnected.value = true;
      connecting.value = false;
      showServerPanel.value = false; // Fermer le panneau serveur
      console.log(`Connecté au serveur comme client`);
      
      // Si déjà connecté au WiFi, afficher la grille
      if (connected.value) {
        gridVisible.value = true;
      }
      
      // Envoyer l'état initial au serveur
      const initialState = {
        type: 'initial-state',
        role: 'client',
        wifiNetworks: wifiList.value,
        connectedWifi: connectedWifi.value,
        timestamp: Date.now()
      };
      wifiNetworks.value = wifiList.value;
      sendToServer(initialState);
    };
    
    ws.onmessage = async (event) => {
      let messageData = event.data;
      
      // Convertir Blob en texte si nécessaire
      if (event.data instanceof Blob) {
        messageData = await event.data.text();
      }
      
      // Traiter les messages reçus du serveur
      console.log('Message reçu:', messageData);
      try {
        const message = JSON.parse(messageData);
        
        // Traiter différents types de messages
        switch (message.type) {
          case 'grid-config':
            // Configuration de grille envoyée par le serveur
            console.log('📥 Reçu grid-config:', message);
            if (message.width && message.height) {
              console.log('🔄 Mise à jour grille:', message.width, 'x', message.height);
              width.value = message.width;
              height.value = message.height;
              console.log('✓ Grille mise à jour:', width.value, 'x', height.value);
            } else {
              console.warn('⚠️ grid-config invalide - width ou height manquant');
            }
            break;
            
          case 'data-config':
            // Configuration des données (éléments du grid avec actions)
            console.log('📥 Reçu data-config:', message);
            if (message.data && Array.isArray(message.data)) {
              console.log('🔄 Mise à jour des données du grid');
              // Reconstruire les données avec les fonctions d'action appropriées
              data.value = message.data.map(item => ({
                ...item,
                action: createActionHandler(item.action)
              }));
              console.log('✓ Données du grid mises à jour:', data.value.length, 'éléments');
            } else {
              console.warn('⚠️ data-config invalide - data manquante');
            }
            break;
            
          case 'wifi-scan-request':
            // Le client demande un scan WiFi
            scanWifi().then(() => {
              sendToServer({
                type: 'wifi-networks',
                networks: wifiList.value,
                timestamp: Date.now()
              });
            });
            break;
            
          case 'wifi-connect-request':
            // Le client demande de se connecter à un WiFi
            if (message.ssid) {
              selectedWifi.value = message.ssid;
              connectWifi().then(() => {
                sendToServer({
                  type: 'wifi-connected',
                  ssid: connectedWifi.value,
                  success: connected.value,
                  timestamp: Date.now()
                });
              });
            }
            break;
            
          case 'wifi-networks':
            // Mise à jour de la liste WiFi depuis le serveur
            if (message.networks) {
              wifiList.value = message.networks;
              wifiNetworks.value = message.networks;
            }
            break;
            
          case 'navigate-to-page':
            // Navigation vers une page calculée par le serveur
            console.log('📄 Navigation vers page:', message.page);
            if (typeof message.page === 'number') {
              currentPage.value = message.page;
              updateGridForPage(message.page);
            }
            break;
            
          default:
            console.log('Type de message non géré:', message.type);
        }
      } catch (e) {
        console.error('❌ Erreur parsing JSON:', e);
        console.error('Message brut:', messageData);
      }
    };
    
    ws.onerror = (error) => {
      wsError.value = 'Erreur de connexion au serveur';
      console.error('Erreur WebSocket:', error);
      connecting.value = false;
    };
    
    ws.onclose = () => {
      wsConnected.value = false;
      gridVisible.value = false;
      showSettingsPanel.value = false;
      ws = null;
      console.log('Déconnecté du serveur - retour au panneau de connexion');
      
      // Si WiFi toujours connecté, afficher le quick-connect-panel
      // sinon, afficher le panneau de sélection WiFi
      if (connected.value) {
        console.log('Affichage du quick-connect-panel');
      } else {
        network.value = true;
      }
    };
  } catch (error) {
    wsError.value = error.message;
    connecting.value = false;
  }
};

// Fonction pour envoyer un message au serveur
const sendToServer = (message) => {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(message));
  }
};

// Fonction pour changer de WiFi depuis les paramètres
const changeWifi = () => {
  showSettingsPanel.value = false;
  gridVisible.value = false;
  
  // Déconnecter du serveur si connecté
  if (ws) {
    ws.close();
  }
  wsConnected.value = false;
  
  // Réinitialiser WiFi
  resetWifi();
};

// Fonction pour se connecter directement à un WiFi depuis le modal
const connectToWifi = (network) => {
  selectedWifi.value = network;
  wifiPassword.value = '';
};

// Fonction pour confirmer la connexion WiFi
const confirmWifiConnection = async () => {
  if (!selectedWifi.value || !wifiPassword.value) {
    console.warn('⚠️ WiFi ou mot de passe manquant');
    return;
  }
  
  try {
    console.log('🔄 Tentative de connexion à:', selectedWifi.value.ssid);
    
    // Appeler l'API Electron pour se connecter au WiFi
    if (window.electronAPI && window.electronAPI.connectWifi) {
      const result = await window.electronAPI.connectWifi(
        selectedWifi.value.ssid,
        wifiPassword.value
      );
      
      if (result.success) {
        console.log('✓ Connecté au WiFi:', selectedWifi.value.ssid);
        connectedWifi.value = selectedWifi.value.ssid;
        selectedWifi.value = null;
        wifiPassword.value = '';
        showWifiModal.value = false;
      } else {
        console.error('❌ Erreur connexion WiFi:', result.error);
      }
    } else {
      console.warn('⚠️ API Electron non disponible pour WiFi');
    }
  } catch (error) {
    console.error('❌ Erreur:', error);
  }
};

// Fonction pour changer de serveur depuis les paramètres
const changeServer = () => {
  showSettingsPanel.value = false;
  gridVisible.value = false;
  
  // Déconnecter du serveur si connecté
  if (ws) {
    ws.close();
  }
  wsConnected.value = false;
  
  // Afficher le panneau de connexion rapide si WiFi connecté
  // sinon retourner au panneau réseau
  if (!connected.value) {
    network.value = true;
  }
};
</script>

<style scoped>
#app {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

main {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
}

.server-panel {
  width: 100%;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.server-container {
  background: white;
  border-radius: 15px;
  padding: 40px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
  width: 90%;
  max-width: 500px;
}

.server-container h2 {
  color: #333;
  margin-top: 0;
  margin-bottom: 30px;
  font-size: 28px;
  text-align: center;
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  color: #333;
  font-weight: 600;
  font-size: 14px;
}

.input-field {
  width: 100%;
  padding: 12px;
  border: 1px solid #ddd;
  border-radius: 8px;
  font-size: 14px;
  font-family: inherit;
  transition: border-color 0.3s;
  box-sizing: border-box;
}

.input-field:focus {
  outline: none;
  border-color: #42b983;
  box-shadow: 0 0 0 3px rgba(66, 185, 131, 0.1);
}

.input-field:hover {
  border-color: #42b983;
}

.room-selector {
  display: flex;
  gap: 8px;
  align-items: center;
}

.room-selector .input-field {
  flex: 1;
  margin: 0;
}

.load-rooms-btn {
  padding: 12px 16px;
  background-color: #667eea;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 16px;
  cursor: pointer;
  transition: all 0.3s;
  min-width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.load-rooms-btn:hover:not(:disabled) {
  background-color: #764ba2;
}

.load-rooms-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.connect-server-btn {
  width: 100%;
  padding: 14px;
  background-color: #42b983;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  margin-bottom: 15px;
}

.connect-server-btn:hover:not(:disabled) {
  background-color: #35a372;
}

.connect-server-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.error-message {
  padding: 12px;
  background-color: #ffebee;
  color: #c62828;
  border-radius: 8px;
  font-size: 14px;
  text-align: center;
}

.quick-connect-panel {
  width: 100%;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.quick-connect-container {
  background: white;
  border-radius: 15px;
  padding: 40px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
  width: 90%;
  max-width: 500px;
}

.quick-connect-container h2 {
  color: #333;
  margin-top: 0;
  margin-bottom: 10px;
  font-size: 28px;
  text-align: center;
}

.quick-connect-container p {
  color: #666;
  text-align: center;
  margin-bottom: 30px;
  font-size: 14px;
}

.back-btn {
  width: 100%;
  padding: 12px;
  background-color: #f0f0f0 !important;
  color: #333 !important;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  margin-top: 10px;
}

.back-btn:hover {
  background-color: #e0e0e0 !important;
}

.network-panel {
  width: 100%;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.network-container {
  background: white;
  border-radius: 15px;
  padding: 40px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
  width: 90%;
  max-width: 600px;
}

.network-container h2 {
  color: #333;
  margin-top: 0;
  margin-bottom: 30px;
  font-size: 28px;
  text-align: center;
}

.network-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 30px;
}

.network-header h2 {
  color: #333;
  margin: 0;
  font-size: 28px;
  text-align: center;
  flex: 1;
}

.back-to-quick-btn {
  background-color: #f0f0f0 !important;
  color: #333 !important;
  padding: 10px 16px !important;
  font-size: 14px !important;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.3s;
  min-width: auto;
  border: none !important;
}

.back-to-quick-btn:hover {
  background-color: #e0e0e0 !important;
}

.wifi-list {
  margin-bottom: 30px;
  max-height: 400px;
  overflow-y: auto;
  border: 1px solid #e0e0e0;
  border-radius: 10px;
}

.no-wifi {
  padding: 40px;
  text-align: center;
  color: #999;
  font-size: 16px;
}

.wifi-item {
  padding: 15px 20px;
  border-bottom: 1px solid #f0f0f0;
  cursor: pointer;
  transition: all 0.3s;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 15px;
}

.wifi-item:hover {
  background-color: #f9f9f9;
}

.wifi-item.selected {
  background-color: #e8f5e9;
  border-left: 4px solid #42b983;
  border-bottom: 1px solid #f0f0f0;
}

.wifi-name {
  flex: 1;
  font-weight: 500;
  color: #333;
  font-size: 16px;
}

.wifi-signal {
  font-size: 20px;
}

.signal-bars {
  color: #42b983;
}

.wifi-info {
  font-size: 12px;
  color: #999;
  white-space: nowrap;
}

.network-controls {
  display: flex;
  gap: 10px;
  margin-bottom: 20px;
}

.network-controls button {
  flex: 1;
  padding: 12px 20px;
  font-size: 16px;
  border-radius: 8px;
  border: none;
  cursor: pointer;
  transition: all 0.3s;
  font-weight: 600;
}

.network-controls button:first-child {
  background-color: #f0f0f0;
  color: #333;
}

.network-controls button:first-child:hover:not(:disabled) {
  background-color: #e0e0e0;
}

.connect-btn {
  background-color: #42b983 !important;
  color: white !important;
}

.connect-btn:hover:not(:disabled) {
  background-color: #35a372 !important;
}

.network-controls button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.connected-info {
  padding: 15px;
  background-color: #e8f5e9;
  border-left: 4px solid #42b983;
  border-radius: 5px;
  text-align: center;
}

.connected-text {
  color: #42b983;
  margin: 0;
  font-weight: 600;
}

.network-footer {
  margin-top: 20px;
  padding-top: 20px;
  border-top: 1px solid #e0e0e0;
  display: flex;
  justify-content: center;
}

.server-link-btn {
  background-color: #f0f0f0 !important;
  color: #333 !important;
  padding: 10px 20px !important;
  font-size: 14px !important;
}

.server-link-btn:hover {
  background-color: #e0e0e0 !important;
}

.server-status-connected {
  color: #42b983;
  font-weight: 600;
  font-size: 14px;
}

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: white;
  border-radius: 15px;
  padding: 30px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
  max-width: 400px;
  width: 90%;
}

.modal-content h3 {
  margin-top: 0;
  margin-bottom: 15px;
  color: #333;
  font-size: 20px;
}

.modal-content p {
  margin-bottom: 20px;
  color: #666;
  font-size: 14px;
}

.modal-content p strong {
  color: #42b983;
}

.modal-buttons {
  display: flex;
  gap: 10px;
  margin-top: 20px;
}

.modal-buttons button {
  flex: 1;
  padding: 12px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
}

.cancel-btn {
  background-color: #f0f0f0;
  color: #333;
}

.cancel-btn:hover {
  background-color: #e0e0e0;
}

.confirm-btn {
  background-color: #42b983;
  color: white;
}

.confirm-btn:hover {
  background-color: #35a372;
}

.settings-panel {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2000;
}

.settings-container {
  background: white;
  border-radius: 15px;
  padding: 30px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
  max-width: 500px;
  width: 90%;
  max-height: 80vh;
  overflow-y: auto;
}

.settings-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 30px;
  border-bottom: 1px solid #e0e0e0;
  padding-bottom: 20px;
}

.header-content {
  display: flex;
  align-items: center;
  gap: 15px;
}

.settings-header h2 {
  color: #333;
  margin: 0;
  font-size: 24px;
}

.back-nav-btn {
  background: none;
  border: none;
  color: #667eea;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  padding: 0;
  transition: all 0.3s;
  min-width: auto;
}

.back-nav-btn:hover {
  color: #764ba2;
  transform: translateX(-4px);
}

.close-settings-btn {
  background-color: #f0f0f0;
  color: #333;
  padding: 8px 12px;
  font-size: 18px;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.3s;
  min-width: auto;
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.close-settings-btn:hover {
  background-color: #e0e0e0;
}

.settings-divider {
  height: 1px;
  background: #e0e0e0;
  margin: 20px 0;
}

.settings-nav-btn {
  width: 100%;
  padding: 12px;
  background-color: white;
  color: #333;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.3s;
  text-align: left;
}

.settings-nav-btn:hover {
  background-color: #f9f9f9;
  border-color: #667eea;
  color: #667eea;
}

.settings-nav-btn:not(:last-child) {
  margin-bottom: 10px;
}

.settings-content {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.setting-item {
  padding: 15px;
  background-color: #f9f9f9;
  border-radius: 8px;
  border-left: 4px solid #42b983;
}

.setting-item label {
  display: block;
  font-weight: 600;
  color: #333;
  margin-bottom: 8px;
  font-size: 14px;
}

.setting-item p {
  margin: 0;
  color: #666;
  font-size: 14px;
}

.setting-action-btn {
  margin-top: 10px;
  width: 100%;
  padding: 10px;
  background-color: #42b983;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
}

.setting-action-btn:hover {
  background-color: #35a372;
}

.wifi-status {
  font-weight: 600;
  color: #42b983 !important;
}

.connection-status {
  font-weight: 600;
  color: #42b983 !important;
}

.connection-status.error {
  color: #e74c3c !important;
}

.server-url {
  font-size: 12px !important;
  color: #999 !important;
  word-break: break-all;
}

.connection-info {
  color: #42b983 !important;
  font-weight: 500;
}

.connection-info.error {
  color: #e74c3c !important;
}

.network-list {
  margin-top: 10px;
}

.network-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px;
  background: white;
  border-radius: 6px;
  margin-bottom: 8px;
  border: 1px solid #e0e0e0;
  font-size: 13px;
}

.network-item span {
  color: #333;
}

.signal-strength {
  color: #999;
  font-size: 12px;
}

.no-networks {
  text-align: center;
  color: #999 !important;
  padding: 20px !important;
  font-style: italic;
}

/* Modal styles */
.settings-modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2001;
}

.settings-modal {
  background: white;
  border-radius: 15px;
  width: 90%;
  max-width: 500px;
  max-height: 80vh;
  overflow-y: auto;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px;
  border-bottom: 1px solid #e0e0e0;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.modal-header h2 {
  color: white;
  margin: 0;
  font-size: 22px;
}

.modal-close-btn {
  background: rgba(255, 255, 255, 0.2);
  color: white;
  border: none;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  font-size: 20px;
  cursor: pointer;
  transition: all 0.3s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-close-btn:hover {
  background: rgba(255, 255, 255, 0.3);
}

.modal-content {
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.wifi-password-input {
  width: 100%;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 13px;
  box-sizing: border-box;
  font-family: inherit;
}

.wifi-password-input:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 2px rgba(102, 126, 234, 0.1);
}

.load-rooms-btn {
  margin-top: 8px;
  padding: 8px 12px;
  background-color: #667eea;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
}

.load-rooms-btn:hover {
  background-color: #764ba2;
}

.network-item-clickable {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  background: white;
  border-radius: 8px;
  border: 1px solid #e0e0e0;
  margin-bottom: 8px;
  gap: 10px;
}

.network-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
  flex: 1;
}

.network-name {
  color: #333;
  font-weight: 500;
  font-size: 13px;
}

.signal-strength {
  color: #999;
  font-size: 11px;
}

.network-connect-btn {
  padding: 6px 12px;
  background-color: #667eea;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  white-space: nowrap;
}

.network-connect-btn:hover {
  background-color: #764ba2;
}

.button-group {
  display: flex;
  gap: 10px;
}

.button-group .setting-action-btn,
.button-group .cancel-btn {
  flex: 1;
}

.cancel-btn {
  padding: 10px;
  background-color: #f0f0f0;
  color: #333;
  border: none;
  border-radius: 6px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
}

.cancel-btn:hover {
  background-color: #e0e0e0;
}

.grid {
  display: grid;
  gap: 10px;
  width: 100vw;
  height: 100vh;
}

.grid-item {
  background-color: #f0f0f0;
  border: 2px solid #42b983;
  border-radius: 8px;
  padding: 20px;
  min-height: 100px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s;
  cursor: pointer;
}

.grid-item:hover {
  background-color: #42b983;
  color: white;
}

h1 {
  margin: 0;
}

h2 {
  color: #42b983;
}

.counter {
  display: flex;
  gap: 20px;
  align-items: center;
  justify-content: center;
  margin-top: 30px;
  font-size: 24px;
}

button {
  background-color: #42b983;
  color: white;
  border: none;
  padding: 10px 20px;
  font-size: 20px;
  border-radius: 5px;
  cursor: pointer;
  transition: background-color 0.3s;
}

button:hover {
  background-color: #35a372;
}

button:active {
  background-color: #2d8a5f;
}
</style>
