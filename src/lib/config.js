// Public runtime config. Values come from VITE_* env at build time, with the
// committed public defaults below as a fallback (the anon/publishable key is
// designed to be public; access control is enforced by Supabase Auth + RLS).
export const APP_NAME = 'ASW Training Record'
export const APP_TAGLINE = 'Training Record & Training Expense Management'
export const APP_SUBTITLE = 'ASW Training Record — Training Management & Analytics System'

const DEFAULTS = {
  url: '',
  key: '',
}

export const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || DEFAULTS.url
export const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || DEFAULTS.key
export const IS_CONFIGURED = Boolean(SUPABASE_URL && SUPABASE_ANON_KEY)
