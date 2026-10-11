import React, { useState, useEffect } from 'react';
import { Lock, Delete } from 'lucide-react';
import { isAppLocked, verifyAppLockPin, unlockApp, subscribeAppLock } from '../../services/appLock';
import { triggerHaptic } from '../../services/capacitor';
import { useAuth } from '../../context/AuthContext';
import { Avatar } from '../ui/Avatar';
import './appLockOverlay.css';

export const AppLockOverlay: React.FC = () => {
  const { user } = useAuth();
  const [locked, setLocked] = useState(() => isAppLocked());
  const [pin, setPin] = useState('');
  const [isError, setIsError] = useState(false);

  useEffect(() => {
    return subscribeAppLock(() => {
      setLocked(isAppLocked());
      if (!isAppLocked()) {
        setPin('');
        setIsError(false);
      }
    });
  }, []);

  // Keyboard listener when locked
  useEffect(() => {
    if (!locked) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (/^[0-9]$/.test(e.key)) {
        e.preventDefault();
        handleDigit(e.key);
      } else if (e.key === 'Backspace') {
        e.preventDefault();
        handleBackspace();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [locked, pin, isError]);

  const handleDigit = async (digit: string) => {
    if (isError || pin.length >= 4) return;
    const nextPin = pin + digit;
    setPin(nextPin);
    triggerHaptic('light');

    if (nextPin.length === 4) {
      const ok = await verifyAppLockPin(nextPin);
      if (ok) {
        triggerHaptic('success');
        unlockApp();
      } else {
        triggerHaptic('error');
        setIsError(true);
        setTimeout(() => {
          setPin('');
        }, 550);
        setTimeout(() => {
          setIsError(false);
        }, 950);
      }
    }
  };

  const handleBackspace = () => {
    if (isError) return;
    triggerHaptic('light');
    setPin((prev) => prev.slice(0, -1));
  };

  if (!locked) return null;

  return (
    <>
      <style>{`
        @keyframes appLockShake {
          0%, 100% { transform: translateX(0); }
          12% { transform: translateX(-16px) rotate(-1.5deg); }
          26% { transform: translateX(14px) rotate(1.2deg); }
          42% { transform: translateX(-10px) rotate(-0.8deg); }
          58% { transform: translateX(8px) rotate(0.6deg); }
          74% { transform: translateX(-4px) rotate(-0.3deg); }
          88% { transform: translateX(2px); }
        }
        @keyframes dotPulseError {
          0% { transform: scale(1); }
          30% { transform: scale(1.35); }
          65% { transform: scale(0.92); }
          100% { transform: scale(1.1); }
        }
        @keyframes errorTextFade {
          0% { opacity: 0; transform: translateY(-4px); }
          100% { opacity: 1; transform: translateY(0); }
        }
      `}</style>

      <div className="app-lock-overlay" role="dialog" aria-modal="true" aria-label="Passcode Screen Lock">
        <div className="app-lock-card">
          {/* Avatar with dynamic lock status indicator */}
          <div className="app-lock-avatar-wrap">
            <Avatar name={user?.displayName || user?.username || 'You'} avatarUrl={user?.avatarId} size="lg" />
            <div className={`app-lock-status-badge ${isError ? 'is-error' : ''}`}>
              <Lock size={13} strokeWidth={2.4} />
            </div>
          </div>

          <h2 className="app-lock-title">
            Novyn Chat Locked
          </h2>

          {/* Subtitle / Animated Error Message */}
          <div className="app-lock-subtitle-wrap">
            {isError ? (
              <p className="app-lock-error-msg">
                <span className="app-lock-error-dot" />
                Incorrect passcode · Try again
              </p>
            ) : (
              <p className="app-lock-subtitle">
                Enter your 4-digit passcode
              </p>
            )}
          </div>

          {/* 4 PIN Dots with Spring Shake & Crimson Glow on Error */}
          <div className={`app-lock-dots-row ${isError ? 'is-shaking' : ''}`}>
            {[0, 1, 2, 3].map((index) => {
              const isFilled = pin.length > index;
              return (
                <div
                  key={index}
                  className={`app-lock-pin-dot ${isError ? 'is-error' : ''} ${isFilled ? 'is-filled' : ''}`}
                  style={{
                    animation: isError ? `dotPulseError 0.5s ease ${index * 0.035}s both` : 'none',
                  }}
                />
              );
            })}
          </div>

          {/* Keypad */}
          <div className="app-lock-keypad">
            {['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((digit) => (
              <button
                key={digit}
                type="button"
                className="app-lock-key-btn"
                onClick={() => handleDigit(digit)}
              >
                {digit}
              </button>
            ))}
            <div />
            <button
              type="button"
              className="app-lock-key-btn"
              onClick={() => handleDigit('0')}
            >
              0
            </button>
            <button
              type="button"
              className="app-lock-backspace-btn"
              onClick={handleBackspace}
              aria-label="Delete last digit"
            >
              <Delete size={24} />
            </button>
          </div>
        </div>
      </div>
    </>
  );
};
