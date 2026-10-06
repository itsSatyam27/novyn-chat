import React from 'react';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { MessageCircle, Phone, Compass, UserRound, Plus, ArrowUpRight, RefreshCw } from 'lucide-react';

type WelcomeTab = 'chats' | 'calls' | 'discover' | 'contacts';
const content = {
  chats: { eyebrow: 'A SPACE TO CONNECT', title: 'Good conversations start here', description: 'A quick hello, a shared idea, or a little catch-up. Make room for your people.', action: 'New message', icon: MessageCircle, actionIcon: Plus },
  calls: { eyebrow: 'MORE THAN WORDS', title: 'Closer, even from afar', description: 'Hear a familiar voice or share a face-to-face moment. Choose a contact to get started.', action: 'Choose a contact', icon: Phone, actionIcon: ArrowUpRight },
  discover: { eyebrow: 'SOMETHING NEW AWAITS', title: 'Find your next connection', description: 'See who’s online, send a friend request, and let a new conversation unfold.', action: 'Refresh people', icon: Compass, actionIcon: RefreshCw },
  contacts: { eyebrow: 'YOUR OWN LITTLE CIRCLE', title: 'Your people, in one place', description: 'Keep familiar faces close. Find a friend, manage requests, or welcome someone new.', action: 'Add a friend', icon: UserRound, actionIcon: Plus },
};

export const TabWelcome: React.FC<{ tab: WelcomeTab; onAction?: () => void }> = ({ tab, onAction }) => {
  const reducedMotion = useReducedMotion();
  const { eyebrow, title, description, action, icon: Icon, actionIcon: ActionIcon } = content[tab];
  return <div className="tab-welcome" data-welcome-tab={tab}>
    <AnimatePresence mode="wait" initial={false}>
      <motion.section key={tab} className="tab-welcome-content"
        initial={{ opacity: 0, y: reducedMotion ? 0 : 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: reducedMotion ? 0 : -6 }}
        transition={{ duration: reducedMotion ? 0 : 0.18 }} aria-label={`${tab} overview`}>
        <div className={`welcome-art welcome-art-${tab}`} aria-hidden="true">
          <div className="welcome-halo" />
          {tab === 'chats' && <><span className="welcome-message-secondary"><MessageCircle size={38} strokeWidth={1.4} /></span><span className="welcome-dots">•••</span></>}
          {tab === 'calls' && <><span className="welcome-ring ring-one" /><span className="welcome-ring ring-two" /><span className="welcome-wave"><i /><i /><i /><i /><i /></span></>}
          {tab === 'discover' && <svg className="welcome-constellation" viewBox="0 0 280 220"><path d="M35 140L90 45L195 30L245 115L205 185L80 190Z M35 140L140 110L195 30 M140 110L205 185 M90 45L245 115" /><circle cx="35" cy="140" r="5" /><circle cx="90" cy="45" r="7" /><circle cx="195" cy="30" r="4" /><circle cx="245" cy="115" r="6" /><circle cx="205" cy="185" r="5" /><circle cx="80" cy="190" r="4" /></svg>}
          {tab === 'contacts' && <><span className="welcome-person person-left"><UserRound size={30} strokeWidth={1.4} /></span><span className="welcome-person person-right"><UserRound size={30} strokeWidth={1.4} /></span></>}
          <span className="welcome-icon"><Icon size={43} strokeWidth={1.5} /></span>
        </div>
        <p className="welcome-eyebrow">{eyebrow}</p>
        <h2>{title}</h2>
        <p className="welcome-description">{description}</p>
        {onAction && <button type="button" className="welcome-action" onClick={onAction}><ActionIcon size={17} aria-hidden="true" />{action}</button>}
      </motion.section>
    </AnimatePresence>
  </div>;
};
