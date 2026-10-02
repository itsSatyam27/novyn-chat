import React, { createContext, useContext, useState, useEffect } from 'react';
import { UserProfile } from '../types';
import { apiRequest } from '../services/api';
import { connectSocket, disconnectSocket } from '../services/socket';
import { triggerHaptic } from '../services/capacitor';

interface AuthContextType {
  user: UserProfile | null;
  setUser: React.Dispatch<React.SetStateAction<UserProfile | null>>;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (payload: { identifier: string; password: string; remember?: boolean }) => Promise<{ ok: boolean; error?: string }>;
  signup: (payload: { name: string; username: string; email: string; password: string }) => Promise<{ ok: boolean; error?: string }>;
  loginWithGoogle: () => Promise<{ ok: boolean; error?: string }>;
  logout: () => Promise<void>;
  refreshSession: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<UserProfile | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const refreshSession = async () => {
    try {
      const res = await apiRequest('/api/auth/session');
      if (res.ok && res.data?.username) {
        setUser({
          username: res.data.username,
          displayName: res.data.displayName || res.data.username,
          email: res.data.email,
          avatarId: res.data.avatarId || '',
          bio: res.data.bio || '',
          presenceMode: res.data.presenceMode || 'online',
          retentionDays: res.data.retentionDays,
        });
        connectSocket();
      } else {
        // Try refresh token
        const refreshRes = await apiRequest('/api/auth/refresh', { method: 'POST' });
        if (refreshRes.ok) {
          const secondSession = await apiRequest('/api/auth/session');
          if (secondSession.ok && secondSession.data?.username) {
            setUser({
              username: secondSession.data.username,
              displayName: secondSession.data.displayName || secondSession.data.username,
              email: secondSession.data.email,
              avatarId: secondSession.data.avatarId || '',
              bio: secondSession.data.bio || '',
              presenceMode: secondSession.data.presenceMode || 'online',
              retentionDays: secondSession.data.retentionDays,
            });
            connectSocket();
          }
        }
      }
    } catch {
      setUser(null);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    refreshSession();
  }, []);

  const login = async ({ identifier, password, remember = true }: { identifier: string; password: string; remember?: boolean }) => {
    const res = await apiRequest('/api/auth/signin', {
      method: 'POST',
      body: JSON.stringify({ identifier, password, remember }),
    });

    if (res.ok && res.data?.username) {
      setUser({
        username: res.data.username,
        displayName: res.data.username,
        email: res.data.email,
      });
      triggerHaptic('success');
      disconnectSocket();
      connectSocket();
      return { ok: true };
    }

    triggerHaptic('error');
    return { ok: false, error: res.data?.message || res.data?.error || 'Login failed' };
  };

  const signup = async ({ name, username, email, password }: { name: string; username: string; email: string; password: string }) => {
    const res = await apiRequest('/api/auth/signup', {
      method: 'POST',
      body: JSON.stringify({ name, username, email, password }),
    });

    if (res.ok && res.data?.username) {
      setUser({
        username: res.data.username,
        displayName: name || res.data.username,
        email,
      });
      triggerHaptic('success');
      disconnectSocket();
      connectSocket();
      return { ok: true };
    }

    triggerHaptic('error');
    return { ok: false, error: res.data?.message || res.data?.error || 'Registration failed' };
  };

  const loginWithGoogle = async () => {
    try {
      const { loginWithGooglePopup } = await import('../services/firebase');
      const googleData = await loginWithGooglePopup();
      if (!googleData?.idToken) {
        return { ok: false, error: 'Google sign-in token missing' };
      }

      const res = await apiRequest('/api/auth/google', {
        method: 'POST',
        body: JSON.stringify({ idToken: googleData.idToken, remember: true }),
      });

      if (res.ok && res.data?.username) {
        setUser({
          username: res.data.username,
          displayName: res.data.displayName || res.data.username,
          email: res.data.email,
        });
        triggerHaptic('success');
        disconnectSocket();
        connectSocket();
        return { ok: true };
      }

      triggerHaptic('error');
      const errorMsg = res.data?.message || res.data?.error || (res.status === 503 ? 'Firebase Admin not configured on server' : `Google sign-in rejected (${res.status || 'server error'})`);
      return { ok: false, error: errorMsg };
    } catch (err: any) {
      triggerHaptic('error');
      return { ok: false, error: err?.message || 'Google sign-in error' };
    }
  };

  const logout = async () => {
    try {
      await apiRequest('/api/auth/logout', { method: 'POST' });
    } finally {
      setUser(null);
      disconnectSocket();
      triggerHaptic('medium');
    }
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        setUser,
        isAuthenticated: !!user,
        isLoading,
        login,
        signup,
        loginWithGoogle,
        logout,
        refreshSession,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
