// Runs the Commuter app's Firestore queries as a real signed-in user (rules
// applied), to debug PERMISSION_DENIED without the phone. Uses the Admin SDK only
// to mint a custom token for the user; the queries themselves go through the
// public Firestore REST API with that user's ID token.
// Usage: node rules_probe.mjs <uid>

import { readFileSync } from 'node:fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const uid = process.argv[2];
if (!uid) throw new Error('usage: node rules_probe.mjs <uid>');

const keyPath = process.env.FIBUS_ADMIN_KEY ?? 'D:/FIBUS/secrets/fibus-admin.json';
const projectId = 'fibus-84a9b';
const gs = JSON.parse(readFileSync('../../android/app/src/commuter/google-services.json', 'utf8'));
const apiKey = gs.client[0].api_key[0].current_key;

initializeApp({ credential: cert(JSON.parse(readFileSync(keyPath, 'utf8'))) });
const customToken = await getAuth().createCustomToken(uid);

const signIn = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ token: customToken, returnSecureToken: true }),
});
const auth = await signIn.json();
if (!auth.idToken) throw new Error(`sign-in failed: ${JSON.stringify(auth.error ?? auth)}`);

const base = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
const headers = { Authorization: `Bearer ${auth.idToken}`, 'Content-Type': 'application/json' };

const eq = (field, value) => ({ fieldFilter: { field: { fieldPath: field }, op: 'EQUAL', value } });
const str = (v) => ({ stringValue: v });

async function query(label, structuredQuery) {
  const res = await fetch(`${base}:runQuery`, { method: 'POST', headers, body: JSON.stringify({ structuredQuery }) });
  const body = await res.json();
  const err = Array.isArray(body) ? body.find((x) => x.error)?.error : body.error;
  const docs = Array.isArray(body) ? body.filter((x) => x.document).length : 0;
  console.log(`${res.ok && !err ? 'OK  ' : 'FAIL'} ${label}: ${err ? `${err.status} ${err.message}` : `${docs} doc(s)`}`);
}

async function get(label, path) {
  const res = await fetch(`${base}/${path}`, { headers });
  const body = await res.json();
  console.log(`${res.ok || res.status === 404 ? 'OK  ' : 'FAIL'} ${label}: ${res.ok ? 'found' : `${res.status} ${body.error?.status ?? ''}`}`);
}

const today = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });

await get('get own profile', `users/${uid}`);
await get('get own commute preference', `users/${uid}/commutePreferences/primary`);
await query('active routes', { from: [{ collectionId: 'routes' }], where: eq('isActive', { booleanValue: true }) });
await query('buses on route_9_isnapur', {
  from: [{ collectionId: 'buses' }],
  where: { compositeFilter: { op: 'AND', filters: [
    { fieldFilter: { field: { fieldPath: 'routeIds' }, op: 'ARRAY_CONTAINS', value: str('route_9_isnapur') } },
    eq('isActive', { booleanValue: true }),
  ] } },
});
await query('own operator assignments', { from: [{ collectionId: 'operatorAssignments' }], where: eq('operatorUid', str(uid)) });
await query(`today's alert session (${today})`, {
  from: [{ collectionId: 'alertSessions' }],
  where: { compositeFilter: { op: 'AND', filters: [
    eq('commuterUid', str(uid)),
    eq('serviceDate', str(today)),
    { fieldFilter: { field: { fieldPath: 'status' }, op: 'IN', value: { arrayValue: { values: [str('monitoring'), str('advance_sent')] } } } },
  ] } },
  limit: 1,
});
await query('alert sessions, commuterUid only', { from: [{ collectionId: 'alertSessions' }], where: eq('commuterUid', str(uid)) });

process.exit(0);
