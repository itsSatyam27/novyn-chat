import type { Message } from '../types';

export const LEGACY_MESSAGE_UNAVAILABLE = 'Previous encrypted message unavailable';

// Resolve reply previews from locally cached message text.
export function resolveReplyPreviews(messages: Message[]): Message[] {
  const originals = new Map(messages.map(message => [message.id, message]));
  return messages.map(message => {
    const reply = message.replyTo;
    if (!reply) return message;
    const original = originals.get(reply.id);
    const legacyReply = reply as typeof reply & { from?: string };
    return {
      ...message,
      replyTo: {
        ...reply,
        sender: original?.sender || reply.sender || legacyReply.from || '',
        text: original ? original.text : reply.text,
        attachment: original ? original.attachment : reply.attachment,
      },
    };
  });
}

// Older message records may still be marked encrypted; display them as unavailable
// unless this device already has a readable local copy.
export function readLastMessage(item: any, username: string): Message | undefined {
  const raw = item.lastMessageData || item.lastMessage;
  if (!raw) return undefined;
  const message = typeof raw === 'string' ? { text: raw } : raw;
  const legacyEncrypted = Boolean(message.isEncrypted);
  return {
    id: message.id || '',
    sender: message.from || message.sender || item.lastFrom || '',
    receiver: message.to || message.receiver || username,
    text: legacyEncrypted ? LEGACY_MESSAGE_UNAVAILABLE : message.text || '',
    timestamp: message.timestamp || item.lastTimestamp,
    status: 'delivered',
    attachment: message.attachment,
    isVoice: Boolean(message.isVoice || message.attachment?.kind === 'audio'),
    isEncrypted: legacyEncrypted,
  };
}

export function withCachedLegacyText(message: Message, cached: Message): Message {
  // Preserve only a readable copy already cached locally; never decrypt ciphertext.
  if (!message.isEncrypted || !cached.isEncrypted || message.id !== cached.id ||
      message.text !== LEGACY_MESSAGE_UNAVAILABLE || !cached.text ||
      cached.text === LEGACY_MESSAGE_UNAVAILABLE) return message;
  return { ...message, text: cached.text, isEncrypted: true };
}
