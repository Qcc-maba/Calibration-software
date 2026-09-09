/*
  PackingIcon — for the אריזה entry in the עוד menu (MBA-909).

  Written to match CarIcon / the other menu icons exactly: stroke="currentColor" so it inherits
  the menu's colour on hover and active states, the same strokeWidth / size props, the same round
  caps and joins.

  Why not reuse the existing BoxIcon: it hardcodes stroke="#9B5600" and is 36x28. It is the right
  glyph for the packing COLUMN, where the orange is deliberate, but dropped into the menu it would
  be the only coloured icon and would not respond to hover.

  This file is reference only — it belongs in app/src/assets/icons/PackingIcon.tsx and the app repo
  is Dako's to change.
*/
import { type SVGProps } from 'react';

export const PackingIcon = ({
  className,
  strokeWidth = 2,
  size = 24,
  ...props
}: SVGProps<SVGSVGElement> & { strokeWidth?: number; size?: number }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    className={className}
    stroke="currentColor"
    strokeWidth={strokeWidth}
    strokeLinecap="round"
    strokeLinejoin="round"
    width={size}
    height={size}
    {...props}
  >
    {/* carton lid */}
    <path d="M3 8.5 L6.2 4.2 A1.6 1.6 0 0 1 7.5 3.5 H16.5 A1.6 1.6 0 0 1 17.8 4.2 L21 8.5" />
    {/* carton body */}
    <path d="M3 8.5 H21 V19 A1.5 1.5 0 0 1 19.5 20.5 H4.5 A1.5 1.5 0 0 1 3 19 Z" />
    {/* seam where the flaps meet */}
    <path d="M12 3.5 V20.5" />
  </svg>
);
