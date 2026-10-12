import { ContactsDashboard } from '../contacts/ContactsDashboard';
import React, { lazy, Suspense, useState, useEffect, useRef } from 'react';
import { useAuth } from '../../context/AuthContext';
import { useChat } from '../../context/ChatContext';
const LandingPage = lazy(() => import('../landing/LandingPage').then((m) => ({ default: m.LandingPage })));
const AuthModal = lazy(() => import('../auth/AuthModal').then((m) => ({ default: m.AuthModal })));
const MobileAuthPage = lazy(() => import('../auth/MobileAuthPage').then((m) => ({ default: m.MobileAuthPage })));
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
import { SettingsPanel, SettingsSubSection } from '../settings/SettingsPanel';
const SettingsDetailView = lazy(() => import('../settings/SettingsDetailView').then((m) => ({ default: m.SettingsDetailView })));
const CallModal = lazy(() => import('../calls/CallModal').then((m) => ({ default: m.CallModal })));
import { setupMobileEnvironment } from '../../services/capacitor';
import { NovynLogo } from '../ui/NovynLogo';
import { SettingsToast } from '../settings/SettingsToast';
import { parseHash, subSectionToSlug } from '../../services/router';
import { handleModalPopState } from '../../services/modalStack';
import { AppLockOverlay } from './AppLockOverlay';

const DEFAULT_PANEL_WIDTH = 340;

export const AppLayout: React.FC = () => {
  const { isAuthenticated, isLoading } = useAuth();
  const { activeChat, setActiveChat, markMissedCallsRead, callLogs, callNotice, dismissCallNotice, conversations, unreadMissedCallCount } = useChat();

  const [initialRoute] = useState(() => parseHash());
  const [activeTab, setActiveTab] = useState<NavTab>(() => initialRoute.tab);
  const [settingsSubSection, setSettingsSubSection] = useState<SettingsSubSection>(() =>
    initialRoute.tab === 'settings' ? initialRoute.subSection : 'profile-details'
  );
  const [isListCollapsed, setIsListCollapsed] = useState(false);
  const [isAuthOpen, setIsAuthOpen] = useState(false);
  const [authMode, setAuthMode] = useState<'signin' | 'signup'>('signin');
  const [showDesktopLandingOnMobile, setShowDesktopLandingOnMobile] = useState(false);
  const [isMobileSettingsDetailOpen, setIsMobileSettingsDetailOpen] = useState<boolean>(() =>
    initialRoute.tab === 'settings' ? Boolean(initialRoute.isDetailOpen) : false
  );
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);
  const isMobile = windowWidth <= 768;

  const isInternalNavRef = useRef(false);

  // Restore initial chat if specified in deep link
  useEffect(() => {
    if (initialRoute.tab === 'chats' && initialRoute.chat && isAuthenticated) {
      setActiveChat(initialRoute.chat);
    }
  }, [isAuthenticated, initialRoute, setActiveChat]);

  // Handle browser Back / Forward buttons and mobile gestures
  useEffect(() => {
    const handlePopState = () => {
      if (isInternalNavRef.current) return;
      // If an open modal was dismissed by Back button, do not navigate the underlying page
      if (handleModalPopState()) return;

      const route = parseHash();
      setActiveTab(route.tab);
      if (route.tab === 'chats') {
        setActiveChat(route.chat);
      } else {
        setActiveChat(null);
      }
      if (route.tab === 'settings') {
        setSettingsSubSection(route.subSection);
        setIsMobileSettingsDetailOpen(Boolean(route.isDetailOpen));
      } else {
        setIsMobileSettingsDetailOpen(false);
      }
    };

    window.addEventListener('popstate', handlePopState);
    window.addEventListener('hashchange', handlePopState);
    return () => {
      window.removeEventListener('popstate', handlePopState);
      window.removeEventListener('hashchange', handlePopState);
    };
  }, [setActiveChat]);

  const totalUnreadMessages = conversations.reduce((acc, conv) => acc + (conv.unreadCount || 0), 0);

  // Dynamic document.title synchronization
  useEffect(() => {
    if (!isAuthenticated) {
      document.title = 'Novyn Chat';
      return;
    }
    let title = 'Novyn Chat';
    if (activeTab === 'chats') {
      if (activeChat) {
        title = `${activeChat} — Novyn Chat`;
      } else {
        title = totalUnreadMessages > 0 ? `(${totalUnreadMessages}) Novyn Chat` : 'Novyn Chat';
      }
    } else if (activeTab === 'calls') {
      title = unreadMissedCallCount > 0 ? `(${unreadMissedCallCount}) Calls — Novyn` : 'Calls — Novyn';
    } else if (activeTab === 'contacts') {
      title = 'Contacts — Novyn';
    } else if (activeTab === 'discover') {
      title = 'Discover — Novyn';
    } else if (activeTab === 'settings') {
      const sectionName =
        settingsSubSection === 'security-dashboard' ? 'Security' :
        settingsSubSection === 'profile-details' ? 'Profile' :
        settingsSubSection.startsWith('privacy-') ? 'Privacy & Security' :
        settingsSubSection.startsWith('appear-') ? 'Appearance' :
        settingsSubSection.startsWith('notif-') ? 'Notifications' :
        settingsSubSection.startsWith('storage-') ? 'Storage' : 'Settings';
      title = `${sectionName} — Novyn Settings`;
    }
    document.title = title;
  }, [isAuthenticated, activeTab, activeChat, settingsSubSection, totalUnreadMessages, unreadMissedCallCount]);

  // Synchronize internal state changes with browser URL and history
  useEffect(() => {
    if (!isAuthenticated) return;
    let targetHash: string;
    if (activeTab === 'chats') {
      targetHash = activeChat ? `#/chats/${encodeURIComponent(activeChat)}` : '#/chats';
    } else if (activeTab === 'calls') {
      targetHash = '#/calls';
    } else if (activeTab === 'contacts') {
      targetHash = '#/contacts';
    } else if (activeTab === 'discover') {
      targetHash = '#/discover';
    } else {
      if (windowWidth <= 768 && !isMobileSettingsDetailOpen) {
        targetHash = '#/settings';
      } else {
        targetHash = `#/settings/${subSectionToSlug(settingsSubSection)}`;
      }
    }

    if (window.location.hash !== targetHash) {
      isInternalNavRef.current = true;
      window.history.pushState(null, '', targetHash);
      setTimeout(() => {
        isInternalNavRef.current = false;
      }, 50);
    }
  }, [isAuthenticated, activeTab, activeChat, settingsSubSection, isMobileSettingsDetailOpen, windowWidth]);

  // Escape key handler for desktop & tablet keyboards
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (activeChat) {
          if (window.history.length > 1) window.history.back();
          else setActiveChat(null);
        } else if (isMobileSettingsDetailOpen) {
          if (window.history.length > 1) window.history.back();
          else setIsMobileSettingsDetailOpen(false);
        }
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [activeChat, isMobileSettingsDetailOpen, setActiveChat]);

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
    if (isMobile && !showDesktopLandingOnMobile) {
      return (
        <Suspense fallback={null}>
          <MobileAuthPage
            initialMode={authMode}
            onSwitchToDesktopLanding={() => setShowDesktopLandingOnMobile(true)}
          />
        </Suspense>
      );
    }

    return (
      <Suspense fallback={null}>
        {isMobile && showDesktopLandingOnMobile && (
          <header className="mobile-landing-return-bar">
            <button
              type="button"
              onClick={() => setShowDesktopLandingOnMobile(false)}
              className="mobile-landing-return-btn"
            >
              ← Back to Sign In / Sign Up
            </button>
            <span className="mobile-landing-return-tag">Novyn Web</span>
          </header>
        )}
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
      </Suspense>
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
              onSelectCategory={(_cat, defaultSub) => {
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
            <SettingsDetailView
              activeSubSection={settingsSubSection}
              isVisible={windowWidth > 768 || isMobileSettingsDetailOpen}
              onSelectSection={(_category, section) => { setSettingsSubSection(section); }}
              onBack={windowWidth <= 768 && isMobileSettingsDetailOpen ? () => {
                setIsMobileSettingsDetailOpen(false);
              } : undefined}
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
      {callNotice && <SettingsToast notice={callNotice} onDismiss={dismissCallNotice} />}
      <CallModal />

      {/* Screen Passcode & App Lock Shield */}
      <AppLockOverlay />
    </div>
  );
};
