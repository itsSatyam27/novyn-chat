import React, { useEffect, useState } from 'react';
import { WifiOff, RefreshCw } from 'lucide-react';
import { getSocket } from '../../services/socket';

export const ConnectionNotice: React.FC = () => {
  const [state, setState] = useState<'connected' | 'connecting' | 'offline'>(() => getSocket().connected ? 'connected' : 'connecting');
  useEffect(() => {
    const socket = getSocket();
    const connected = () => setState('connected');
    const disconnected = () => setState('offline');
    const reconnecting = () => setState('connecting');
    socket.on('connect', connected).on('disconnect', disconnected).on('connect_error', disconnected);
    socket.io.on('reconnect_attempt', reconnecting).on('reconnect_failed', disconnected);
    return () => {
      socket.off('connect', connected).off('disconnect', disconnected).off('connect_error', disconnected);
      socket.io.off('reconnect_attempt', reconnecting).off('reconnect_failed', disconnected);
    };
  }, []);
  if (state === 'connected') return null;
  return <div className="connection-notice" role="status" aria-live="polite">
    <WifiOff size={16} aria-hidden="true" />
    <span>{state === 'connecting' ? 'Connecting…' : 'Connection lost. Messages may not send.'}</span>
    {state === 'offline' && <button type="button" onClick={() => { setState('connecting'); getSocket().connect(); }}><RefreshCw size={14} /> Reconnect</button>}
  </div>;
};
