// Supabase Edge Function: push-on-message
//
// Sends an FCM (HTTP v1) push notification to the receiver of a new chat
// message. Triggered by a Database Webhook on `public.messages` INSERT.
//
// Why an Edge Function: the app used to call Google's legacy FCM endpoint
// (`fcm.googleapis.com/fcm/send` with a server key) directly from the client.
// Google shut that API down in June 2024, and a service-account key must never
// ship inside the app. FCM v1 requires an OAuth2 token minted from a service
// account, which only a trusted backend (this function) may hold.
//
// Setup (see push-notifications-README.md):
//   1. supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
//   2. supabase functions deploy push-on-message --no-verify-jwt
//   3. Create a Database Webhook: table public.messages, event INSERT,
//      POST to this function's URL.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const PROJECT_ID = 'treepnet-16a89'
const FCM_ENDPOINT =
  `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`

// Cache the OAuth2 access token across warm invocations (valid ~1h).
let cachedToken: { token: string; exp: number } | null = null

function pemToPkcs8(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\\n/g, '')
    .replace(/\s+/g, '')
  const bin = atob(b64)
  const buf = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i)
  return buf.buffer
}

function base64url(data: Uint8Array | string): string {
  const bytes = typeof data === 'string'
    ? new TextEncoder().encode(data)
    : data
  let bin = ''
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

// deno-lint-ignore no-explicit-any
async function getAccessToken(sa: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedToken && cachedToken.exp > now + 60) return cachedToken.token

  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const claim = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }))
  const unsigned = `${header}.${claim}`

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sigBuf = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  const jwt = `${unsigned}.${base64url(new Uint8Array(sigBuf))}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  const json = await res.json()
  if (!json.access_token) {
    throw new Error('OAuth token error: ' + JSON.stringify(json))
  }
  cachedToken = {
    token: json.access_token,
    exp: now + (json.expires_in ?? 3600),
  }
  return json.access_token
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json()
    // Database Webhook payloads look like { type, table, record, old_record }.
    const record = payload.record ?? payload
    const conversationId = record.conversation_id as string | undefined
    const fromId = record.from_id as string | undefined
    const text = (record.message as string | undefined) ?? 'New message'
    if (!conversationId || !fromId) {
      return new Response('skip: missing fields', { status: 200 })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // Receiver = the other participant in the conversation.
    const { data: parts } = await supabase
      .from('participants')
      .select('user_id')
      .eq('conversation_id', conversationId)
      .neq('user_id', fromId)
    const receiverId = parts?.[0]?.user_id as string | undefined
    if (!receiverId) return new Response('skip: no receiver', { status: 200 })

    const { data: receiver } = await supabase
      .from('profiles')
      .select('push_token')
      .eq('id', receiverId)
      .single()
    const token = receiver?.push_token as string | undefined
    if (!token) return new Response('skip: no push token', { status: 200 })

    const { data: sender } = await supabase
      .from('profiles')
      .select('username, full_name')
      .eq('id', fromId)
      .single()
    const senderName = (sender?.username as string) ||
      (sender?.full_name as string) || 'Someone'

    const sa = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!)
    const accessToken = await getAccessToken(sa)

    const fcmRes = await fetch(FCM_ENDPOINT, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: senderName, body: text },
          data: {
            type: 'message',
            chat_id: conversationId,
            sender_id: fromId,
          },
          // No channel_id: let FCM use its auto-created default channel so the
          // notification always shows even if the app hasn't registered a
          // custom channel.
          android: {
            priority: 'high',
            notification: { sound: 'default' },
          },
        },
      }),
    })
    const fcmBody = await fcmRes.text()
    return new Response(
      JSON.stringify({ ok: fcmRes.ok, status: fcmRes.status, fcm: fcmBody }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    // Return 200 so the webhook is not retried forever on a bad payload.
    return new Response(JSON.stringify({ error: String(e) }), { status: 200 })
  }
})
