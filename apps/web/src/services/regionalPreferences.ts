import { readBrowserPreference } from './browserPreferences';

/** Browser-local locale used by message, call and export date formatting. */
export function getPreferredLocale(): string {
  const language = localStorage.getItem('novyn_settings_language') === 'hi' ? 'hi' : 'en';
  const savedRegion = localStorage.getItem('novyn_region');
  const region = savedRegion && ['IN', 'US', 'GB'].includes(savedRegion) ? savedRegion : 'IN';
  return `${language}-${region}`;
}

const validTimeZones = new Map<string, boolean>();
export function isValidTimeZone(value: string): boolean {
  const cached = validTimeZones.get(value);
  if (cached !== undefined) return cached;
  let valid = false;
  try { new Intl.DateTimeFormat('en', { timeZone: value }); valid = true; } catch { /* Ignore unsupported stored zones. */ }
  validTimeZones.set(value, valid);
  return valid;
}

export function getDeviceTimeZone(): string {
  return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
}

export function getPreferredTimeZone(): string {
  const manual = readBrowserPreference('novyn_time_zone', getDeviceTimeZone());
  return readBrowserPreference('novyn_time_zone_mode', 'auto') === 'manual' && isValidTimeZone(manual)
    ? manual : getDeviceTimeZone();
}

export function getTimeZoneOptions() {
  const common = ['Asia/Kolkata', 'Europe/London', 'America/New_York', 'America/Chicago', 'America/Denver',
    'America/Los_Angeles', 'America/Anchorage', 'Pacific/Honolulu', 'Asia/Dubai', 'Asia/Tokyo', 'Australia/Sydney', 'UTC'];
  const supported = (Intl as typeof Intl & { supportedValuesOf?: (key: string) => string[] }).supportedValuesOf?.('timeZone') || [];
  return [...new Set([...common, getDeviceTimeZone(), ...supported])].filter(isValidTimeZone)
    .map(id => ({ id, name: id === 'UTC' ? 'UTC' : id.split('/').slice(1).join(' / ').replace(/_/g, ' '), description: id }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

/** Calendar days must use the same time zone as message timestamps. */
let dayFormatter: { zone: string; formatter: Intl.DateTimeFormat } | undefined;
export function getPreferredDayKey(value: Date): string {
  if (Number.isNaN(value.getTime())) return '';
  const zone = getPreferredTimeZone();
  if (dayFormatter?.zone !== zone) dayFormatter = { zone, formatter: new Intl.DateTimeFormat('en-US', { timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit' }) };
  const parts = dayFormatter.formatter.formatToParts(value);
  return ['year', 'month', 'day'].map(type => parts.find(part => part.type === type)?.value).join('-');
}
