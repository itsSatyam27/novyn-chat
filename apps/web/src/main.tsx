import React from 'react';
import ReactDOM from 'react-dom/client';
import { App } from './App';
import './styles/index.css';
import './styles/glass.css';
import './styles/settingsWorkspace.css';
import { initializeUserPreferences } from './services/settingsTheme';
import { applyAccessibilityPreferences, readBrowserPreference } from './services/browserPreferences';

initializeUserPreferences();
applyAccessibilityPreferences();
document.documentElement.lang = readBrowserPreference('novyn_settings_language', 'en');

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
