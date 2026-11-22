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
  const displaySize = withBadge ? badgeSize || Math.round(size * 1.6) : size;

  const imgElement = (
    <img
      src="/icons/novyn-app-icon.png"
      alt="Novyn app icon"
      width={displaySize}
      height={displaySize}
      style={{
        width: `${displaySize}px`,
        height: `${displaySize}px`,
        objectFit: 'contain',
        display: 'block',
        borderRadius: `${Math.round(displaySize * 0.24)}px`,
        flexShrink: 0,
        pointerEvents: 'none',
        userSelect: 'none',
        ...style,
      }}
      className={className}
    />
  );

  return onClick ? (
    <div onClick={onClick} style={{ cursor: 'pointer', display: 'inline-flex' }}>
      {imgElement}
    </div>
  ) : imgElement;
};
