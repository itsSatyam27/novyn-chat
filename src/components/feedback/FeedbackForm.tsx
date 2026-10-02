import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { MessageSquarePlus, X, Star, Send, CheckCircle2, ChevronDown } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { triggerHaptic } from '../../services/capacitor';

// ── Types ────────────────────────────────────────────────────────────────────
type FeedbackType = 'general' | 'bug' | 'feature' | 'praise';

interface FeedbackOption {
  value: FeedbackType;
  label: string;
  emoji: string;
  color: string;
}

const FEEDBACK_TYPES: FeedbackOption[] = [
  { value: 'general',  label: 'General',        emoji: '💬', color: '#38bdf8' },
  { value: 'bug',      label: 'Bug Report',      emoji: '🐛', color: '#f87171' },
  { value: 'feature',  label: 'Feature Request', emoji: '✨', color: '#a78bfa' },
  { value: 'praise',   label: 'Praise',          emoji: '🙌', color: '#34d399' },
];

// ── FeedbackForm ─────────────────────────────────────────────────────────────
export const FeedbackForm: React.FC = () => {
  const { user } = useAuth();

  const [open, setOpen]           = useState(false);
  const [type, setType]           = useState<FeedbackType>('general');
  const [message, setMessage]     = useState('');
  const [email, setEmail]         = useState('');
  const [rating, setRating]       = useState<number>(0);
  const [hoverRating, setHoverRating] = useState<number>(0);
  const [loading, setLoading]     = useState(false);
  const [success, setSuccess]     = useState(false);
  const [error, setError]         = useState('');
  const [typeOpen, setTypeOpen]   = useState(false);

  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const modalRef    = useRef<HTMLDivElement>(null);

  // Pre-fill email from logged-in user
  useEffect(() => {
    if (user?.email && !email) setEmail(user.email);
  }, [user?.email]);

  // Focus textarea when modal opens
  useEffect(() => {
    if (open) setTimeout(() => textareaRef.current?.focus(), 150);
  }, [open]);

  // Close type dropdown on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (typeOpen && !(e.target as Element).closest('[data-type-dropdown]')) {
        setTypeOpen(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [typeOpen]);

  const selectedType = FEEDBACK_TYPES.find(t => t.value === type)!;

  const reset = () => {
    setMessage('');
    setRating(0);
    setHoverRating(0);
    setError('');
    setType('general');
    if (!user?.email) setEmail('');
  };

  const handleClose = () => {
    setOpen(false);
    setTimeout(() => { setSuccess(false); reset(); }, 300);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!message.trim() || message.trim().length < 5) {
      setError('Please write at least a few words.');
      return;
    }
    setLoading(true);
    setError('');
    triggerHaptic('medium');

    try {
      const res = await fetch('/api/feedback', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          type,
          message: message.trim(),
          email:   email.trim() || undefined,
          rating:  rating || undefined,
        }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Submission failed.');

      triggerHaptic('success');
      setSuccess(true);
      setTimeout(handleClose, 2800);
    } catch (err: any) {
      setError(err.message || 'Something went wrong. Try again.');
      triggerHaptic('heavy');
    } finally {
      setLoading(false);
    }
  };

  const charCount = message.length;
  const charLimit = 2000;

  return (
    <>
      {/* ── Floating trigger button ─────────────────────────────────────── */}
      <AnimatePresence>
        {!open && (
          <motion.button
            key="fab"
            initial={{ opacity: 0, scale: 0.8, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.8, y: 20 }}
            transition={{ type: 'spring', damping: 20, stiffness: 300 }}
            onClick={() => { triggerHaptic('light'); setOpen(true); }}
            aria-label="Send feedback"
            style={{
              position: 'fixed',
              bottom: '24px',
              right: '24px',
              zIndex: 900,
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              padding: '11px 18px',
              borderRadius: '999px',
              background: 'linear-gradient(135deg, var(--primary) 0%, #059669 100%)',
              border: 'none',
              color: 'var(--text-on-primary)',
              fontSize: '0.82rem',
              fontWeight: 700,
              cursor: 'pointer',
              boxShadow: '0 4px 20px var(--primary-glow), 0 2px 8px rgba(36, 76, 96, 0.1)',
              letterSpacing: '0.01em',
              whiteSpace: 'nowrap',
            }}
            whileHover={{ scale: 1.06 }}
            whileTap={{ scale: 0.95 }}
          >
            <MessageSquarePlus style={{ width: '16px', height: '16px', flexShrink: 0 }} />
            Feedback
          </motion.button>
        )}
      </AnimatePresence>

      {/* ── Modal overlay ───────────────────────────────────────────────── */}
      <AnimatePresence>
        {open && (
          <motion.div
            key="overlay"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            onClick={handleClose}
            style={{
              position: 'fixed',
              inset: 0,
              zIndex: 1000,
              background: 'rgba(23, 66, 78, 0.12)',
              backdropFilter: 'blur(6px)',
              display: 'flex',
              alignItems: 'flex-end',
              justifyContent: 'flex-end',
              padding: '0 20px 20px',
            }}
          >
            {/* ── Modal panel ─────────────────────────────────────────── */}
            <motion.div
              ref={modalRef}
              key="modal"
              initial={{ opacity: 0, y: 40, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 30, scale: 0.96 }}
              transition={{ type: 'spring', damping: 26, stiffness: 340 }}
              onClick={e => e.stopPropagation()}
              style={{
                width: '100%',
                maxWidth: '420px',
                background: 'var(--bg-surface)',
                border: '1px solid var(--border)',
                borderRadius: '20px',
                padding: '24px',
                boxShadow: '0 24px 60px rgba(36, 76, 96, 0.1)',
                display: 'flex',
                flexDirection: 'column',
                gap: '16px',
              }}
            >
              {success ? (
                /* ── Success state ──────────────────────────────────── */
                <motion.div
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  style={{ textAlign: 'center', padding: '16px 0' }}
                >
                  <motion.div
                    initial={{ scale: 0 }}
                    animate={{ scale: 1 }}
                    transition={{ type: 'spring', damping: 12, stiffness: 200, delay: 0.1 }}
                    style={{
                      width: '64px', height: '64px', borderRadius: '50%',
                      background: 'rgba(16,185,129,0.15)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      margin: '0 auto 16px',
                    }}
                  >
                    <CheckCircle2 style={{ width: '32px', height: '32px', color: '#0e9f8a' }} />
                  </motion.div>
                  <h3 style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-main)', margin: '0 0 8px' }}>
                    Thanks for your feedback!
                  </h3>
                  <p style={{ fontSize: '0.86rem', color: 'var(--text-muted)', margin: 0, lineHeight: 1.5 }}>
                    We read every submission and use it to make Novyn better.
                  </p>
                </motion.div>
              ) : (
                /* ── Form ──────────────────────────────────────────── */
                <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                  {/* Header */}
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <div style={{
                        width: '34px', height: '34px', borderRadius: '10px',
                        background: 'var(--primary-glow)',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                      }}>
                        <MessageSquarePlus style={{ width: '17px', height: '17px', color: 'var(--primary)' }} />
                      </div>
                      <div>
                        <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 800, color: 'var(--text-main)' }}>Send Feedback</h3>
                        <p style={{ margin: 0, fontSize: '0.74rem', color: 'var(--text-dark)' }}>
                          {user ? `Sending as ${user.username}` : 'Anonymous — add email to get a reply'}
                        </p>
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={handleClose}
                      style={{
                        background: 'rgba(255, 255, 255, 0.55)', border: '1px solid var(--border)',
                        color: 'var(--text-muted)', width: '30px', height: '30px', borderRadius: '8px',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        cursor: 'pointer', flexShrink: 0,
                      }}
                    >
                      <X style={{ width: '14px', height: '14px' }} />
                    </button>
                  </div>

                  {/* Type selector */}
                  <div data-type-dropdown style={{ position: 'relative' }}>
                    <button
                      type="button"
                      onClick={() => setTypeOpen(p => !p)}
                      style={{
                        width: '100%', display: 'flex', alignItems: 'center',
                        justifyContent: 'space-between',
                        padding: '10px 14px', borderRadius: '12px',
                        background: 'rgba(255, 255, 255, 0.55)',
                        border: `1px solid ${typeOpen ? 'var(--border-focus)' : 'var(--border)'}`,
                        color: 'var(--text-main)', cursor: 'pointer', fontSize: '0.87rem', fontWeight: 600,
                      }}
                    >
                      <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <span>{selectedType.emoji}</span>
                        <span style={{ color: selectedType.color }}>{selectedType.label}</span>
                      </span>
                      <ChevronDown style={{
                        width: '14px', height: '14px', color: 'var(--text-dark)',
                        transform: typeOpen ? 'rotate(180deg)' : 'none',
                        transition: 'transform 0.2s',
                      }} />
                    </button>

                    <AnimatePresence>
                      {typeOpen && (
                        <motion.div
                          initial={{ opacity: 0, y: -6, scale: 0.97 }}
                          animate={{ opacity: 1, y: 0, scale: 1 }}
                          exit={{ opacity: 0, y: -6, scale: 0.97 }}
                          transition={{ duration: 0.15 }}
                          style={{
                            position: 'absolute', top: 'calc(100% + 6px)', left: 0, right: 0,
                            background: 'var(--bg-surface)',
                            border: '1px solid var(--border)',
                            borderRadius: '12px', overflow: 'hidden', zIndex: 10,
                            boxShadow: '0 8px 24px rgba(36, 76, 96, 0.1)',
                          }}
                        >
                          {FEEDBACK_TYPES.map(opt => (
                            <button
                              key={opt.value}
                              type="button"
                              onClick={() => { setType(opt.value); setTypeOpen(false); triggerHaptic('light'); }}
                              style={{
                                width: '100%', display: 'flex', alignItems: 'center', gap: '10px',
                                padding: '10px 14px', background: type === opt.value
                                  ? 'rgba(255, 255, 255, 0.55)' : 'transparent',
                                border: 'none', color: type === opt.value ? opt.color : 'var(--text-muted)',
                                cursor: 'pointer', fontSize: '0.87rem', fontWeight: 600,
                                textAlign: 'left',
                              }}
                            >
                              <span>{opt.emoji}</span>
                              <span>{opt.label}</span>
                            </button>
                          ))}
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </div>

                  {/* Star rating */}
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    <span style={{ fontSize: '0.78rem', color: 'var(--text-dark)', fontWeight: 600 }}>
                      Rate your experience (optional)
                    </span>
                    <div style={{ display: 'flex', gap: '6px' }}>
                      {[1, 2, 3, 4, 5].map(star => (
                        <button
                          key={star}
                          type="button"
                          onClick={() => { setRating(star === rating ? 0 : star); triggerHaptic('light'); }}
                          onMouseEnter={() => setHoverRating(star)}
                          onMouseLeave={() => setHoverRating(0)}
                          style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '2px' }}
                          aria-label={`Rate ${star} star${star > 1 ? 's' : ''}`}
                        >
                          <Star
                            style={{
                              width: '22px', height: '22px',
                              transition: 'all 0.15s ease',
                              transform: (hoverRating || rating) >= star ? 'scale(1.15)' : 'scale(1)',
                            }}
                            fill={(hoverRating || rating) >= star ? '#f59e0b' : 'transparent'}
                            stroke={(hoverRating || rating) >= star ? '#f59e0b' : '#475569'}
                            strokeWidth={1.5}
                          />
                        </button>
                      ))}
                      {rating > 0 && (
                        <span style={{ fontSize: '0.78rem', color: '#a86d0b', alignSelf: 'center', marginLeft: '4px', fontWeight: 700 }}>
                          {['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'][rating]}
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Message textarea */}
                  <div style={{ position: 'relative' }}>
                    <textarea
                      ref={textareaRef}
                      value={message}
                      onChange={e => { setMessage(e.target.value.slice(0, charLimit)); setError(''); }}
                      placeholder={`What's on your mind? ${selectedType.emoji}`}
                      rows={4}
                      style={{
                        width: '100%', resize: 'none', padding: '12px 14px',
                        borderRadius: '12px', fontSize: '0.88rem', lineHeight: 1.6,
                        background: 'rgba(255, 255, 255, 0.55)',
                        border: `1px solid ${error ? '#f87171' : 'var(--border)'}`,
                        color: 'var(--text-main)', outline: 'none', boxSizing: 'border-box',
                        fontFamily: 'inherit', transition: 'border-color 0.15s',
                      }}
                      onFocus={e => { if (!error) e.target.style.borderColor = 'var(--border-focus)'; }}
                      onBlur={e => { if (!error) e.target.style.borderColor = 'var(--border)'; }}
                    />
                    <span style={{
                      position: 'absolute', bottom: '10px', right: '12px',
                      fontSize: '0.7rem', color: charCount > charLimit * 0.9 ? '#bd3750' : 'var(--text-dark)',
                    }}>
                      {charCount}/{charLimit}
                    </span>
                  </div>

                  {/* Email (only if not logged in) */}
                  {!user && (
                    <input
                      type="email"
                      value={email}
                      onChange={e => setEmail(e.target.value)}
                      placeholder="Your email (optional — for a reply)"
                      style={{
                        width: '100%', padding: '10px 14px', borderRadius: '12px',
                        fontSize: '0.87rem', background: 'rgba(255, 255, 255, 0.55)',
                        border: '1px solid var(--border)', color: 'var(--text-main)',
                        outline: 'none', boxSizing: 'border-box', fontFamily: 'inherit',
                      }}
                    />
                  )}

                  {/* Error */}
                  <AnimatePresence>
                    {error && (
                      <motion.p
                        initial={{ opacity: 0, y: -6 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0 }}
                        style={{ margin: 0, fontSize: '0.82rem', color: '#bd3750', fontWeight: 600 }}
                      >
                        {error}
                      </motion.p>
                    )}
                  </AnimatePresence>

                  {/* Submit */}
                  <button
                    type="submit"
                    disabled={loading || !message.trim()}
                    style={{
                      width: '100%', padding: '12px', borderRadius: '12px',
                      background: loading || !message.trim()
                        ? 'rgba(255, 255, 255, 0.55)'
                        : 'linear-gradient(135deg, var(--primary) 0%, #059669 100%)',
                      border: 'none', color: loading || !message.trim() ? 'var(--text-dark)' : 'var(--text-main)',
                      fontSize: '0.9rem', fontWeight: 700, cursor: loading || !message.trim() ? 'not-allowed' : 'pointer',
                      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px',
                      transition: 'all 0.2s ease',
                      boxShadow: loading || !message.trim() ? 'none' : '0 4px 14px var(--primary-glow)',
                    }}
                  >
                    {loading ? (
                      <>
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"
                          style={{ animation: 'spin 0.8s linear infinite' }}>
                          <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/>
                        </svg>
                        Sending…
                      </>
                    ) : (
                      <>
                        <Send style={{ width: '15px', height: '15px' }} />
                        Send Feedback
                      </>
                    )}
                  </button>
                </form>
              )}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Spinner keyframe */}
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </>
  );
};
