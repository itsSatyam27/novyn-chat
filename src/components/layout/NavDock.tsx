import React, { useEffect, useRef, useState } from 'react';
import { MessageSquare, Phone, Compass, Users, Settings } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';
import { useDockAlwaysVisible } from '../../services/dockPreferences';

export type NavTab = 'chats' | 'calls' | 'discover' | 'contacts' | 'settings';

export const NAV_ITEMS = [
  { id: 'chats', label: 'Chats', icon: MessageSquare },
  { id: 'calls', label: 'Calls', icon: Phone },
  { id: 'discover', label: 'Discover', icon: Compass },
  { id: 'contacts', label: 'Contacts', icon: Users },
  { id: 'settings', label: 'Settings', icon: Settings },
] satisfies { id: NavTab; label: string; icon: typeof MessageSquare }[];

interface NavDockProps {
  activeTab: NavTab;
  onSelectTab: (tab: NavTab) => void;
  className: string;
  requestCount: number;
  unreadCount?: number;
}

// A single persistent pill slides between slots. Equal expanded widths keep the
// dock centered, and CSS transitions can reverse immediately during rapid taps.
export const NavDock: React.FC<NavDockProps> = ({ activeTab, onSelectTab, className, requestCount, unreadCount = 0 }) => {
  const alwaysVisible = useDockAlwaysVisible();
  const [phase, setPhase] = useState<'expanded' | 'compact' | 'tucked'>('expanded');
  const [hovered, setHovered] = useState(false);
  const [focused, setFocused] = useState(false);
  const [activity, setActivity] = useState(0);
  const dockRef = useRef<HTMLElement>(null);
  const reveal = () => { setPhase('expanded'); setActivity((value) => value + 1); };

  useEffect(() => {
    setPhase('expanded');
    if (alwaysVisible || hovered || focused) return;
    const compact = window.setTimeout(() => setPhase('compact'), 2500);
    const tucked = window.setTimeout(() => setPhase('tucked'), 3250);
    return () => { window.clearTimeout(compact); window.clearTimeout(tucked); };
  }, [activeTab, alwaysVisible, hovered, focused, activity]);

  return (
  <nav
    ref={dockRef}
    className={`${className} glass-dock`}
    aria-label="Main navigation"
    data-phase={phase}
    onPointerEnter={(event) => { if (event.pointerType === 'mouse') { setHovered(true); reveal(); } }}
    onPointerLeave={(event) => { if (event.pointerType === 'mouse') setHovered(false); }}
    onPointerDown={() => setFocused(false)}
    onFocusCapture={(event) => {
      if (event.target.matches(':focus-visible')) { setFocused(true); reveal(); }
    }}
    onBlurCapture={(event) => {
      if (!event.currentTarget.contains(event.relatedTarget)) setFocused(false);
    }}
    onKeyDown={() => { setFocused(true); reveal(); }}
    style={{ '--dock-active-index': NAV_ITEMS.findIndex(({ id }) => id === activeTab) } as React.CSSProperties}
  >
    <button
      type="button"
      className="dock-reveal"
      aria-label={`Show navigation${requestCount + unreadCount > 0 ? ', new activity' : ''}`}
      aria-expanded={phase === 'expanded'}
      tabIndex={phase === 'expanded' ? -1 : 0}
      onClick={reveal}
      onFocus={(event) => {
        if (event.target.matches(':focus-visible')) {
          reveal();
          dockRef.current?.querySelector<HTMLButtonElement>('[aria-current="page"]')?.focus();
        }
      }}
    >
      <span className="dock-reveal-bar" />
      {requestCount + unreadCount > 0 && <span className="dock-reveal-dot" />}
    </button>
    <div className="dock-surface" aria-hidden={phase !== 'expanded'}>
    <span className="dock-active-pill" aria-hidden="true" />
    {NAV_ITEMS.map(({ id, label, icon: Icon }) => (
      <button
        key={id}
        type="button"
        className={`dock-item ${activeTab === id ? 'active' : ''}`}
        aria-label={label}
        aria-current={activeTab === id ? 'page' : undefined}
        title={label}
        tabIndex={phase === 'expanded' ? 0 : -1}
        onClick={() => {
          reveal();
          if (activeTab === id) return;
          triggerHaptic('light');
          onSelectTab(id);
        }}
      >
        <Icon size={18} aria-hidden="true" />
        <span className="dock-label" aria-hidden="true">{label}</span>
        {id === 'contacts' && requestCount > 0 && <span className="dock-badge" aria-label={`${requestCount} friend requests`} />}
      </button>
    ))}
    </div>
  </nav>
  );
};
