import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { CheckCircle2, CircleAlert, X } from 'lucide-react';

export type SettingsNotice = { text: string; error: boolean };

export function SettingsToast({ notice, onDismiss }: { notice: SettingsNotice; onDismiss: () => void }) {
  const [leaving, setLeaving] = useState(false);
  useEffect(() => {
    setLeaving(false);
    const leaveTimer = window.setTimeout(() => setLeaving(true), 3300);
    const dismissTimer = window.setTimeout(onDismiss, 3500);
    return () => { window.clearTimeout(leaveTimer); window.clearTimeout(dismissTimer); };
  }, [notice, onDismiss]);
  const Icon = notice.error ? CircleAlert : CheckCircle2;
  return createPortal(
    <div className="settings-toast-position">
      <div className={'settings-toast' + (notice.error ? ' is-error' : '') + (leaving ? ' is-leaving' : '')}
        role={notice.error ? 'alert' : 'status'} aria-atomic="true">
        <Icon size={20} aria-hidden="true" />
        <span>{notice.text}</span>
        <button type="button" aria-label="Dismiss notification" onClick={onDismiss}><X size={17} aria-hidden="true" /></button>
      </div>
    </div>, document.body,
  );
}
