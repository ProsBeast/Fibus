// Fibus admin seed script (PRD sections 7.6 and 11).
//
// Writes the pilot bus, route, ordered stops and operator assignments to
// Firestore, mirrors operator assignments into the Realtime Database
// (busOperators/{busId}/{uid} = true, which the RTDB rules check), and
// generates candidate road geometry for each route from its ordered stops.
//
// The Admin SDK bypasses security rules, so keep the service-account key
// outside the project and never commit it.
//
// Usage:
//   node seed.mjs [--data seed-data.json] [--key <service-account.json>] [--dry-run]
//
// The key path can also come from the FIBUS_ADMIN_KEY environment variable.

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const args = process.argv.slice(2);
const argValue = (flag) => {
  const i = args.indexOf(flag);
  return i >= 0 ? args[i + 1] : undefined;
};

const dryRun = args.includes('--dry-run');
const dataPath = resolve(argValue('--data') ?? 'seed-data.json');
const keyPath = argValue('--key') ?? process.env.FIBUS_ADMIN_KEY ?? 'D:/FIBUS/secrets/fibus-admin.json';

const data = JSON.parse(readFileSync(dataPath, 'utf8'));
validate(data);

const geometry = {};
for (const route of data.routes) {
  geometry[route.id] = await generateGeometry(route, data.stops);
}

printPlan(data, geometry);

if (dryRun) {
  console.log('\nDry run: nothing was written.');
  process.exit(0);
}

const { initializeApp, cert } = await import('firebase-admin/app');
const { getFirestore, FieldValue } = await import('firebase-admin/firestore');
const { getDatabase } = await import('firebase-admin/database');

const serviceAccount = JSON.parse(readFileSync(keyPath, 'utf8'));
if (serviceAccount.project_id !== data.projectId) {
  throw new Error(`Key is for project "${serviceAccount.project_id}", but seed data targets "${data.projectId}".`);
}

initializeApp({ credential: cert(serviceAccount), databaseURL: data.databaseURL });
const db = getFirestore();
const rtdb = getDatabase();
const now = FieldValue.serverTimestamp();

const batch = db.batch();

for (const stop of data.stops) {
  batch.set(db.doc(`stops/${stop.id}`), {
    name: stop.name,
    latitude: stop.latitude,
    longitude: stop.longitude,
    sequenceIndex: stop.sequenceIndex,
    scheduledArrivalLocalTime: stop.scheduledArrivalLocalTime,
    isActive: true,
    updatedAt: now,
  }, { merge: true });
}

for (const route of data.routes) {
  const geo = geometry[route.id];
  batch.set(db.doc(`routes/${route.id}`), {
    name: route.name,
    direction: route.direction ?? '',
    timeZone: data.timeZone,
    isActive: true,
    orderedStopIds: route.orderedStopIds,
    polylinePoints: geo.points,
    geometryVersion: route.geometryVersion ?? 1,
    generatedFromProvider: geo.provider,
    routeQualityStatus: geo.points.length ? 'generated_unreviewed' : 'missing',
    geometryUpdatedAt: now,
    updatedAt: now,
  }, { merge: true });
}

for (const bus of data.buses) {
  const operatorUids = data.operators.filter((o) => o.busId === bus.id).map((o) => o.uid);
  batch.set(db.doc(`buses/${bus.id}`), {
    displayName: bus.displayName,
    routeIds: bus.routeIds,
    isActive: true,
    operatorUids,
    trackerReminderTime: bus.trackerReminderTime,
    serviceDays: bus.serviceDays,
    timeZone: data.timeZone,
    updatedAt: now,
  }, { merge: true });
}

for (const op of data.operators) {
  batch.set(db.doc(`operatorAssignments/${op.busId}_${op.uid}`), {
    assignmentId: `${op.busId}_${op.uid}`,
    busId: op.busId,
    operatorUid: op.uid,
    isActive: true,
    assignedBy: 'seed-script',
    assignedAt: now,
  }, { merge: true });
}

await batch.commit();

const rtdbOperators = {};
for (const op of data.operators) {
  rtdbOperators[`busOperators/${op.busId}/${op.uid}`] = true;
}
await rtdb.ref().update(rtdbOperators);

console.log('\nSeed complete.');
process.exit(0);

// ---------------------------------------------------------------------------

function validate(d) {
  const fail = (msg) => { throw new Error(`seed data: ${msg}`); };
  for (const key of ['projectId', 'databaseURL', 'timeZone', 'stops', 'routes', 'buses', 'operators']) {
    if (d[key] === undefined) fail(`missing "${key}"`);
  }
  const stopIds = new Set(d.stops.map((s) => s.id));
  const routeIds = new Set(d.routes.map((r) => r.id));
  const busIds = new Set(d.buses.map((b) => b.id));

  for (const s of d.stops) {
    if (!(Math.abs(s.latitude) <= 90 && Math.abs(s.longitude) <= 180)) fail(`stop ${s.id} has invalid coordinates`);
    if (!/^\d{2}:\d{2}$/.test(s.scheduledArrivalLocalTime ?? '')) fail(`stop ${s.id} needs scheduledArrivalLocalTime as HH:MM`);
  }
  for (const r of d.routes) {
    for (const id of r.orderedStopIds) if (!stopIds.has(id)) fail(`route ${r.id} references unknown stop ${id}`);
  }
  for (const b of d.buses) {
    for (const id of b.routeIds) if (!routeIds.has(id)) fail(`bus ${b.id} references unknown route ${id}`);
  }
  for (const o of d.operators) {
    if (!busIds.has(o.busId)) fail(`operator ${o.uid} assigned to unknown bus ${o.busId}`);
  }
}

// Candidate road geometry through the ordered stops (PRD 9.1). Must be
// reviewed against the real bus path before trusting ETAs built on it.
async function generateGeometry(route, stops) {
  const byId = Object.fromEntries(stops.map((s) => [s.id, s]));
  const coords = route.orderedStopIds.map((id) => `${byId[id].longitude},${byId[id].latitude}`).join(';');
  const url = `https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=geojson`;
  try {
    const res = await fetch(url, { headers: { 'User-Agent': 'fibus-seed (pilot)' } });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const body = await res.json();
    const line = body.routes?.[0];
    if (!line) throw new Error('no route returned');
    return {
      provider: 'osrm-driving',
      distanceMeters: Math.round(line.distance),
      durationSeconds: Math.round(line.duration),
      points: line.geometry.coordinates.map(([lng, lat]) => ({ lat, lng })),
    };
  } catch (e) {
    console.warn(`Route ${route.id}: geometry generation failed (${e.message}); saving without geometry.`);
    return { provider: 'none', distanceMeters: 0, durationSeconds: 0, points: [] };
  }
}

function printPlan(d, geo) {
  console.log(`Project: ${d.projectId}   Time zone: ${d.timeZone}`);
  for (const r of d.routes) {
    const g = geo[r.id];
    console.log(`\nRoute ${r.id} "${r.name}"  (${g.points.length} path points, ${(g.distanceMeters / 1000).toFixed(1)} km, ~${Math.round(g.durationSeconds / 60)} min by car)`);
    r.orderedStopIds.forEach((id, i) => {
      const s = d.stops.find((x) => x.id === id);
      console.log(`  ${i + 1}. ${s.scheduledArrivalLocalTime}  ${s.name}  (${s.latitude}, ${s.longitude})`);
    });
  }
  for (const b of d.buses) {
    const ops = d.operators.filter((o) => o.busId === b.id).map((o) => o.uid);
    console.log(`\nBus ${b.id} "${b.displayName}"  routes: ${b.routeIds.join(', ')}  reminder: ${b.trackerReminderTime}  operators: ${ops.join(', ') || '(none)'}`);
  }
}
