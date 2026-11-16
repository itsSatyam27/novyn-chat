document.getElementById('year').textContent = new Date().getFullYear();

(() => {
  const params = new URLSearchParams(window.location.search);
  const rawInvite = (params.get('invite') || '').trim().replace(/^@/, '');
  const validUsername = /^[A-Za-z0-9_.-]{1,40}$/.test(rawInvite);
  if (!validUsername) return;

  const username = rawInvite;
  const promoUrl = new URL('https://itssatyam27.github.io/novyn-chat/');
  promoUrl.searchParams.set('invite', username);
  promoUrl.searchParams.set('appOpen', '0');
  promoUrl.hash = 'invite';

  // Android Chrome understands intent:// links and uses the fallback URL
  // when Novyn is not installed. The app receives novyn://user/<username>.
  const intentUrl =
    'intent://user/' + encodeURIComponent(username) +
    '#Intent;scheme=novyn;package=com.example.novyn;S.browser_fallback_url=' +
    encodeURIComponent(promoUrl.toString()) + ';end';

  const banner = document.createElement('section');
  banner.className = 'invite-banner';
  banner.id = 'invite';
  banner.setAttribute('role', 'region');
  banner.setAttribute('aria-labelledby', 'invite-title');

  const copy = document.createElement('div');
  copy.className = 'invite-banner-copy';

  const eyebrow = document.createElement('span');
  eyebrow.className = 'invite-eyebrow';
  eyebrow.textContent = 'YOU HAVE BEEN INVITED';

  const title = document.createElement('h2');
  title.id = 'invite-title';
  title.textContent = '@' + username + ' invited you to Novyn';

  const description = document.createElement('p');
  description.textContent = 'Open the conversation in Novyn, or get the Android app to join in.';

  copy.append(eyebrow, title, description);

  const actions = document.createElement('div');
  actions.className = 'invite-banner-actions';

  const openLink = document.createElement('a');
  openLink.className = 'button button-primary';
  openLink.href = intentUrl;
  openLink.textContent = 'Open Novyn';
  openLink.setAttribute('aria-label', 'Open this invite in the Novyn app');

  const downloadLink = document.createElement('a');
  downloadLink.className = 'button button-secondary';
  downloadLink.href = 'https://github.com/itsSatyam27/novyn-chat/releases/latest/download/Novyn-Android-ARM64.apk';
  downloadLink.textContent = 'Download Android';
  downloadLink.target = '_blank';
  downloadLink.rel = 'noopener noreferrer';

  actions.append(openLink, downloadLink);
  banner.append(copy, actions);
  document.querySelector('main')?.prepend(banner);

  // Do not auto-launch again on the fallback page. Keeping a visible button
  // also lets people retry when their browser blocks automatic app launches.
  const isAndroid = /Android/i.test(navigator.userAgent);
  const shouldTryOpen = params.get('appOpen') !== '0';
  if (isAndroid && shouldTryOpen) {
    window.setTimeout(() => window.location.replace(intentUrl), 250);
  }
})();
