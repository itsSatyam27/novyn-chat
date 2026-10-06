import React, { Suspense } from 'react';
import { AuthProvider } from './context/AuthContext';
import { ChatProvider } from './context/ChatContext';
import { AppLayout } from './components/layout/AppLayout';

export const App: React.FC = () => {
  return (
    <AuthProvider>
      <ChatProvider>
        <Suspense fallback={<div role="status" style={{ padding: 24 }}>Loading Novyn…</div>}>
          <AppLayout />
        </Suspense>
      </ChatProvider>
    </AuthProvider>
  );
};
