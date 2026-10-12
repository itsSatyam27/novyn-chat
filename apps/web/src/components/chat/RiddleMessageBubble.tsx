import React, { useState } from 'react';
import { KeyRound, Lightbulb, LockKeyhole, Unlock } from 'lucide-react';
import type { Message } from '../../types';
import { useChat } from '../../context/ChatContext';
import { triggerHaptic } from '../../services/capacitor';
import './riddleLock.css';

export const RiddleMessageBubble: React.FC<{ message: Message; isMe: boolean }> = ({ message, isMe }) => {
  const { unlockRiddle } = useChat();
  const [answer, setAnswer] = useState('');
  const [busy, setBusy] = useState(false);
  const [feedback, setFeedback] = useState('');
  const riddle = message.riddle!;
  const exhausted = !riddle.unlocked && riddle.triesLeft <= 0;

  const unlock = async () => {
    if (!answer.trim() || busy || exhausted) return;
    setBusy(true);
    setFeedback('');
    const result = await unlockRiddle(message.id, message.sender, answer);
    setBusy(false);
    if (result.ok) {
      setAnswer('');
      triggerHaptic('success');
    } else {
      triggerHaptic('heavy');
      setFeedback(result.message || 'Could not unlock this riddle.');
    }
  };

  return <div className="riddle-message">
    <div className={`riddle-secret${riddle.unlocked ? ' is-unlocked' : ''}`}>
      <span>{riddle.unlocked ? <Unlock size={16} /> : <LockKeyhole size={16} />}</span>
      <strong>{riddle.unlocked ? riddle.secret : 'Secret message locked'}</strong>
    </div>
    <p className="riddle-question">{riddle.question}</p>
    {riddle.hint && <span className="riddle-hint"><Lightbulb size={12} />Hint: {riddle.hint}</span>}
    {!riddle.unlocked && !isMe && <div className="riddle-answer-row">
      <label><KeyRound size={14} /><input type="password" value={answer} disabled={busy || exhausted} placeholder="Your answer" aria-label="Riddle answer" onChange={event => setAnswer(event.target.value)} onKeyDown={event => { if (event.key === 'Enter') void unlock(); }} /></label>
      <button type="button" disabled={!answer.trim() || busy || exhausted} onClick={() => void unlock()}>{busy ? 'Checking…' : 'Unlock'}</button>
    </div>}
    {feedback && <small className="riddle-feedback">{feedback}</small>}
    {!riddle.unlocked && !isMe && <small className="riddle-tries">{riddle.triesLeft} {riddle.triesLeft === 1 ? 'try' : 'tries'} left</small>}
    {isMe && <small className="riddle-tries">Recipient gets {riddle.maxTries} tries</small>}
  </div>;
};
