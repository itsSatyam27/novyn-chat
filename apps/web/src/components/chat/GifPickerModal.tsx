import React, { useCallback, useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, X, Sparkles, Flame, Heart, ThumbsUp, Laugh, PartyPopper, Sticker } from 'lucide-react';
import { triggerHaptic } from '../../services/capacitor';

interface GifPickerModalProps { isOpen: boolean; onClose: () => void; onSelectGif: (gifUrl: string) => void; }
interface GiphyItem { id: string; title: string; previewUrl: string; url: string; }

const CATEGORIES = [
  { label: 'Trending', icon: Flame, query: '' }, { label: 'Reactions', icon: Sparkles, query: 'reaction' },
  { label: 'Laugh', icon: Laugh, query: 'funny laugh' }, { label: 'Love', icon: Heart, query: 'love heart' },
  { label: 'Thumbs up', icon: ThumbsUp, query: 'thumbs up' }, { label: 'Party', icon: PartyPopper, query: 'celebrate dance' },
];

export const GifPickerModal: React.FC<GifPickerModalProps> = ({ isOpen, onClose, onSelectGif }) => {
  const [query, setQuery] = useState('');
  const [activeCategory, setActiveCategory] = useState('');
  const [mediaType, setMediaType] = useState<'gifs' | 'stickers'>('gifs');
  const [items, setItems] = useState<GiphyItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState('');
  const [nextOffset, setNextOffset] = useState(0);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const loadMedia = useCallback(async (offset = 0, append = false) => {
    const search = query.trim() || activeCategory;
    append ? setLoadingMore(true) : setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({ type: mediaType, limit: '24', offset: String(offset) });
      if (search) params.set('q', search);
      const response = await fetch(`/api/giphy?${params}`, { credentials: 'include' });
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.error || 'GIF search is unavailable.');
      const next: GiphyItem[] = Array.isArray(payload.items) ? payload.items : [];
      setItems((current) => append ? [...current, ...next.filter((item) => !current.some((saved) => saved.id === item.id))] : next);
      setNextOffset(Number(payload.nextOffset) || offset + next.length);
    } catch (requestError) {
      setItems((current) => append ? current : []);
      setError(requestError instanceof Error ? requestError.message : 'GIF search is unavailable.');
    } finally { setLoading(false); setLoadingMore(false); }
  }, [activeCategory, mediaType, query]);

  useEffect(() => {
    if (!isOpen) return;
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => loadMedia(), query.trim() ? 300 : 0);
    return () => { if (debounceRef.current) clearTimeout(debounceRef.current); };
  }, [isOpen, query, activeCategory, mediaType, loadMedia]);

  if (!isOpen) return null;
  return createPortal(
    <AnimatePresence>
      <div className="gif-picker-backdrop" onClick={onClose}>
        <motion.div className="gif-picker-modal" initial={{ opacity: 0, scale: 0.95, y: 10 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.95, y: 10 }} transition={{ duration: 0.15 }} onClick={(event) => event.stopPropagation()}>
          <header className="gif-picker-header">
            <div className="gif-picker-heading"><span><Sparkles size={15} /></span><h3>GIFs & Stickers</h3></div>
            <button type="button" className="gif-picker-close" onClick={onClose} aria-label="Close GIF picker"><X size={18} /></button>
            <label className="gif-picker-search"><Search size={16} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder={`Search ${mediaType === 'gifs' ? 'GIFs' : 'stickers'} on GIPHY`} autoFocus />{query && <button type="button" onClick={() => setQuery('')} aria-label="Clear search"><X size={14} /></button>}</label>
            <div className="gif-picker-tabs" role="tablist" aria-label="Media type">
              <button type="button" role="tab" aria-selected={mediaType === 'gifs'} onClick={() => { setMediaType('gifs'); triggerHaptic('light'); }}><Sparkles size={14} /> GIFs</button>
              <button type="button" role="tab" aria-selected={mediaType === 'stickers'} onClick={() => { setMediaType('stickers'); triggerHaptic('light'); }}><Sticker size={14} /> Stickers</button>
            </div>
            {!query && <div className="gif-picker-categories">{CATEGORIES.map((category) => { const Icon = category.icon; const active = activeCategory === category.query; return <button key={category.label} type="button" className={active ? 'active' : ''} onClick={() => { setActiveCategory(category.query); triggerHaptic('light'); }}><Icon size={12} />{category.label}</button>; })}</div>}
          </header>
          <div className="gif-picker-grid">
            {loading && <div className="gif-picker-state"><i />Loading from GIPHY…</div>}
            {!loading && error && <div className="gif-picker-state error">{error}{error.includes('not configured') && <small>Add <code>GIPHY_API_KEY</code> to the server environment, then restart it.</small>}</div>}
            {!loading && !error && !items.length && <div className="gif-picker-state">No results. Try another search.</div>}
            {!loading && items.map((item) => <motion.button key={item.id} type="button" className="gif-picker-item" whileHover={{ scale: 1.03 }} whileTap={{ scale: 0.97 }} onClick={() => { triggerHaptic('medium'); onSelectGif(item.url); onClose(); }}><img src={item.previewUrl} alt={item.title || 'GIF'} loading="lazy" /></motion.button>)}
          </div>
          {!loading && !error && items.length > 0 && <button type="button" className="gif-picker-more" disabled={loadingMore} onClick={() => loadMedia(nextOffset, true)}>{loadingMore ? 'Loading…' : 'Load more'}</button>}
          <footer>Powered by GIPHY</footer>
        </motion.div>
      </div>
    </AnimatePresence>, document.body
  );
};
