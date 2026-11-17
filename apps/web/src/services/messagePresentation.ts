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
  return {
    id: message.id || '',
    sender: message.from || message.sender || item.lastFrom || '',
    receiver: message.to || message.receiver || username,
    text: message.isEncrypted ? ENCRYPTED_MESSAGE_PLACEHOLDER : message.text || '',
    timestamp: message.timestamp || item.lastTimestamp,
    status: 'delivered',
    attachment: message.attachment,
    isVoice: Boolean(message.isVoice || message.attachment?.kind === 'audio'),
  };
}

export function withDecryptedText(message: Message, decrypted: Message): Message {
  // A late decryption must not overwrite a newer, edited, or deleted message.
  if (!needsDecryption(message) || !decrypted.isEncrypted ||
      message.id !== decrypted.id || message.ciphertext !== decrypted.ciphertext ||
      message.iv !== decrypted.iv || message.text === decrypted.text ||
      decrypted.text === ENCRYPTED_MESSAGE_PLACEHOLDER) return message;
  return { ...message, text: decrypted.text };
}
