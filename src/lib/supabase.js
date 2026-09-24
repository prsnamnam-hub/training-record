import { createClient } from '@supabase/supabase-js'
import { SUPABASE_URL, SUPABASE_ANON_KEY, IS_CONFIGURED } from './config'

export const supabase = IS_CONFIGURED
  ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { persistSession: true, autoRefreshToken: true, flowType: 'pkce', detectSessionInUrl: true } })
  : null

/** Throw on Supabase errors so callers can use try/catch uniformly. */
export async function must(promise) {
  const { data, error, count } = await promise
  if (error) throw new Error(error.message || String(error))
  return count !== undefined && count !== null ? { data, count } : data
}
