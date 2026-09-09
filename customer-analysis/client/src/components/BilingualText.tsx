import React from 'react';

interface BilingualTextProps {
  text: string;
  className?: string;
}

function hasEnglishChars(text: string): boolean {
  return /[a-zA-Z]/.test(text);
}

function hasHebrewChars(text: string): boolean {
  return /[\u0590-\u05FF]/.test(text);
}

function isEnglishOrSpace(c: string): boolean {
  return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c === ' ';
}

function fixReversedEnglish(text: string): string {
  if (!text) return text;
  
  let result: string[] = [];
  let englishSegment: string[] = [];
  
  for (const char of text) {
    if (isEnglishOrSpace(char)) {
      englishSegment.push(char);
    } else {
      if (englishSegment.length > 0) {
        const segment = englishSegment.join('').trim();
        if (segment) {
          const reversed = segment.split('').reverse().join('');
          result.push(reversed);
        }
        englishSegment = [];
      }
      result.push(char);
    }
  }
  
  if (englishSegment.length > 0) {
    const segment = englishSegment.join('').trim();
    if (segment) {
      const reversed = segment.split('').reverse().join('');
      result.push(reversed);
    }
  }
  
  return result.join('');
}

export function BilingualText({ text, className = '' }: BilingualTextProps) {
  if (!text) return null;
  
  const hasEnglish = hasEnglishChars(text);
  const hasHebrew = hasHebrewChars(text);
  
  if (hasEnglish && !hasHebrew) {
    return <span dir="ltr" className={`inline-block text-left ${className}`}>{text}</span>;
  }
  
  if (!hasEnglish && hasHebrew) {
    return <span dir="rtl" className={className}>{text}</span>;
  }
  
  if (hasEnglish && hasHebrew) {
    const fixedText = fixReversedEnglish(text);
    return <span className={className}>{fixedText}</span>;
  }
  
  return <span className={className}>{text}</span>;
}
