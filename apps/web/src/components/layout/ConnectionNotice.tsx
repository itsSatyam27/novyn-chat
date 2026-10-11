import React, { useEffect, useState } from 'react';
import { WifiOff, RefreshCw } from 'lucide-react';
import { getSocket } from '../../services/socket';
import { triggerHaptic } from '../../services/capacitor';

export const ConnectionNotice: React.FC = () => {
  const [state, setState] = useState<'connected' | 'connecting' | 'offline'>(() => {
    if (typeof navigator !== 'undefined' && !navigator.onLine) return 'offline';
    return getSocket().connected ? 'connected' : 'connecting';
  });

  useEffect(() => {
    const socket = getSocket();
    const handleConnected = () => setState('connected');
    const handleDisconnected = () => setState('offline');
    const handleReconnecting = () => setState('connecting');

    const handleWindowOnline = () => {
      setState('connecting');
      socket.connect();
    };
    const handleWindowOffline = () => {
      setState('offline');
    };

    socket.on('connect', handleConnected);
    socket.on('disconnect', handleDisconnected);
    socket.on('connect_error', handleDisconnected);
    socket.io.on('reconnect_attempt', handleReconnecting);
    socket.io.on('reconnect_failed', handleDisconnected);

    window.addEventListener('online', handleWindowOnline);
    window.addEventListener('offline', handleWindowOffline);

    return () => {
      socket.off('connect', handleConnected);
      socket.off('disconnect', handleDisconnected);
      socket.off('connect_error', handleDisconnected);
      socket.io.off('reconnect_attempt', handleReconnecting);
      socket.io.off('reconnect_failed', handleDisconnected);
      window.removeEventListener('online', handleWindowOnline);
      window.removeEventListener('offline', handleWindowOffline);
    };
  }, []);

  if (state === 'connected') return null;

  const handleReconnect = () => {
    triggerHaptic('light');
    setState('connecting');
    getSocket().connect();
  };

  return (
    <div className="connection-notice" role="status" aria-live="polite">
      <WifiOff size={16} aria-hidden="true" />
      <span>{state === 'connecting' ? 'Connecting to Novyn…' : 'Connection lost. Messages may not send.'}</span>
      {state === 'offline' && (
        <button type="button" onClick={handleReconnect}>
          <RefreshCw size={14} /> Reconnect
        </button>
      )}
    </div>
  );
};
