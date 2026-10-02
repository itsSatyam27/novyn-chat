import React, { useState } from 'react';
import { createPortal } from 'react-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { BarChart3, Plus, Trash2, X, Send } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

interface CreatePollModalProps {
  isOpen: boolean;
  onClose: () => void;
  onCreatePoll: (question: string, options: string[]) => void;
}

export const CreatePollModal: React.FC<CreatePollModalProps> = ({
  isOpen,
  onClose,
  onCreatePoll,
}) => {
  const [question, setQuestion] = useState('');
  const [options, setOptions] = useState<string[]>(['', '']);

  if (!isOpen) return null;

  const handleAddOption = () => {
    if (options.length >= 6) return;
    triggerHaptic('light');
    setOptions((prev) => [...prev, '']);
  };

  const handleRemoveOption = (index: number) => {
    if (options.length <= 2) return;
    triggerHaptic('light');
    setOptions((prev) => prev.filter((_, i) => i !== index));
  };

  const handleOptionChange = (index: number, val: string) => {
    setOptions((prev) => {
      const next = [...prev];
      next[index] = val;
      return next;
    });
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const cleanQuestion = question.trim();
    const cleanOptions = options.map((o) => o.trim()).filter(Boolean);

    if (!cleanQuestion || cleanOptions.length < 2) return;

    triggerHaptic('success');
    onCreatePoll(cleanQuestion, cleanOptions);
    setQuestion('');
    setOptions(['', '']);
    onClose();
  };

  return createPortal(
    <AnimatePresence>
      <div
        className="chat-option-overlay create-poll-overlay"
        style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(23, 66, 78, 0.12)',
          backdropFilter: 'blur(10px)',
          WebkitBackdropFilter: 'blur(10px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 9999,
          padding: '16px',
        }}
        onClick={onClose}
      >
        <motion.div
          className="chat-option-modal create-poll-modal"
          initial={{ opacity: 0, scale: 0.95, y: 10 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 10 }}
          transition={{ duration: 0.15 }}
          style={{
            width: '100%',
            maxWidth: '440px',
            background: 'var(--bg-surface)',
            border: '1px solid var(--border)',
            borderRadius: '20px',
            boxShadow: '0 25px 50px -12px rgba(36, 76, 96, 0.1)',
            padding: '24px',
            display: 'flex',
            flexDirection: 'column',
            gap: '18px',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <div
                className="create-poll-header-icon"
                style={{
                  width: '36px',
                  height: '36px',
                  borderRadius: '10px',
                  background: 'rgba(16, 185, 129, 0.15)',
                  border: '1px solid rgba(16, 185, 129, 0.3)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#0e9f8a',
                }}
              >
                <BarChart3 style={{ width: '18px', height: '18px' }} />
              </div>
              <h3 style={{ fontSize: '1.05rem', fontWeight: 800, color: 'var(--text-main)', margin: 0 }}>
                Create a Poll
              </h3>
            </div>
            <button
              className="chat-option-close"
              type="button"
              onClick={onClose}
              style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer' }}
            >
              <X style={{ width: '18px', height: '18px' }} />
            </button>
          </div>

          <form className="create-poll-form" onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
            {/* Question Input */}
            <div>
              <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '6px' }}>
                QUESTION
              </label>
              <input
                className="create-poll-input"
                type="text"
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                placeholder="Ask a question..."
                autoFocus
                required
                style={{
                  width: '100%',
                  background: 'rgba(255, 255, 255, 0.55)',
                  border: '1px solid var(--border)',
                  borderRadius: '12px',
                  padding: '10px 14px',
                  color: 'var(--text-main)',
                  fontSize: '0.88rem',
                  outline: 'none',
                }}
              />
            </div>

            {/* Options */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)' }}>
                OPTIONS (2–6)
              </label>
              {options.map((opt, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <input
                    className="create-poll-input create-poll-option-input"
                    type="text"
                    value={opt}
                    onChange={(e) => handleOptionChange(i, e.target.value)}
                    placeholder={`Option ${i + 1}`}
                    required
                    style={{
                      flex: 1,
                      background: 'rgba(255, 255, 255, 0.55)',
                      border: '1px solid var(--border)',
                      borderRadius: '10px',
                      padding: '8px 12px',
                      color: 'var(--text-main)',
                      fontSize: '0.84rem',
                      outline: 'none',
                    }}
                  />
                  {options.length > 2 && (
                    <button
                      className="create-poll-remove"
                      type="button"
                      onClick={() => handleRemoveOption(i)}
                      style={{
                        background: 'none',
                        border: 'none',
                        color: '#bd3750',
                        cursor: 'pointer',
                        padding: '4px',
                      }}
                    >
                      <Trash2 style={{ width: '15px', height: '15px' }} />
                    </button>
                  )}
                </div>
              ))}

              {options.length < 6 && (
                <button
                  className="create-poll-add-option"
                  type="button"
                  onClick={handleAddOption}
                  style={{
                    background: 'none',
                    border: '1px dashed var(--border)',
                    borderRadius: '10px',
                    padding: '8px',
                    color: '#0e9f8a',
                    fontSize: '0.8rem',
                    fontWeight: 700,
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '6px',
                    marginTop: '4px',
                  }}
                >
                  <Plus style={{ width: '14px', height: '14px' }} /> Add Option
                </button>
              )}
            </div>

            {/* Submit Button */}
            <button
              className="chat-option-primary create-poll-submit"
              type="submit"
              disabled={!question.trim() || options.filter((o) => o.trim()).length < 2}
              style={{
                width: '100%',
                padding: '12px',
                borderRadius: '12px',
                background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                border: 'none',
                color: 'var(--text-on-primary)',
                fontSize: '0.9rem',
                fontWeight: 800,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px',
                boxShadow: '0 8px 20px rgba(16, 185, 129, 0.35)',
                marginTop: '6px',
                opacity: !question.trim() || options.filter((o) => o.trim()).length < 2 ? 0.5 : 1,
              }}
            >
              <Send style={{ width: '16px', height: '16px' }} /> Send Poll
            </button>
          </form>
        </motion.div>
      </div>
    </AnimatePresence>,
    document.body
  );
};
