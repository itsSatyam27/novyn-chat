import React from 'react';
import { useChat } from '../../context/ChatContext';
import { NavDock, NavTab } from './NavDock';

interface BottomNavProps {
  activeTab: NavTab;
  onSelectTab: (tab: NavTab) => void;
}

export const BottomNav: React.FC<BottomNavProps> = ({ activeTab, onSelectTab }) => {
  const { friendRequests, activeChat, conversations } = useChat();
  if (activeChat && activeTab === 'chats') return null;
  return (
    <NavDock className="mobile-bottom-nav" activeTab={activeTab} onSelectTab={onSelectTab} requestCount={friendRequests.length} unreadCount={conversations.reduce((sum, chat) => sum + chat.unreadCount, 0)} />
  );
};
