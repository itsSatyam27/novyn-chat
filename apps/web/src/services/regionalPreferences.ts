/** Browser-local locale used by message, call and export date formatting. */
export function getPreferredLocale(): string {
  const language = localStorage.getItem('novyn_settings_language') === 'hi' ? 'hi' : 'en';
  const savedRegion = localStorage.getItem('novyn_region');
  const region = savedRegion && ['IN', 'US', 'GB'].includes(savedRegion) ? savedRegion : 'IN';
  return `${language}-${region}`;
}
