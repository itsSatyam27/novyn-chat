import { getSocket } from './socket';

type ProfileChange = { displayName?: string; bio?: string; avatarId?: string; presenceMode?: string; retentionDays?: number; callPrivacy?: string; messagePrivacy?: string; profilePhotoPrivacy?: string; presencePrivacy?: string; readReceiptsEnabled?: boolean; typingIndicatorsEnabled?: boolean; groupInvitePrivacy?: string; friendRequestPrivacy?: string };
export function saveAccountSettings(username: string, change: ProfileChange): Promise<void> {
  const socket = getSocket();
  if (!socket.connected) return Promise.reject(new Error('Reconnect before saving account settings.'));
  return new Promise((resolve, reject) => {
    socket.timeout(10000).emit('update_profile', change, (error: Error | null, result: any) => {
      if (error) reject(new Error('The server did not confirm the change. Restart the chat server and try again.'));
      else if (!result?.ok) reject(new Error(result?.message || 'Could not save account settings.'));
      else resolve();
    });
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
