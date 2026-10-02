import React from 'react';

interface NovynLogoProps {
  size?: number;
  variant?: 'white' | 'emerald' | 'black';
  withBadge?: boolean;
  badgeSize?: number;
  className?: string;
  style?: React.CSSProperties;
  onClick?: () => void;
}

export const NovynLogo: React.FC<NovynLogoProps> = ({
  size = 24,
  variant = 'white',
  withBadge = false,
  badgeSize,
  className = '',
  style = {},
  onClick,
}) => {
  const iconSrc =
    variant === 'emerald'
      ? '/icons/novyn-wings-emerald.png'
      : variant === 'black'
      ? '/icons/novyn-wings.png'
      : '/icons/novyn-wings-white.png';

  const imgElement = (
    <img
      src={iconSrc}
      alt="Novyn Wings Logo"
      width={size}
      height={size}
      style={{
        width: `${size}px`,
        height: `${size}px`,
        objectFit: 'contain',
        display: 'block',
        pointerEvents: 'none',
        userSelect: 'none',
        ...style,
      }}
      className={className}
    />
  );

  if (!withBadge) {
    return onClick ? (
      <div onClick={onClick} style={{ cursor: 'pointer', display: 'inline-flex' }}>
        {imgElement}
      </div>
    ) : (
      imgElement
    );
  }

  const containerSize = badgeSize || Math.round(size * 1.6);
  const radius = Math.round(containerSize * 0.28);

  return (
    <div
      onClick={onClick}
      style={{
        width: `${containerSize}px`,
        height: `${containerSize}px`,
        borderRadius: `${radius}px`,
        background: 'linear-gradient(135deg, #7c6cff 0%, #5141cd 100%)',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        boxShadow: '0 4px 18px rgba(75, 62, 186, 0.38)',
        flexShrink: 0,
        cursor: onClick ? 'pointer' : 'default',
      }}
    >
      {imgElement}
    </div>
  );
};
