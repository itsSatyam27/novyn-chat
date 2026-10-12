import { useEffect, useState } from 'react';
import { HelpCircle, KeyRound, Lightbulb, LockKeyhole, X } from 'lucide-react';
import './riddleComposerModal.css';

type RiddlePayload = { secret: string; question: string; answer: string; hint?: string; maxTries: 3 | 5 };

export function RiddleComposerModal({ isOpen, recipient, onClose, onSend }: {
  isOpen: boolean;
  recipient: string;
  onClose: () => void;
  onSend: (payload: RiddlePayload) => Promise<{ ok: boolean; message?: string }>;
}) {
  const [secret, setSecret] = useState('');
  const [question, setQuestion] = useState('');
  const [answer, setAnswer] = useState('');
  const [hint, setHint] = useState('');
  const [tries, setTries] = useState<3 | 5>(3);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!isOpen) return;
    setSecret(''); setQuestion(''); setAnswer(''); setHint(''); setTries(3); setError(''); setBusy(false);
  }, [isOpen, recipient]);

  if (!isOpen) return null;
  const ready = secret.trim() && question.trim() && answer.trim() && !busy;
  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!ready) return;
    setBusy(true); setError('');
    const result = await onSend({ secret: secret.trim(), question: question.trim(), answer: answer.trim(), hint: hint.trim() || undefined, maxTries: tries });
    setBusy(false);
    if (result.ok) onClose();
    else setError(result.message || 'Could not send riddle.');
  };

  return <div className="riddle-composer-backdrop" onClick={onClose}>
    <section className="riddle-composer-modal" role="dialog" aria-modal="true" aria-labelledby="riddle-composer-title" onClick={event => event.stopPropagation()}>
      <header><span><LockKeyhole size={19} /></span><div><small>Riddle lock</small><h2 id="riddle-composer-title">Lock a message for @{recipient}</h2></div><button type="button" onClick={onClose} aria-label="Close"><X size={19} /></button></header>
      <p className="riddle-composer-note">Just for fun. For private information, send normally.</p>
      <form onSubmit={submit}>
        <label className="riddle-secret-field"><span>Secret message</span><textarea autoFocus value={secret} maxLength={250} onChange={event => setSecret(event.target.value)} placeholder="Write the secret message…" /><small>{secret.length} / 250</small></label>
        <div className="riddle-composer-pair">
          <label><HelpCircle size={15} /><input value={question} maxLength={160} onChange={event => setQuestion(event.target.value)} placeholder="Ask a question" aria-label="Riddle question" /></label>
          <label><KeyRound size={15} /><input type="password" value={answer} maxLength={80} onChange={event => setAnswer(event.target.value)} placeholder="Answer" aria-label="Riddle answer" /></label>
        </div>
        <div className="riddle-composer-options"><label><Lightbulb size={15} /><input value={hint} maxLength={160} onChange={event => setHint(event.target.value)} placeholder="Hint (optional)" /></label><span>Tries</span><button type="button" className={tries === 3 ? 'is-selected' : ''} onClick={() => setTries(3)}>3</button><button type="button" className={tries === 5 ? 'is-selected' : ''} onClick={() => setTries(5)}>5</button></div>
        {error && <p className="riddle-composer-error" role="alert">{error}</p>}
        <button className="riddle-composer-send" type="submit" disabled={!ready}><LockKeyhole size={16} />{busy ? 'Sending…' : 'Lock & send'}</button>
      </form>
    </section>
  </div>;
}
