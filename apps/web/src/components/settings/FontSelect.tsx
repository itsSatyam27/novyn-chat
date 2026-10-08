import { useEffect, useId, useLayoutEffect, useRef, useState, type KeyboardEvent } from 'react';
import { createPortal } from 'react-dom';
import { Check, ChevronDown } from 'lucide-react';
import { FONT_PRESETS } from '../../services/settingsTheme';

export function SettingsSelect({ label, options, value, onChange, searchable = false }: {
  label: string;
  options: readonly { id: string; name: string; description: string; family?: string }[];
  value: string;
  onChange: (value: string) => void;
  searchable?: boolean;
}) {
  const id = useId();
  const trigger = useRef<HTMLButtonElement>(null);
  const menu = useRef<HTMLDivElement>(null);
  const searchInput = useRef<HTMLInputElement>(null);
  const [search, setSearch] = useState('');
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const [position, setPosition] = useState<{ top: number; left: number; width: number; maxHeight: number } | null>(null);
  const selected = Math.max(0, options.findIndex(option => option.id === value));
  const visibleOptions = options.filter(option => !search || `${option.name} ${option.description}`.toLowerCase().replace(/_/g, ' ').includes(search.toLowerCase().replace(/_/g, ' ').trim()));

  const show = () => { setSearch(''); setActive(selected); setOpen(true); };
  const choose = (index: number) => { if (!visibleOptions[index]) return; onChange(visibleOptions[index].id); setOpen(false); trigger.current?.focus(); };

  useLayoutEffect(() => {
    if (!open) return;
    const place = () => {
      const rect = trigger.current?.getBoundingClientRect();
      if (!rect) return;
      if (rect.bottom < 0 || rect.top > window.innerHeight) { setOpen(false); return; }
      const below = window.innerHeight - rect.bottom - 16;
      const above = rect.top - 16;
      const upwards = below < 220 && above > below;
      const maxHeight = Math.max(54, Math.min(options.length * 54 + 14 + (searchable ? 48 : 0), searchable ? 340 : 380, upwards ? above : below));
      const width = Math.min(rect.width, window.innerWidth - 24);
      setPosition({ top: upwards ? rect.top - maxHeight - 6 : rect.bottom + 6,
        left: Math.max(12, Math.min(rect.left, window.innerWidth - width - 12)), width, maxHeight });
    };
    place();
    const scroll = (event: Event) => { if (!menu.current?.contains(event.target as Node)) place(); };
    window.addEventListener('resize', place);
    window.addEventListener('scroll', scroll, true);
    return () => { window.removeEventListener('resize', place); window.removeEventListener('scroll', scroll, true); };
  }, [open, options.length, searchable]);

  useEffect(() => {
    if (!open) return;
    const dismiss = (event: PointerEvent) => {
      if (!trigger.current?.contains(event.target as Node) && !menu.current?.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener('pointerdown', dismiss);
    return () => document.removeEventListener('pointerdown', dismiss);
  }, [open]);

  useEffect(() => {
    if (open) menu.current?.querySelectorAll('[role=option]')[active]?.scrollIntoView({ block: 'nearest' });
  }, [open, active, search, position?.maxHeight]);

  useEffect(() => { if (open && searchable && position) searchInput.current?.focus(); }, [open, searchable, Boolean(position)]);

  const keyDown = (event: KeyboardEvent<HTMLElement>) => {
    if (event.key === 'Escape') { event.preventDefault(); setOpen(false); trigger.current?.focus(); return; }
    if (event.key === 'Tab') { setOpen(false); return; }
    if (event.key === 'Enter' || (event.key === ' ' && event.target !== searchInput.current)) { event.preventDefault(); if (open) choose(active); else show(); return; }
    if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
      event.preventDefault();
      if (!open) { show(); return; }
      if (!visibleOptions.length) return;
      setActive(index => event.key === 'Home' ? 0 : event.key === 'End' ? visibleOptions.length - 1
        : (index + (event.key === 'ArrowDown' ? 1 : -1) + visibleOptions.length) % visibleOptions.length);
    }
  };

  return <div className="web-settings-field font-select-field">
    <span id={id + '-label'}>{label}</span>
    <button ref={trigger} type="button" role="combobox" className="font-select-trigger" aria-labelledby={id + '-label'}
      aria-expanded={open} aria-haspopup="listbox" aria-controls={open ? id + '-list' : undefined}
      aria-activedescendant={open ? id + '-option-' + active : undefined} onKeyDown={keyDown}
      onBlur={event => { if (!menu.current?.contains(event.relatedTarget as Node)) setOpen(false); }}
      onClick={() => { if (open) setOpen(false); else show(); }}>
      <span>{options[selected].name}</span><ChevronDown size={17} aria-hidden="true" />
    </button>
    {open && position && createPortal(<div ref={menu}
      className={'font-select-menu' + (searchable ? ' is-searchable' : '')} style={position}
      onBlur={event => { if (!menu.current?.contains(event.relatedTarget as Node) && event.relatedTarget !== trigger.current) setOpen(false); }}
      onMouseDown={event => { if (event.target !== searchInput.current) event.preventDefault(); }}>
      {searchable && <input ref={searchInput} className="settings-select-search" type="search" value={search} placeholder="Search city or time zone…"
        aria-label="Search time zones" role="combobox" aria-expanded={true} aria-controls={id + '-list'} aria-activedescendant={visibleOptions.length ? id + '-option-' + active : undefined}
        onChange={event => { setSearch(event.target.value); setActive(0); }} onKeyDown={keyDown} />}
      <div id={id + '-list'} role="listbox" aria-labelledby={id + '-label'} className="settings-select-options">
      {visibleOptions.map((font, index) => <div key={font.id} id={id + '-option-' + index} role="option"
        aria-selected={font.id === value} className={'font-select-option' + (index === active ? ' is-active' : '')}
        onPointerMove={() => setActive(index)} onClick={() => choose(index)}>
        <span><strong style={{ fontFamily: font.family }}>{font.name}</strong><small>{font.description}</small></span>
        {font.id === value && <Check size={17} aria-hidden="true" />}
      </div>)}
      </div>
      {!visibleOptions.length && <p className="settings-select-empty" role="status">No matching time zones.</p>}
    </div>, document.body)}
  </div>;
}

export function FontSelect({ value, onChange }: { value: string; onChange: (value: string) => void }) {
  return <SettingsSelect label="Font family" options={FONT_PRESETS} value={value} onChange={onChange} />;
}
