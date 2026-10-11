const BASE32_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export function generateBase32Secret(length = 20): string {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let result = '';
  for (let i = 0; i < length; i++) {
    result += BASE32_CHARS[bytes[i] % 32];
  }
  return result;
}

export function generateBackupCodes(count = 8): string[] {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const codes: string[] = [];
  for (let i = 0; i < count; i++) {
    const bytes = new Uint8Array(8);
    crypto.getRandomValues(bytes);
    let code = '';
    for (let j = 0; j < 8; j++) {
      if (j === 4) code += '-';
      code += chars[bytes[j] % chars.length];
    }
    codes.push(code);
  }
  return codes;
}

export function getOtpAuthUrl(username: string, secret: string, issuer = 'Novyn'): string {
  const cleanUser = encodeURIComponent(username || 'User');
  const cleanIssuer = encodeURIComponent(issuer);
  return `otpauth://totp/${cleanIssuer}:${cleanUser}?secret=${secret}&issuer=${cleanIssuer}&period=30&digits=6`;
}
