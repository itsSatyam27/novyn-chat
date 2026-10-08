import React from 'react';
import { useChat } from '../../context/ChatContext';
import { NavDock, NavTab } from './NavDock';
export { NAV_ITEMS } from './NavDock';
export type { NavTab } from './NavDock';

interface SidebarProps {
  activeTab: NavTab;
  onSelectTab: (tab: NavTab) => void;
  onToggleList: () => void;
  isListCollapsed?: boolean;
}

export const Sidebar: React.FC<SidebarProps> = ({ activeTab, onSelectTab }) => {
  const { friendRequests, conversations, unreadMissedCallCount } = useChat();
  return (
    <NavDock className="desktop-sidebar" activeTab={activeTab} onSelectTab={onSelectTab} requestCount={friendRequests.length} missedCallCount={unreadMissedCallCount} unreadCount={conversations.reduce((sum, chat) => sum + chat.unreadCount, 0)} />
  );
};
