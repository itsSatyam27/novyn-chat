function decodeHtmlEntities(value) {
  return String(value || '')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&apos;/gi, "'")
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&#(?:x([0-9a-f]+)|(\d+));/gi, (match, hex, decimal) => {
      const codePoint = hex ? Number.parseInt(hex, 16) : Number.parseInt(decimal, 10);
      if (!Number.isFinite(codePoint) || codePoint < 0 || codePoint > 0x10ffff) return match;
      try {
        return String.fromCodePoint(codePoint);
      } catch (_) {
        return match;
      }
    });
}

function readTagAttributes(tag) {
  const attributes = {};
  const source = String(tag || '')
    .replace(/^<\s*meta\b/i, '')
    .replace(/\/?>\s*$/, '');
  const attributePattern = /([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g;
  let match;
  while ((match = attributePattern.exec(source))) {
    const key = match[1].toLowerCase();
    attributes[key] = match[2] ?? match[3] ?? match[4] ?? '';
  }
  return attributes;
}

function findMetaContent(html, names) {
  const accepted = new Set(names.map((name) => name.toLowerCase()));
  const tags = String(html || '').match(/<meta\b[^>]*>/gi) || [];
  for (const tag of tags) {
    const attributes = readTagAttributes(tag);
    const name = String(attributes.property || attributes.name || attributes.itemprop || '').toLowerCase();
    if (accepted.has(name) && attributes.content) return attributes.content;
  }
  return '';
}

function cleanText(value, maxLength) {
  return decodeHtmlEntities(value)
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, maxLength);
}

function safePreviewImage(rawImage, baseUrl) {
  if (!rawImage) return '';
  try {
    const imageUrl = new URL(decodeHtmlEntities(rawImage).trim(), baseUrl);
    if (!['http:', 'https:'].includes(imageUrl.protocol) || imageUrl.username || imageUrl.password) {
      return '';
    }
    return imageUrl.href;
  } catch (_) {
    return '';
  }
}

function createLinkPreviewData(html, rawUrl) {
  const pageUrl = new URL(String(rawUrl || '').trim());
  if (!['http:', 'https:'].includes(pageUrl.protocol) || pageUrl.username || pageUrl.password) {
    throw new Error('Unsupported URL');
  }

  const pageTitle = (String(html || '').match(/<title\b[^>]*>([\s\S]*?)<\/title>/i) || [])[1] || '';
  const title = cleanText(
    findMetaContent(html, ['og:title', 'twitter:title', 'title']) || pageTitle || pageUrl.hostname,
    120,
  );
  const description = cleanText(
    findMetaContent(html, ['og:description', 'twitter:description', 'description']),
    200,
  );
  const image = safePreviewImage(
    findMetaContent(html, ['og:image', 'og:image:url', 'og:image:secure_url', 'twitter:image', 'twitter:image:src']),
    pageUrl,
  );
  const siteName = cleanText(
    findMetaContent(html, ['og:site_name']) || pageUrl.hostname.replace(/^www\./i, ''),
    80,
  );

  return {
    url: pageUrl.href,
    title,
    description,
    image,
    siteName,
    domain: pageUrl.hostname,
  };
}

module.exports = { createLinkPreviewData };
