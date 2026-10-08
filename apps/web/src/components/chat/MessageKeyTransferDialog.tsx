import { useEffect, useId, useRef } from 'react';
import { X } from 'lucide-react';
import { MessageKeyTransfer } from '../settings/MessageKeyTransfer';

export function MessageKeyTransferDialog({ isOpen, onClose }: { isOpen: boolean; onClose: () => void }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  useEffect(() => {
    if (isOpen) dialog.current?.showModal();
    else dialog.current?.close();
  }, [isOpen]);
  return (
    <dialog ref={dialog} className="android-settings-dialog message-key-dialog" aria-labelledby={titleId}
      onClose={onClose} onClick={(event) => {
        if (event.target !== event.currentTarget) return;
        const rect = event.currentTarget.getBoundingClientRect();
        if (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom) onClose();
      }}>
      <header><h2 id={titleId}>Sync encrypted messages to Android</h2>
        <button type="button" aria-label="Close" onClick={onClose}><X size={20} /></button>
      </header>
      {isOpen && <MessageKeyTransfer embedded />}
    </dialog>
  );
}
