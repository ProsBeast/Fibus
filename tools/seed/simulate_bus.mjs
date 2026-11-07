// Simulates the Tracker app for testing: drives a bus along its seeded route
// polyline and writes tracker-format fixes to liveBuses/{busId} every 5 s.
// Ends the trip (status 'ended') when it finishes or on Ctrl+C.
//
// Usage: node simulate_bus.mjs [--bus bus_9] [--from isnapur] [--pace 1]
//                              [--minutes 20] [--interval 5]
//   --from      stop id to start at (default: first stop)
//   --pace      speed relative to the timetable (2 = twice as fast, 0.5 = late)
//   --minutes   stop after this many real minutes (default: run to last stop)
//   --stall-at  stop id where the bus waits --stall-minutes (simulates traffic)
//
// Admin credentials bypass the RTDB rules, so this writes as the bus's
// seeded operator UID only to keep the payload shape identical.

import { readFileSync } from 'node:fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getDatabase, ServerValue } from 'firebase-admin/database';
import { getFirestore } from 'firebase-admin/firestore';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, a, i, all) => {
    if (a.startsWith('--')) acc.push([a.slice(2), all[i + 1]]);
    return acc;
  }, []),
);
const busId = args.bus ?? 'bus_9';
const pace = Number(args.pace ?? 1);
const intervalSec = Number(args.interval ?? 5);
const maxMinutes = args.minutes ? Number(args.minutes) : Infinity;
const stallAt = args['stall-at'];
const stallMinutes = Number(args['stall-minutes'] ?? 5);

const seed = JSON.parse(readFileSync('seed-data.json', 'utf8'));
const keyPath = process.env.FIBUS_ADMIN_KEY ?? 'D:/FIBUS/secrets/fibus-admin.json';
initializeApp({ credential: cert(JSON.parse(readFileSync(keyPath, 'utf8'))), databaseURL: seed.databaseURL });
const db = getDatabase();
const fs = getFirestore();

const bus = (await fs.doc(`buses/${busId}`).get()).data();
if (!bus) throw new Error(`no bus ${busId}`);
const route = (await fs.doc(`routes/${bus.routeIds[0]}`).get()).data();
const stopDocs = await Promise.all(route.orderedStopIds.map((id) => fs.doc(`stops/${id}`).get()));
const stops = stopDocs.map((d) => ({ id: d.id, ...d.data() }));
const line = route.polylinePoints.map((p) => [p.lat, p.lng]);
const operatorUid = (bus.operatorUids ?? [])[0] ?? 'simulator';

const R = 6371000;
const rad = (d) => (d * Math.PI) / 180;
const hav = ([a, b], [c, d]) => {
  const x = Math.sin(rad(c - a) / 2) ** 2 + Math.cos(rad(a)) * Math.cos(rad(c)) * Math.sin(rad(d - b) / 2) ** 2;
  return 2 * R * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
};
const cum = [0];
for (let i = 1; i < line.length; i++) cum.push(cum[i - 1] + hav(line[i - 1], line[i]));

// Stop progress = nearest polyline vertex, kept non-decreasing.
let last = 0;
const stopAlong = stops.map((s) => {
  let best = 0, bestD = Infinity;
  for (let i = 0; i < line.length; i++) {
    const d = hav([s.latitude, s.longitude], line[i]);
    if (d < bestD) { bestD = d; best = i; }
  }
  last = Math.max(last, cum[best]);
  return last;
});
const mins = (hhmm) => { const [h, m] = hhmm.split(':').map(Number); return h * 60 + m; };
const stopClock = stops.map((s) => (mins(s.scheduledArrivalLocalTime) - mins(stops[0].scheduledArrivalLocalTime)) * 60);

const pointAt = (along) => {
  let i = cum.findIndex((c) => c >= along);
  if (i <= 0) return line[Math.max(0, i)];
  const t = (along - cum[i - 1]) / (cum[i] - cum[i - 1] || 1);
  return [line[i - 1][0] + t * (line[i][0] - line[i - 1][0]), line[i - 1][1] + t * (line[i][1] - line[i - 1][1])];
};
// Timetable clock (s) -> route progress (m).
const alongAtClock = (clock) => {
  for (let i = 1; i < stops.length; i++) {
    if (clock <= stopClock[i]) {
      const f = (clock - stopClock[i - 1]) / (stopClock[i] - stopClock[i - 1] || 1);
      return stopAlong[i - 1] + f * (stopAlong[i] - stopAlong[i - 1]);
    }
  }
  return stopAlong.at(-1);
};

const fromIndex = Math.max(0, stops.findIndex((s) => s.id === (args.from ?? stops[0].id)));
const stallIndex = stallAt ? stops.findIndex((s) => s.id === stallAt) : -1;
const ref = db.ref(`liveBuses/${busId}`);
const prev = (await ref.get()).val();
const generation = (prev?.sessionGeneration ?? 0) + 1;

let ended = false;
async function end() {
  if (ended) return;
  ended = true;
  await ref.update({ status: 'ended', lastServerHeartbeat: ServerValue.TIMESTAMP });
  await db.ref(`activeSessions/${busId}`).remove();
  console.log('trip ended');
  process.exit(0);
}
process.on('SIGINT', end);
process.on('SIGTERM', end);

await db.ref(`activeSessions/${busId}`).set({ operatorUid, sessionGeneration: generation, startedAt: ServerValue.TIMESTAMP });
console.log(`Simulating ${busId} from ${stops[fromIndex].id}, pace x${pace}, gen ${generation}, ${stops.length} stops, ${(cum.at(-1) / 1000).toFixed(1)} km`);

const startMs = Date.now();
let lastStopLogged = -1;
const tick = async () => {
  const elapsed = (Date.now() - startMs) / 1000;
  if (elapsed / 60 > maxMinutes) return end();
  let clock = stopClock[fromIndex] + elapsed * pace;
  if (stallIndex >= 0 && clock > stopClock[stallIndex]) {
    clock = Math.max(stopClock[stallIndex], clock - stallMinutes * 60 * pace);
  }
  const along = alongAtClock(clock);
  const [lat, lng] = pointAt(along);
  await ref.set({
    status: 'tracking',
    latitude: lat,
    longitude: lng,
    accuracy: 8,
    speed: 8 * pace,
    heading: 0,
    timestamp: Date.now(),
    lastServerHeartbeat: ServerValue.TIMESTAMP,
    sessionGeneration: generation,
    operatorUid,
  });
  const passed = stopAlong.findLastIndex((s) => s <= along + 1);
  if (passed !== lastStopLogged) {
    lastStopLogged = passed;
    console.log(new Date().toISOString(), `at/after stop ${stops[passed].id} (${(along / 1000).toFixed(2)} km)`);
  }
  if (along >= stopAlong.at(-1)) return end();
};
await tick();
setInterval(() => tick().catch((e) => console.error('write failed', e.message)), intervalSec * 1000);
