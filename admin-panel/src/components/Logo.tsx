import React from 'react';

/** TreepNet logo (the brand "T" of coloured tiles) on a white rounded tile — same mark as the app icon. */
export const TreepnetLogo: React.FC<{ size?: number; className?: string }> = ({ size = 28, className = '' }) => (
  <svg width={size} height={size} viewBox="0 0 800 800" role="img" aria-label="Treepnet" className={className}>
    <rect width="800" height="800" rx="176" fill="#ffffff" />
    <rect x="86" y="81" width="68" height="80" fill="#B01205" />
    <rect x="166" y="81" width="68" height="80" fill="#7996CF" />
    <rect x="246" y="81" width="68" height="80" fill="#F33AB2" />
    <rect x="326" y="81" width="68" height="80" fill="#6E3BBC" />
    <rect x="406" y="81" width="68" height="80" fill="#F33AB2" />
    <rect x="486" y="81" width="68" height="80" fill="#2F5596" />
    <rect x="566" y="81" width="68" height="80" fill="#B01205" />
    <rect x="646" y="81" width="68" height="80" fill="#6E3BBC" />
    <rect x="86" y="174" width="68" height="80" fill="#2F5596" />
    <rect x="166" y="174" width="68" height="80" fill="#6E3BBC" />
    <rect x="246" y="174" width="68" height="80" fill="#2F5596" />
    <rect x="326" y="174" width="68" height="80" fill="#B01205" />
    <rect x="406" y="174" width="68" height="80" fill="#7996CF" />
    <rect x="486" y="174" width="68" height="80" fill="#6E3BBC" />
    <rect x="566" y="174" width="68" height="80" fill="#7996CF" />
    <rect x="646" y="174" width="68" height="80" fill="#F33AB2" />
    <rect x="326" y="267" width="68" height="80" fill="#F33AB2" />
    <rect x="406" y="267" width="68" height="80" fill="#2F5596" />
    <rect x="326" y="360" width="68" height="80" fill="#6E3BBC" />
    <rect x="406" y="360" width="68" height="80" fill="#B01205" />
    <rect x="326" y="453" width="68" height="80" fill="#7996CF" />
    <rect x="406" y="453" width="68" height="80" fill="#F33AB2" />
    <rect x="326" y="546" width="68" height="80" fill="#B01205" />
    <rect x="406" y="546" width="68" height="80" fill="#2F5596" />
    <rect x="326" y="639" width="68" height="80" fill="#6E3BBC" />
    <rect x="406" y="639" width="68" height="80" fill="#7996CF" />
  </svg>
);
