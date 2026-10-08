import React, { Suspense } from 'react';
import { AuthProvider } from './context/AuthContext';
import { ChatProvider } from './context/ChatContext';
import { AppLayout } from './components/layout/AppLayout';
import { MotionConfig } from 'framer-motion';
import { useBrowserPreference } from './services/browserPreferences';

export const App: React.FC = () => {
  const reducedMotion = useBrowserPreference('novyn_reduce_motion', 'false') === 'true';
  // Refresh visible timestamps when preferences change, including in another tab.
  useBrowserPreference('novyn_time_zone_mode', 'auto');
  useBrowserPreference('novyn_time_zone', '');
  useBrowserPreference('novyn_settings_language', 'en');
  useBrowserPreference('novyn_region', 'IN');
  return (
    <MotionConfig reducedMotion={reducedMotion ? 'always' : 'user'}>
    <AuthProvider>
      <ChatProvider>
        <Suspense fallback={<div role="status" style={{ padding: 24 }}>Loading Novyn…</div>}>
          <AppLayout />
        </Suspense>
      </ChatProvider>
    </AuthProvider>
    </MotionConfig>
  );
};
