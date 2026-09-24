import { reactive, computed } from 'vue'
import { supabase } from './supabase'

export const auth = reactive({ ready: false, session: null, profile: null })

export const role = computed(() => auth.profile?.role || 'none')
export const isAdmin = computed(() => role.value === 'admin')
export const canEdit = computed(() => ['admin', 'hr_training'].includes(role.value))
export const canView = computed(() => ['admin', 'hr_training', 'viewer'].includes(role.value))

export const ROLE_LABEL = { admin: 'Admin', hr_training: 'HR / Training', viewer: 'Viewer', none: '—' }

async function loadProfile() {
  if (!auth.session) { auth.profile = null; return }
  const { data } = await supabase.from('profiles').select('*').eq('id', auth.session.user.id).maybeSingle()
  auth.profile = data || { id: auth.session.user.id, email: auth.session.user.email, role: 'none', is_active: false }
}

export async function initAuth() {
  if (!supabase) { auth.ready = true; return }
  const { data } = await supabase.auth.getSession()
  auth.session = data.session
  await loadProfile()
  auth.ready = true
  supabase.auth.onAuthStateChange((evt, session) => {
    auth.session = session
    // hash router: the recovery link lands on "/?code=..." — send the user to the reset page
    if (evt === 'PASSWORD_RECOVERY') window.location.hash = '#/reset-password'
    setTimeout(loadProfile, 0) // never await Supabase calls inside this callback (deadlocks the client)
  })
}

export async function signIn(email, password) {
  const { error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw error
}

export async function signUp(email, password, fullName) {
  const { data, error } = await supabase.auth.signUp({ email, password, options: { data: { full_name: fullName } } })
  if (error) throw error
  return data
}

export async function resetPassword(email) {
  const redirectTo = window.location.origin + window.location.pathname
  const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo })
  if (error) throw error
}

export async function signOut() {
  await supabase.auth.signOut()
  auth.session = null
  auth.profile = null
}
