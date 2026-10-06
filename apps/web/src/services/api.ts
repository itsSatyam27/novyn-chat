const CSRF_COOKIE_NAME = 'novyn_csrf';
const CSRF_HEADER_NAME = 'x-novyn-csrf';

export function getCookie(name: string): string {
  if (typeof document === 'undefined') return '';
  const prefix = `${name}=`;
  const cookies = document.cookie.split(';');
  for (let cookie of cookies) {
    cookie = cookie.trim();
    if (cookie.startsWith(prefix)) {
      try {
        return decodeURIComponent(cookie.substring(prefix.length));
      } catch {
        return cookie.substring(prefix.length);
      }
    }
  }
  return '';
}

export async function apiRequest<T = any>(
  path: string,
  options: RequestInit = {}
): Promise<{ ok: boolean; status: number; data: T }> {
  const method = (options.method || 'GET').toUpperCase();
  const headers = new Headers(options.headers || {});

  if (!headers.has('Content-Type') && !(options.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }

  if (method !== 'GET' && method !== 'HEAD' && method !== 'OPTIONS') {
    const csrfToken = getCookie(CSRF_COOKIE_NAME);
    if (csrfToken) {
      headers.set(CSRF_HEADER_NAME, csrfToken);
    }
  }

  try {
    const response = await fetch(path, {
      ...options,
      headers,
      credentials: 'include',
    });

    let data: any = {};
    const contentType = response.headers.get('content-type');
    if (contentType && contentType.includes('application/json')) {
      data = await response.json().catch(() => ({}));
    }

    return {
      ok: response.ok,
      status: response.status,
      data,
    };
  } catch (error: any) {
    return {
      ok: false,
      status: 0,
      data: { message: error?.message || 'Network request failed' } as any,
    };
  }
}

export async function uploadVoiceBlob(blob: Blob): Promise<{ ok: boolean; url?: string; error?: string }> {
  const formData = new FormData();
  formData.append('voice', blob, 'voice.webm');

  const csrfToken = getCookie(CSRF_COOKIE_NAME);
  const headers: HeadersInit = {};
  if (csrfToken) {
    headers[CSRF_HEADER_NAME] = csrfToken;
  }

  try {
    const res = await fetch('/upload-voice', {
      method: 'POST',
      body: formData,
      headers,
      credentials: 'include',
    });
    const data = await res.json();
    if (!res.ok) {
      return { ok: false, error: data?.error || 'Voice upload failed' };
    }
    return { ok: true, url: data.url };
  } catch (err: any) {
    return { ok: false, error: err?.message || 'Upload error' };
  }
}

export async function uploadMediaFile(file: File): Promise<{ ok: boolean; url?: string; error?: string }> {
  const formData = new FormData();
  formData.append('file', file);

  const csrfToken = getCookie(CSRF_COOKIE_NAME);
  const headers: HeadersInit = {};
  if (csrfToken) {
    headers[CSRF_HEADER_NAME] = csrfToken;
  }

  try {
    const res = await fetch('/upload-file', {
      method: 'POST',
      body: formData,
      headers,
      credentials: 'include',
    });
    const data = await res.json();
    if (!res.ok) {
      return { ok: false, error: data?.error || 'File upload failed' };
    }
    return { ok: true, url: data.url };
  } catch (err: any) {
    return { ok: false, error: err?.message || 'Upload error' };
  }
}
