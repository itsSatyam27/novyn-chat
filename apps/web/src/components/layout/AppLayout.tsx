import { ContactsDashboard } from '../contacts/ContactsDashboard';
import React, { lazy, Suspense, useState, useEffect } from 'react';
import { useAuth } from '../../context/AuthContext';
import { useChat } from '../../context/ChatContext';
const LandingPage = lazy(() => import('../landing/LandingPage').then((m) => ({ default: m.LandingPage })));
const AuthModal = lazy(() => import('../auth/AuthModal').then((m) => ({ default: m.AuthModal })));
import { Sidebar, NavTab } from './Sidebar';
import { BottomNav } from './BottomNav';
import { ConnectionNotice } from './ConnectionNotice';
import { TabWelcome } from './TabWelcome';
import { ChatList } from '../chat/ChatList';
import { MessagesWorkspace } from '../chat/MessagesWorkspace';
const ChatWindow = lazy(() => import('../chat/ChatWindow').then((m) => ({ default: m.ChatWindow })));
import { CallsPanel } from '../calls/CallsPanel';
import { CallsWorkspace } from '../calls/CallsWorkspace';
import { DiscoverPanel } from '../discover/DiscoverPanel';
import { DiscoverWorkspace } from '../discover/DiscoverWorkspace';
import { ContactsPanel } from '../contacts/ContactsPanel';
import { SettingsPanel, SettingsMainCategory, SettingsSubSection } from '../settings/SettingsPanel';
import { SettingsSubPanel } from '../settings/SettingsSubPanel';
const SettingsDetailView = lazy(() => import('../settings/SettingsDetailView').then((m) => ({ default: m.SettingsDetailView })));
const CallModal = lazy(() => import('../calls/CallModal').then((m) => ({ default: m.CallModal })));
import { setupMobileEnvironment } from '../../services/capacitor';
import { NovynLogo } from '../ui/NovynLogo';

const DEFAULT_PANEL_WIDTH = 340;

export const AppLayout: React.FC = () => {
  const { isAuthenticated, isLoading } = useAuth();
  const { activeChat, blockedUsers, markMissedCallsRead, callLogs } = useChat();
  const [activeTab, setActiveTab] = useState<NavTab>('chats');
  const [settingsCategory, setSettingsCategory] = useState<SettingsMainCategory>('profile');
  const [settingsSubSection, setSettingsSubSection] = useState<SettingsSubSection>('profile-details');
  const [isListCollapsed, setIsListCollapsed] = useState(false);
  const [isAuthOpen, setIsAuthOpen] = useState(false);
  const [authMode, setAuthMode] = useState<'signin' | 'signup'>('signin');
  const [isMobileSettingsDetailOpen, setIsMobileSettingsDetailOpen] = useState(false);
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  useEffect(() => {
    if (activeTab === 'calls') markMissedCallsRead();
  }, [activeTab, callLogs, markMissedCallsRead]);

  // The navigation panel stays a stable width. Users can collapse it with the
  // adjacent control, rather than accidentally resizing it while scrolling.
  const panelWidth = DEFAULT_PANEL_WIDTH;
  const isCompact = false;

  useEffect(() => {
    setupMobileEnvironment();
    const viewport = window.visualViewport;
    const updateViewport = () => document.documentElement.style.setProperty('--visible-viewport-height', `${viewport?.height || window.innerHeight}px`);
    updateViewport();
    viewport?.addEventListener('resize', updateViewport);
    window.addEventListener('resize', updateViewport);
    return () => {
      viewport?.removeEventListener('resize', updateViewport);
      window.removeEventListener('resize', updateViewport);
      document.documentElement.style.removeProperty('--visible-viewport-height');
    };
  }, []);

  if (isLoading) {
    return (
      <div style={{ display: 'flex', height: '100vh', width: '100vw', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-surface)', color: 'var(--text-main)' }}>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '16px' }}>
          <NovynLogo size={42} variant="white" withBadge badgeSize={76} />
          <span style={{ fontSize: '0.82rem', fontWeight: 800, color: '#0e9f8a', letterSpacing: '0.12em', textTransform: 'uppercase' }}>
            Loading Novyn...
          </span>
        </div>
      </div>
    );
  }

  // Unauthenticated landing & auth modal flow
  if (!isAuthenticated) {
    return (
      <>
        <LandingPage
          onOpenAuth={(mode = 'signin') => {
            setAuthMode(mode);
            setIsAuthOpen(true);
          }}
        />
        <AuthModal
          isOpen={isAuthOpen}
          initialMode={authMode}
          onClose={() => setIsAuthOpen(false)}
        />
      </>
    );
  }


  return (
    <div className="app-container" data-tab={activeTab} style={{ '--navigation-panel-width': isListCollapsed ? '0px' : `${panelWidth}px` } as React.CSSProperties}>
      <ConnectionNotice />
      {/* 1. Desktop Sidebar Navigation (Column 1) */}
      <Sidebar
        activeTab={activeTab}
        onSelectTab={(tab) => {
          setActiveTab(tab);
          setIsListCollapsed(false);
          setIsMobileSettingsDetailOpen(false);
        }}
        onToggleList={() => setIsListCollapsed((prev) => !prev)}
        isListCollapsed={isListCollapsed}
      />

      {/* 2. Middle Navigation Pane (Column 2: Chats / Calls / Discover / Contacts / Settings Categories) */}
      {!isListCollapsed && (
        <div
          style={{
            display:
              (activeChat && activeTab === 'chats') ||
              (activeTab === 'settings' && isMobileSettingsDetailOpen && windowWidth <= 768)
                ? 'none'
                : 'flex',
            height: '100%',
            width: windowWidth <= 768 ? '100%' : `${panelWidth}px`,
            minWidth: windowWidth <= 768 ? '100%' : `${panelWidth}px`,
            maxWidth: windowWidth <= 768 ? '100%' : `${panelWidth}px`,
            transition: 'width 0.18s ease',
            overflow: 'hidden',
          }}
          className="sm-flex-always navigation-pane"
        >
          {activeTab === 'chats' && (
            <ChatList
              onOpenContacts={() => setActiveTab('contacts')}
              isCompact={isCompact}
            />
          )}
          {activeTab === 'calls' && <CallsPanel isCompact={isCompact} onOpenContacts={() => setActiveTab('contacts')} />}
          {activeTab === 'discover' && <DiscoverPanel isCompact={isCompact} onOpenChat={() => setActiveTab('chats')} />}
          {activeTab === 'contacts' && <ContactsPanel isCompact={isCompact} onOpenChat={() => setActiveTab('chats')} />}
          {activeTab === 'settings' && (
            <SettingsPanel
              activeSubSection={settingsSubSection}
              onSelectCategory={(cat, defaultSub) => {
                setSettingsCategory(cat);
                setSettingsSubSection(defaultSub);
                setIsMobileSettingsDetailOpen(true);
              }}
              isCompact={isCompact}
            />
          )}
        </div>
      )}

      {/* 3 & 4. Right Active Main Area (Settings Dual Screen 50/50 or Chat Window) */}
      <div
        style={{
          flex: 1,
          height: '100%',
          display:
            windowWidth > 768 ||
            (activeChat && activeTab === 'chats') ||
            isListCollapsed ||
            (activeTab === 'settings' && isMobileSettingsDetailOpen)
              ? 'flex'
              : 'none',
          minWidth: 0,
        }}
        className="sm-flex-always workspace-pane"
      >
        {/* Lazy screens must not hide the dock while their code is loading. */}
        <Suspense fallback={<div role="status" style={{ padding: 24, color: 'var(--text-muted)' }}>Loading view…</div>}>
        {activeTab === 'settings' ? (
          <div className="settings-workspace">
              {!settingsSubSection.startsWith('privacy-') && !['feedback-send', 'feedback-bug', 'feedback-feature', 'appear-accessibility', 'storage-cache', 'storage-export', 'storage-security', 'profile-details', 'appear-language', 'appear-theme', 'notif-sounds', 'notif-calls', 'notif-previews'].includes(settingsSubSection) && <SettingsSubPanel
                activeCategory={settingsCategory}
                activeSubSection={settingsSubSection}
                onSelectSubSection={setSettingsSubSection}
                blockedCount={blockedUsers.size}
                onBack={windowWidth <= 768 ? () => setIsMobileSettingsDetailOpen(false) : undefined}
              />}
            <SettingsDetailView
              activeSubSection={settingsSubSection}
              isVisible={windowWidth > 768 || isMobileSettingsDetailOpen}
              onSelectSection={(category, section) => { setSettingsCategory(category); setSettingsSubSection(section); }}
              onBack={windowWidth <= 768 && (settingsSubSection.startsWith('privacy-') || ['feedback-send', 'feedback-bug', 'feedback-feature', 'appear-accessibility', 'storage-cache', 'storage-export', 'storage-security', 'profile-details', 'appear-language', 'appear-theme', 'notif-sounds', 'notif-calls', 'notif-previews'].includes(settingsSubSection)) ? () => setIsMobileSettingsDetailOpen(false) : undefined}
            />
          </div>
        ) : activeTab === 'calls' ? <CallsWorkspace onOpenContacts={() => setActiveTab('contacts')} /> : activeTab === 'contacts' ? <ContactsDashboard onOpenChat={() => setActiveTab('chats')} /> : activeTab === 'chats' && !activeChat ? (
          <MessagesWorkspace />
        ) : activeTab === 'discover' ? (
          <DiscoverWorkspace />
        ) : activeTab !== 'chats' || !activeChat ? (
          <TabWelcome tab={activeTab} onAction={() => {
            setActiveTab('contacts');
            setIsListCollapsed(false);
          }} />
        ) : (
          <ChatWindow
            isListCollapsed={isListCollapsed}
            onToggleList={() => setIsListCollapsed((prev) => !prev)}
            onStartChat={() => { setActiveTab('contacts'); setIsListCollapsed(false); }}
          />
        )}
        </Suspense>
      </div>

      {/* 5. Mobile Bottom Navigation */}
      <BottomNav
        activeTab={activeTab}
        onSelectTab={(tab) => {
          setActiveTab(tab);
          setIsListCollapsed(false);
          setIsMobileSettingsDetailOpen(false);
        }}
      />

      {/* WebRTC Audio/Video Call Overlay */}
      <CallModal />
    </div>
  );
};
