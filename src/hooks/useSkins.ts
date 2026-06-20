import { useContext } from 'react';
import { SkinContext } from '@/lib/skins/skinContext';
import type { SkinContextValue } from '@/lib/skins/skinContext';

/**
 * Liest den SkinContext aus und wirft einen Fehler, wenn er außerhalb
 * eines SkinProvider verwendet wird.
 */
export function useSkins(): SkinContextValue {
  const context = useContext(SkinContext);

  if (context === undefined) {
    throw new Error('useSkins muss innerhalb eines SkinProvider verwendet werden.');
  }

  return context;
}
