import { getSocket } from './socket';

type ProfileChange = { displayName?: string; bio?: string; avatarId?: string; presenceMode?: string; retentionDays?: number };
export function saveAccountSettings(username: string, change: ProfileChange): Promise<void> {
  const socket = getSocket();
  if (!socket.connected) return Promise.reject(new Error('Reconnect before saving account settings.'));
  return new Promise((resolve, reject) => {
    const clear = () => { clearTimeout(timer); socket.off('profile_updated', updated); socket.off('disconnect', disconnected); };
    const updated = (profile: any) => {
      if (profile?.username?.toLowerCase() === username.toLowerCase() &&
          Object.entries(change).every(([key, value]) => profile[key] === value)) { clear(); resolve(); }
    };
    const disconnected = () => { clear(); reject(new Error('Connection lost before the change was confirmed.')); };
    const timer = setTimeout(() => { clear(); reject(new Error('The change could not be confirmed. Please try again.')); }, 10000);
    socket.on('profile_updated', updated);
    socket.on('disconnect', disconnected);
    socket.emit('update_profile', change);
  });
}
export function setBlockedContact(username: string, blocked: boolean): Promise<void> {
  const socket = getSocket();
  if (!socket.connected) return Promise.reject(new Error('Reconnect before changing blocked contacts.'));
  return new Promise((resolve, reject) => {
    socket.timeout(10000).emit('set_block', { username, blocked }, (error: Error | null, result: any) => {
      if (error) reject(new Error('The block change could not be confirmed. Please try again.'));
      else if (!result?.ok) reject(new Error(result?.message || 'Could not update blocked contacts.'));
      else resolve();
    });
  });
}
