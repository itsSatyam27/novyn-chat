import type { Message } from '../types';

export function groupsWithPrevious(previous: Message | undefined, message: Message): boolean {
  if (!previous || previous.sender?.toLowerCase() !== message.sender?.toLowerCase()) return false;
  if (previous.game || message.game || previous.poll || message.poll || message.replyTo) return false;
  const before = new Date(previous.timestamp);
  const now = new Date(message.timestamp);
  const delta = now.getTime() - before.getTime();
  return delta >= 0 && delta < 5 * 60 * 1000 && before.toDateString() === now.toDateString();
}
