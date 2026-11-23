const test = require('node:test');
const assert = require('node:assert/strict');
const { createLinkPreviewData } = require('../server/chat/link-preview');

test('reads Open Graph metadata regardless of meta attribute order', () => {
  const html = [
    '<html><head>',
    '<meta content="Novyn &amp; Friends" property="og:title">',
    "<meta name='description' content='A &#x63;alm chat app &amp; calls'>",
    "<meta content='/assets/preview.jpg' property='og:image'>",
    "<meta content='Novyn' property='og:site_name'>",
    '<title>Fallback title</title>',
    '</head></html>',
  ].join('');
  const result = createLinkPreviewData(html, 'https://example.com/posts/hello?from=chat');

  assert.equal(result.url, 'https://example.com/posts/hello?from=chat');
  assert.equal(result.title, 'Novyn & Friends');
  assert.equal(result.description, 'A calm chat app & calls');
  assert.equal(result.image, 'https://example.com/assets/preview.jpg');
  assert.equal(result.siteName, 'Novyn');
  assert.equal(result.domain, 'example.com');
});

test('uses safe fallbacks when a page has no Open Graph tags', () => {
  const result = createLinkPreviewData('<html><title>Plain page</title></html>', 'https://www.example.com/page');
  assert.equal(result.title, 'Plain page');
  assert.equal(result.description, '');
  assert.equal(result.image, '');
  assert.equal(result.siteName, 'example.com');
});

test('rejects non-web image URLs and URL credentials', () => {
  const result = createLinkPreviewData(
    '<meta property="og:title" content="Page"><meta property="og:image" content="javascript:alert(1)">',
    'https://example.com',
  );
  assert.equal(result.image, '');
  assert.throws(
    () => createLinkPreviewData('<title>Page</title>', 'https://user:secret@example.com'),
    /Unsupported URL/,
  );
});

test('normalizes relative and protocol-relative preview images', () => {
  const relative = createLinkPreviewData(
    '<meta property="og:image" content="../cover.png">',
    'https://example.com/articles/one',
  );
  assert.equal(relative.image, 'https://example.com/cover.png');

  const protocolRelative = createLinkPreviewData(
    '<meta property="og:image" content="//cdn.example.com/cover.png">',
    'https://example.com/articles/one',
  );
  assert.equal(protocolRelative.image, 'https://cdn.example.com/cover.png');
});
