// ASW Training Record — admin user management (Supabase Edge Function).
// Creating users / setting passwords needs the service_role key, which must never reach the browser.
// This function runs server-side, uses the key Supabase injects (SUPABASE_SERVICE_ROLE_KEY) and only
// acts for an active Admin (checked against public.profiles).
//
// POST { action: 'create', email, password, full_name?, role? }   -> new confirmed user (+ role)
// POST { action: 'set_password', user_id, password }              -> set another user's password
// POST { action: 'delete', user_id }                               -> remove a user (soft delete: sign-in blocked,
//                                                                     audit history that references the user stays intact)
import { createClient } from 'npm:@supabase/supabase-js@2'

const ROLES = ['admin', 'hr_training', 'viewer']
const MIN_PASSWORD = 8
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405)

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  // caller must be a signed-in, active Admin
  const token = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '')
  const { data: caller, error: callerErr } = await admin.auth.getUser(token)
  if (callerErr || !caller?.user) return json({ error: 'กรุณาเข้าสู่ระบบ' }, 401)
  const { data: me } = await admin.from('profiles').select('role, is_active').eq('id', caller.user.id).maybeSingle()
  if (!me || me.role !== 'admin' || !me.is_active) return json({ error: 'เฉพาะ Admin เท่านั้น' }, 403)

  let body: Record<string, unknown>
  try { body = await req.json() } catch { return json({ error: 'invalid JSON' }, 400) }
  if (body.action === 'delete') {
    const userId = String(body.user_id ?? '')
    if (!userId) return json({ error: 'user_id required' }, 400)
    if (userId === caller.user.id) return json({ error: 'ลบบัญชีของตัวเองไม่ได้' }, 400)
    // soft delete keeps auth.users rows that created_by / updated_by columns still reference
    const { error } = await admin.auth.admin.deleteUser(userId, true)
    if (error) return json({ error: error.message }, 400)
    const { error: pErr } = await admin.from('profiles').delete().eq('id', userId)
    if (pErr) return json({ error: pErr.message }, 500)
    return json({ id: userId, deleted: true })
  }

  const password = String(body.password ?? '')
  if (password.length < MIN_PASSWORD) return json({ error: `รหัสผ่านต้องมีอย่างน้อย ${MIN_PASSWORD} ตัวอักษร` }, 400)

  if (body.action === 'create') {
    const email = String(body.email ?? '').trim().toLowerCase()
    const fullName = String(body.full_name ?? '').trim() || email.split('@')[0]
    const role = ROLES.includes(String(body.role)) ? String(body.role) : 'viewer'
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json({ error: 'อีเมลไม่ถูกต้อง' }, 400)

    const { data, error } = await admin.auth.admin.createUser({
      email, password, email_confirm: true, user_metadata: { full_name: fullName },
    })
    if (error) return json({ error: error.message }, 400)
    // public.handle_new_user() has created the profile (viewer) — apply the chosen role
    const { error: pErr } = await admin.from('profiles').update({ role, full_name: fullName }).eq('id', data.user.id)
    if (pErr) return json({ error: pErr.message }, 500)
    return json({ id: data.user.id, email, role })
  }

  if (body.action === 'set_password') {
    const userId = String(body.user_id ?? '')
    if (!userId) return json({ error: 'user_id required' }, 400)
    const { error } = await admin.auth.admin.updateUserById(userId, { password })
    if (error) return json({ error: error.message }, 400)
    return json({ id: userId })
  }

  return json({ error: 'unknown action' }, 400)
})
