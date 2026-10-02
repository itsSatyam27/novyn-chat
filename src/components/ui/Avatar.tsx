import React from 'react';

interface AvatarProps {
  name: string;
  avatarUrl?: string;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  online?: boolean;
  presence?: 'online' | 'away' | 'dnd' | 'offline';
  className?: string;
  isGroup?: boolean;
}

const sizeStyles = {
  sm: { width: '34px', height: '34px', fontSize: '0.8rem' },
  md: { width: '42px', height: '42px', fontSize: '0.95rem' },
  lg: { width: '50px', height: '50px', fontSize: '1.15rem' },
  xl: { width: '64px', height: '64px', fontSize: '1.5rem' },
};

const dotSizeStyles = {
  sm: { width: '9px', height: '9px' },
  md: { width: '11px', height: '11px' },
  lg: { width: '13px', height: '13px' },
  xl: { width: '15px', height: '15px' },
};

const gradients = [
  'linear-gradient(135deg, #10b981 0%, #047857 100%)',
  'linear-gradient(135deg, #6366f1 0%, #4338ca 100%)',
  'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
  'linear-gradient(135deg, #8b5cf6 0%, #6d28d9 100%)',
  'linear-gradient(135deg, #ec4899 0%, #be185d 100%)',
  'linear-gradient(135deg, #f59e0b 0%, #b45309 100%)',
];

function getGradient(name: string): string {
  let hash = 0;
  for (let i = 0; i < (name || '').length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash);
  }
  return gradients[Math.abs(hash) % gradients.length];
}

export const Avatar: React.FC<AvatarProps> = ({
  name,
  avatarUrl,
  size = 'md',
  online,
  presence,
  isGroup,
}) => {
  const [imgError, setImgError] = React.useState(false);

  React.useEffect(() => {
    setImgError(false);
  }, [avatarUrl]);

  const initial = (name || '?').charAt(0).toUpperCase();
  const gradient = getGradient(name || '');
  const s = sizeStyles[size] || sizeStyles.md;
  const dotS = dotSizeStyles[size] || dotSizeStyles.md;

  const showImage = Boolean(avatarUrl && !imgError);

  const effectivePresence = isGroup ? undefined : (presence || (online ? 'online' : online === false ? 'offline' : undefined));
  const dotColor =
    effectivePresence === 'online'
      ? '#10b981'
      : effectivePresence === 'away'
      ? '#f59e0b'
      : effectivePresence === 'dnd'
      ? '#ef4444'
      : effectivePresence === 'offline'
      ? '#64748b'
      : undefined;

  return (
    <div
      style={{
        position: 'relative',
        display: 'inline-flex',
        flexShrink: 0,
        alignItems: 'center',
        justifyContent: 'center',
        width: s.width,
        height: s.height,
      }}
    >
      {showImage ? (
        <img
          className="avatar-face"
          src={avatarUrl}
          alt={name}
          onError={() => setImgError(true)}
          style={{
            width: '100%',
            height: '100%',
            borderRadius: '50%',
            objectFit: 'cover',
            background: 'rgba(255, 255, 255, 0.05)',
            border: '1px solid rgba(255, 255, 255, 0.12)',
          }}
        />
      ) : (
        <div
          className="avatar-face"
          style={{
            width: '100%',
            height: '100%',
            borderRadius: '50%',
            background: gradient,
            color: '#ffffff',
            fontWeight: 800,
            fontSize: s.fontSize,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: 'inset 0 1px 2px rgba(255, 255, 255, 0.25)',
            border: '1px solid rgba(255, 255, 255, 0.12)',
            textTransform: 'uppercase',
          }}
        >
          {initial}
        </div>
      )}

      {dotColor && (
        <span
          style={{
            position: 'absolute',
            bottom: '0',
            right: '0',
            width: dotS.width,
            height: dotS.height,
            borderRadius: '50%',
            background: dotColor,
            border: '2px solid #ffffff',
            boxShadow: effectivePresence === 'online' ? '0 0 6px rgba(16, 185, 129, 0.6)' : 'none',
          }}
        />
      )}
    </div>
  );
};
