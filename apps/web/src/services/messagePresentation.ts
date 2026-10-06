import type { Message } from '../types';

export const ENCRYPTED_MESSAGE_PLACEHOLDER = '🔒 Encrypted message';

// Resolve quotes locally: encrypted reply metadata must stay opaque on the relay.
// Re-run when originals decrypt, are edited, or are deleted.
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

// Keep the legacy text summary compatible with older clients. New clients use
// the encrypted envelope to produce their preview locally, never on the relay.
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
    isEncrypted: Boolean(message.isEncrypted),
    ciphertext: message.ciphertext,
    iv: message.iv,
  };
}

export function needsDecryption(message?: Message): message is Message {
  return Boolean(message?.isEncrypted && message.ciphertext && message.iv &&
    message.text === ENCRYPTED_MESSAGE_PLACEHOLDER);
}

export function withDecryptedText(message: Message, decrypted: Message): Message {
  // A late decryption must not overwrite a newer, edited, or deleted message.
  if (!needsDecryption(message) || !decrypted.isEncrypted ||
      message.id !== decrypted.id || message.ciphertext !== decrypted.ciphertext ||
      message.iv !== decrypted.iv || message.text === decrypted.text ||
      decrypted.text === ENCRYPTED_MESSAGE_PLACEHOLDER) return message;
  return { ...message, text: decrypted.text };
}
