export type MessageStatus = 'sending' | 'failed' | 'sent' | 'delivered' | 'seen';

export interface Attachment {
  url: string;
  name: string;
  mime: string;
  size: number;
  kind: 'image' | 'file' | 'audio';
}

export interface Reaction {
  emoji: string;
  username: string;
}

export interface PollOption {
  id: string;
  text: string;
  votes: string[];
}

export interface Poll {
  id: string;
  question: string;
  options: PollOption[];
  totalVotes: number;
}

export type GameType = 'tictactoe' | 'rps' | 'connect4';

export interface GameData {
  id: string;
  gameType: GameType;
  title: string;
  createdBy: string;
  opponent?: string;
  state: 'waiting' | 'in_progress' | 'finished';
  turn: string;
  winner?: string | 'draw';
  data: {
    board?: (string | null)[];
    playerX?: string;
    playerO?: string;
    player1?: string;
    player2?: string;
    p1Move?: 'rock' | 'paper' | 'scissors';
    p2Move?: 'rock' | 'paper' | 'scissors';
    winningLine?: number[];
    movesCount?: number;
  };
  lastMoveBy?: string;
  updatedAt?: number;
}

export interface Message {
  id: string;
  sender: string;
  receiver: string;
  text: string;
  timestamp: string | number;
  status: MessageStatus;
  sendError?: string;
  attachment?: Attachment | null;
  replyTo?: {
    id: string;
    sender: string;
    text: string;
    attachment?: Attachment | null;
  } | null;
  reactions?: Record<string, string[]>; // emoji -> [usernames]
  isVoice?: boolean;
  voiceDuration?: number;
  pinnedAt?: string | null;
  pinnedBy?: string;
  expiresAt?: string | null;
  poll?: Poll | null;
  game?: GameData | null;
  ciphertext?: string;
  iv?: string;
  isEncrypted?: boolean;
}

export interface UserProfile {
  username: string;
  displayName?: string;
  email?: string;
  avatarId?: string;
  bio?: string;
  age?: string;
  gender?: string;
  online?: boolean;
  lastSeenAt?: string;
  presenceMode?: 'online' | 'away' | 'busy' | 'invisible' | 'dnd' | 'offline';
  publicKey?: string;
  retentionDays?: 7 | 15 | 30;
  callPrivacy?: 'everyone' | 'friends' | 'nobody';
  messagePrivacy?: 'everyone' | 'friends' | 'nobody';
  profilePhotoPrivacy?: 'everyone' | 'friends' | 'nobody';
  presencePrivacy?: 'everyone' | 'friends' | 'nobody';
  readReceiptsEnabled?: boolean;
  typingIndicatorsEnabled?: boolean;
  groupInvitePrivacy?: 'everyone' | 'friends' | 'nobody';
  friendRequestPrivacy?: 'everyone' | 'mutuals' | 'nobody';
}

export interface Conversation {
  username: string;
  displayName: string;
  avatarId?: string;
  lastMessage?: Message;
  unreadCount: number;
  online: boolean;
  presence?: 'online' | 'away' | 'busy' | 'invisible' | 'dnd' | 'offline';
  lastSeenAt?: string;
  typing?: boolean;
  bio?: string;
  isGroup?: boolean;
  groupId?: string;
  memberCount?: number;
  owner?: string;
  members?: string[];
  publicKey?: string;
  /** Built-in private notes conversation addressed to the signed-in user. */
  isSelf?: boolean;
  /** False when this is a direct message thread without a friend connection. */
  isFriend?: boolean;
}

export interface FriendRequest {
  from: string;
  timestamp: string;
  displayName?: string;
}

export type ActiveTab = 'chats' | 'calls' | 'contacts' | 'settings';

export interface CallState {
  callId?: string;
  isActive: boolean;
  isIncoming: boolean;
  remoteUser: string;
  remoteDisplayName?: string;
  isVideo: boolean;
  isMuted: boolean;
  isCameraOff: boolean;
  isScreenSharing?: boolean;
  /** The other participant is presenting a display rather than their camera. */
  remoteIsScreenSharing?: boolean;
  status: 'idle' | 'calling' | 'ringing' | 'connected' | 'ended';
  localStream?: MediaStream | null;
  remoteStream?: MediaStream | null;
}

export interface CallLog {
  id: string;
  partner: string;
  partnerDisplayName?: string;
  partnerAvatarId?: string;
  type: 'incoming' | 'outgoing' | 'missed';
  isVideo: boolean;
  timestamp: string | number;
  duration?: number;
}
