import Svg, { Circle, Path, Rect } from 'react-native-svg';

export const brandColors = {
  forest: '#2E4D3A',
  sage: '#8DAE8D',
  leaf: '#BED6B2',
  sand: '#F6F1E8',
  earth: '#D9C9B5',
};

export function BrandMark({ size = 48, cutout = brandColors.sand, forest = brandColors.forest, leaf = brandColors.leaf, background }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 128 128">
      {background ? <Rect width="128" height="128" rx="30" fill={background} /> : null}

      <Path d="M38 10h24c25 0 39 11 39 30 0 15-10 25-23 29 17 4 28 15 28 31 0 25-18 38-44 38H38V10Z" fill={forest} />
      <Path d="M58 25c-10 0-18 7-18 17v17c0 7 5 12 12 12h18c18 0 30-9 30-23 0-15-12-23-30-23H58Z" fill={cutout} opacity="0.95" />
      <Path d="M53 71c-4 8-11 14-21 19 0 0 10 9 22 14 15 6 25 11 41 20-15-18-27-28-42-53Z" fill={cutout} opacity="0.95" />

      <Path d="M28 103c13-14 31-25 57-36-8 17-17 31-31 44-8 8-17 12-26 15 3-8 5-17 0-23Z" fill={leaf} />
      <Path d="M30 111c18-18 36-30 59-41" fill="none" stroke={forest} strokeWidth="2.5" strokeLinecap="round" opacity="0.45" />

      <Circle cx="65" cy="31" r="8" fill={cutout} />
      <Path d="M77 31c-2-7-8-11-15-12 11 2 18 10 17 21-1 12-12 22-24 26 6-3 12-7 16-13 4-7 6-14 6-22Z" fill={leaf} opacity="0.9" />
    </Svg>
  );
}