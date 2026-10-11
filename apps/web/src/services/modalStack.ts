// Modal stack manager for Android & Browser back button dismissal

type DismissCallback = () => void;

interface ModalEntry {
  id: string;
  onDismiss: DismissCallback;
}

const stack: ModalEntry[] = [];
let isPoppingFromHistory = false;

export function registerModal(id: string, onDismiss: DismissCallback): () => void {
  if (typeof window === 'undefined') return () => {};

  const entry: ModalEntry = { id, onDismiss };
  stack.push(entry);

  const state = window.history.state || {};
  window.history.pushState({ ...state, novynModal: id }, '');

  return () => {
    const index = stack.findIndex((m) => m.id === id);
    if (index !== -1) {
      stack.splice(index, 1);
      // If closed by button/click (not via popstate), rewind history
      if (!isPoppingFromHistory && window.history.state?.novynModal === id) {
        window.history.back();
      }
    }
  };
}

export function handleModalPopState(): boolean {
  if (stack.length === 0) return false;

  const top = stack.pop();
  if (top) {
    isPoppingFromHistory = true;
    try {
      top.onDismiss();
    } finally {
      setTimeout(() => {
        isPoppingFromHistory = false;
      }, 50);
    }
    return true;
  }
  return false;
}

export function hasOpenModals(): boolean {
  return stack.length > 0;
}
