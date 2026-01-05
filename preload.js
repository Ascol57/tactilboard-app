const { contextBridge, ipcRenderer } = require('electron');

// Expose protected methods that allow the renderer process to use
// ipcRenderer without exposing the entire object
contextBridge.exposeInMainWorld('electronAPI', {
  sendClick: (message) => ipcRenderer.send('clicked', message),
  
  // Méthodes WiFi
  scanWifi: () => ipcRenderer.invoke('scan-wifi'),
  connectWifi: (ssid, password, bssid) => ipcRenderer.invoke('connect-wifi', ssid, password, bssid),
  getCurrentWifi: () => ipcRenderer.invoke('get-current-wifi'),
  
  // Portail captif
  openCaptivePortal: (url) => ipcRenderer.invoke('open-captive-portal', url),
  closeCaptivePortal: () => ipcRenderer.invoke('close-captive-portal'),
  onCaptivePortalSuccess: (callback) => ipcRenderer.on('captive-portal-success', callback),
  
  // Paramètres de connexion
  saveConnectionSettings: (settings) => ipcRenderer.invoke('save-connection-settings', settings),
  loadConnectionSettings: () => ipcRenderer.invoke('load-connection-settings'),
});
