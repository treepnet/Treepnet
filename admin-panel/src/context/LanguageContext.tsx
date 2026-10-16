import React, { createContext, useContext, useState } from 'react';
import { Language, Translation, translations } from '../i18n/translations';

interface LanguageContextType {
  lang: Language;
  setLang: (lang: Language) => void;
  t: Translation;
}

const LanguageContext = createContext<LanguageContextType | undefined>(undefined);

function readLang(): Language {
  try {
    const s = localStorage.getItem('treepnet_lang');
    if (s === 'uz' || s === 'ru' || s === 'en') return s;
  } catch {
    /* storage unavailable */
  }
  return 'uz';
}

export const LanguageProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [lang, setLangState] = useState<Language>(readLang);
  const setLang = (l: Language) => {
    setLangState(l);
    try {
      localStorage.setItem('treepnet_lang', l);
    } catch {
      /* storage unavailable */
    }
  };
  return (
    <LanguageContext.Provider value={{ lang, setLang, t: translations[lang] }}>{children}</LanguageContext.Provider>
  );
};

export const useLanguage = () => {
  const ctx = useContext(LanguageContext);
  if (!ctx) throw new Error('useLanguage must be used within a LanguageProvider');
  return ctx;
};
