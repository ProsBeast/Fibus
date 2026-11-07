// Reads back the seeded pilot data and prints a short summary.
// Usage: node verify.mjs [--key <service-account.json>] [--uid <commuter uid>]

import { readFileSync } from 'node:fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getDatabase } from 'firebase-admin/database';

const args = process.argv.slice(2);
const argValue = (flag) => {
  const i = args.indexOf(flag);
  return i >= 0 ? args[i + 1] : undefined;
};

const data = JSON.parse(readFileSync('seed-data.json', 'utf8'));
const keyPath = argValue('--key') ?? process.env.FIBUS_ADMIN_KEY ?? 'D:/FIBUS/secrets/fibus-admin.json';
initializeApp({ credential: cert(JSON.parse(readFileSync(keyPath, 'utf8'))), databaseURL: data.databaseURL });

const db = getFirestore();
const rtdb = getDatabase();

for (const name of ['stops', 'routes', 'buses', 'operatorAssignments']) {
  const snap = await db.collection(name).get();
  console.log(`${name}: ${snap.size} doc(s) -> ${snap.docs.map((d) => d.id).join(', ')}`);
}

const route = (await db.doc(`routes/${data.routes[0].id}`).get()).data();
console.log(`route ${data.routes[0].id}: ${route.orderedStopIds.length} stops, ${route.polylinePoints.length} path points, quality=${route.routeQualityStatus}`);

const ops = (await rtdb.ref('busOperators').get()).val();
console.log(`RTDB busOperators: ${JSON.stringify(ops)}`);

const uid = argValue('--uid');
if (uid) {
  const user = await db.doc(`users/${uid}`).get();
  const pref = await db.doc(`users/${uid}/commutePreferences/primary`).get();
  const p = pref.data() ?? {};
  // Only report presence: home coordinates are personal data (PRD section 12).
  console.log(`user profile: ${user.exists ? 'exists' : 'missing'} (role=${user.data()?.role ?? '-'})`);
  console.log(`commute preference: ${pref.exists ? 'exists' : 'missing'}, home pin set=${Boolean(p.homeLatitude && p.homeLongitude)}, busId=${p.busId || '-'}, stop=${p.boardingStopId || '-'}`);
}

process.exit(0);
