// Prints changes to liveBuses/{busId} in the Realtime Database, so a tester can
// confirm the Tracker app's writes arrive. Location is rounded to ~100 m.
// Usage: node watch_live.mjs [busId] [seconds]

import { readFileSync } from 'node:fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getDatabase } from 'firebase-admin/database';

const busId = process.argv[2] ?? 'bus_9';
const seconds = Number(process.argv[3] ?? 300);
const data = JSON.parse(readFileSync('seed-data.json', 'utf8'));
const keyPath = process.env.FIBUS_ADMIN_KEY ?? 'D:/FIBUS/secrets/fibus-admin.json';
initializeApp({ credential: cert(JSON.parse(readFileSync(keyPath, 'utf8'))), databaseURL: data.databaseURL });

const ref = getDatabase().ref(`liveBuses/${busId}`);
console.log(`Watching liveBuses/${busId} for ${seconds}s`);
ref.on('value', (snap) => {
  const v = snap.val();
  if (!v) return console.log(new Date().toISOString(), 'no data');
  const age = v.lastServerHeartbeat ? Math.round((Date.now() - v.lastServerHeartbeat) / 1000) : null;
  console.log(new Date().toISOString(),
    `status=${v.status} gen=${v.sessionGeneration} op=${String(v.operatorUid).slice(0, 6)}…`,
    `pos=${v.latitude?.toFixed(3)},${v.longitude?.toFixed(3)} acc=${v.accuracy?.toFixed?.(0)}m`,
    `heartbeatAge=${age}s`);
});
setTimeout(() => process.exit(0), seconds * 1000);
