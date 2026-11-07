# Fibus Product Requirements Document (PRD)

**Version:** 1.0  
**Status:** Draft for implementation planning  
**Prepared:** 26 October 2026  
**Product:** Fibus  
**Platforms:** Android, two Flutter apps  
**Pilot:** One bus, one route, one morning commute; architecture supports multiple registered buses/routes

> **Product promise:** Fibus helps a commuter decide when to leave home by combining the bus's predicted arrival at their stop with their own traffic-aware scooter travel time. When live tracking is unavailable, it says so and falls back to the published schedule instead of presenting stale data as truth.

---

## 1. Executive summary

Bus commuters currently rely on timetable estimates, WhatsApp live location, mental calculations, and repeated checking to avoid missing the bus. Fibus reduces this uncertainty with two Android apps:

1. **Fibus Tracker:** used by a designated student or passenger on the bus to publish its GPS location during an active trip.
2. **Fibus Commuter:** used by a signed-in commuter to choose a registered bus/route and stop, save a home pin, and receive an actionable departure recommendation.

The commuter app estimates the bus's arrival at the selected stop, estimates the user's scooter travel time from home to that stop, subtracts a five-minute target arrival buffer, and adds a safety margin that grows when the travel-time estimate is uncertain. It sends a configurable advance warning followed by a **Leave now** alert. If the bus is predicted to be at least five minutes late, the app updates the departure recommendation automatically.

The pilot uses a manually configured bus, route, stops, timetable, and assigned tracker operators. It does not require official integration with a bus operator. Scheduled tracking is a reminder, not unattended GPS startup: at the configured reminder time, the assigned operator is notified and must open Tracker and tap **Start tracking**. This is deliberate because Android restricts starting location foreground services from the background in many situations. [1]

## 2. Problem statement

The commuter does not know whether the bus will arrive early, on time, or late. A timetable such as **7:50 AM** describes the expected arrival at the boarding stop but does not provide a reliable live countdown. The commuter currently checks a shared location and mentally estimates when to leave. A wrong estimate can cause a missed bus; a conservative estimate creates unnecessary waiting.

Fibus should replace repeated manual calculations with a clear answer to one question: **“When should I leave home to reach my stop shortly before this bus arrives?”**

## 3. Goals and non-goals

### 3.1 Goals

- Recommend a departure time from home using a bus ETA, scooter travel duration, a five-minute stop-arrival target, and a dynamic uncertainty margin.
- Make the recommendation react to significant changes in bus arrival estimates.
- Show whether an ETA is live, warming up, stale, or schedule-based.
- Send an advance warning at a commuter-configurable interval and a separate Leave now notification.
- Let a designated operator start tracking manually, with a scheduled reminder and a controlled recovery/hand-over path.
- Support registered bus and route records while keeping registration manual during the pilot.
- Validate whether the product reliably balances fewer missed buses and less waiting.

### 3.2 Non-goals for the MVP

- iOS, web commuter apps, or a public commercial marketplace.
- Public self-service bus registration or full transport-management administration.
- Ticketing, fares, payments, seat booking, bus occupancy, route planning for the entire journey, or chat.
- Return-trip automation. The MVP covers the morning journey only.
- Guaranteed-to-the-second alerts or guaranteed bus arrival predictions.
- Automatic GPS tracking startup while the Tracker app is closed.
- Machine-learning ETA prediction. Begin with a transparent rule-based model and validate it with real trips.
- Crowdsourced simultaneous GPS fusion from several devices. One authoritative tracker is active per bus; a replacement can take over after the current feed becomes stale.

## 4. Decisions confirmed during product discovery

| Topic | Confirmed decision |
|---|---|
| Product structure | Two separate Android apps: Tracker and Commuter |
| Pilot size | One bus and one route; data model can represent multiple buses and routes |
| Bus/operator | A student or passenger may operate Tracker |
| Bus/route setup | Buses, routes, stops, timetables and operator assignments are manually configured in the backend |
| Bus selection | Commuter and operator independently select the same registered bus; no trip QR/code in MVP |
| Authentication | Google sign-in |
| Location access | Signed-in users can view registered buses and active trips |
| GPS publishing permission | Only designated operators assigned to a bus can start tracking it |
| Commuter home | Drop a pin on a map and save it |
| Boarding stop | Choose a route, then a stop from that route's ordered stop list |
| Routine | Save preferred commute; commuter activates alerts each morning |
| Journey scope | Morning journey only |
| Advance warning | Configurable in settings; initial default proposed as 10 minutes |
| Primary action | Two-stage notifications: advance warning, then Leave now |
| Scooter duration | Google Routes API two-wheeler mode, with a dynamic safety margin |
| Route geometry | Generate road geometry from ordered stops and let the admin correct/approve it |
| Tracker start | Backend sends a configured-time reminder; operator opens the app and taps Start tracking |
| Tracker stop | Operator can stop tracking manually; backend also closes/marks old trips under defined rules |
| Stale location | No fresh valid GPS update for 60 seconds marks live data stale and makes a replacement operator eligible to take over |
| Late bus | Automatically recalculate departure time; 5+ minutes later than schedule is a significant delay |
| Tracker not started | Warn commuter, use labelled schedule fallback, remind operator to start tracking |
| Target bus arrival | Reach the boarding stop about 5 minutes before the predicted bus arrival; reference schedule is 7:50 AM at the stop, target 7:45 AM |
| Success definition | Balance reliable departure recommendations, avoiding missed buses, and reducing unnecessary waiting |

## 5. Explicit assumptions to validate

The following items were not explicitly decided and are implementation assumptions, not confirmed user requirements.

1. **Initial default warning:** 10 minutes before the current recommended departure time; commuter can change it.
2. **Time zone:** store instants in UTC and evaluate schedules in the route's configured local time zone. The initial pilot is expected to use India Standard Time, but the route configuration must own the time zone.
3. **Tracker reminder time:** configured separately from the scheduled arrival time at the stop. The 7:50 AM stop arrival is not the tracker start time.
4. **Commuter activity:** the commuter taps **Activate alerts for today** after opening the app each morning. The saved route and home pin do not imply that monitoring is active every day.
5. **Base safety margin:** initial proposed default is 2 minutes, with an additional uncertainty allowance up to 5 minutes. These values must be tuned during the pilot.
6. **Meaningful recommendation shift:** refresh the UI on every accepted ETA recalculation. Avoid push-notification churn; send a new plan-change notification only when the recommendation shifts materially (initial proposal: 5 minutes or more) or the app detects a significant new delay.
7. **Admin setup tooling:** one-route pilot can use an internal seed/configuration script plus a route preview/correction utility. A full public administration portal is out of scope.
8. **Map and route licensing:** enable Google Maps Platform billing and comply with current provider display, attribution, caching, and terms requirements before release.
9. **Reliability target:** notification delivery is best-effort and cannot be guaranteed exactly at a wall-clock second. The UI must be clear when notifications are disabled or permissions are missing.
10. **Departure data quality:** Google Routes API two-wheeler mode supports India but remains in beta and has higher billing rates. Treat its duration as an estimate and verify traffic-aware results, coverage, and cost in the actual pilot area before relying on it. [2][3][4]

## 6. Users and roles

| Role | Needs | Permissions |
|---|---|---|
| Commuter | Know whether to leave now, later, or rely on schedule fallback | Sign in; read registered buses/routes and active trips; maintain own home pin/commute preferences; activate or cancel own alert session |
| Designated tracker operator | Publish the selected bus's location during the trip | Sign in; select assigned bus; receive start reminder; start/stop tracking; request/perform takeover when eligible |
| Administrator/configurator | Keep pilot data correct and assign authorized operators | Create/edit buses, routes, ordered stops, timetable, route geometry, tracker assignment, tracker reminder time and schedule |
| Backend service | Reconcile live locations, compute ETAs, enforce state transitions, send notifications | Privileged server identity only; secrets never reside in app clients |

Authentication proves identity; it does not by itself authorize a user to publish a bus location. Firebase database rules and server-side checks must enforce assignment-based permissions. [5]

## 7. User flows

### 7.1 First-time commuter setup

1. Open Commuter and sign in with Google.
2. Grant notification permission when the value is clear and the user is ready to enable alerts. On Android 13+, posting notifications requires runtime permission. [6]
3. Drop and save a home pin on the map.
4. Select a registered route from a list, then select a boarding stop on that route.
5. Confirm the saved commute and choose the advance-warning interval.
6. See whether the bus currently has an active tracker, whether GPS is fresh, and whether the app currently has enough information to calculate a live ETA.

### 7.2 Daily commuter flow

1. Open Commuter and tap **Activate alerts for today**.
2. App loads saved home, route, stop, timetable, alert settings, and current trip state.
3. If live data is fresh and route matching is credible, display live bus ETA and an estimated scooter journey time.
4. Calculate the target arrival time and recommended departure time.
5. Send an advance warning at `recommendedDeparture - configuredWarningLead`.
6. Send **Leave now** at the recommended departure time, unless the plan has been updated and the user has not yet received the applicable action.
7. Recalculate when the bus ETA changes, the route location advances, or the scooter duration is refreshed.
8. When the selected bus reaches the stop, the trip ends, or the commuter cancels, mark today's alert session complete.

### 7.3 Tracker operator flow

1. Operator receives a reminder at the route's configured tracker-start reminder time.
2. Open Tracker and sign in with Google.
3. Select an assigned registered bus.
4. Review the trip/route identity and tap **Start tracking**.
5. Grant location permission and keep the app's persistent foreground-service notification visible while tracking is active.
6. App publishes timestamped GPS fixes and heartbeats at a configurable interval (initial target: every 5-10 seconds while moving and the device/network permit).
7. Operator can tap **End trip** at the end of tracking.
8. Backend closes the active session, rejects later writes from the expired session, and marks the bus as not actively tracked.

### 7.4 Tracker reminder and no-start flow

1. A backend scheduled job checks whether a trip is due to be tracked.
2. At the configured reminder time, send a push reminder to assigned operator(s).
3. If tracking has not started, the Commuter app shows **Live tracking has not started** and offers the published timetable as a clearly labelled fallback.
4. Repeated reminders should be rate-limited; do not send a reminder every minute indefinitely.
5. The configured reminder time is a reminder, not a guarantee that GPS begins on time.

### 7.5 Stale GPS and takeover flow

1. When no accepted GPS fix has arrived for 60 seconds, mark the feed stale.
2. Stop treating the last point as current; show the last update time and switch live ETA to unavailable/stale status.
3. Commuter receives a clear stale-data warning and a schedule fallback.
4. A designated replacement operator can request takeover.
5. Backend performs an atomic handover: increment session generation or issue a new active `tripId`, mark the previous tracker session superseded, and assign the new operator.
6. Reject writes from the previous session after handover, even if its phone reconnects.
7. When fresh points from the replacement are sufficient and route-matched, return to live ETA.

### 7.6 Administrator route setup

1. Create a bus record and assign a route.
2. Add stops in the actual order travelled by the bus, including stable IDs, coordinates, timetable arrival times, and optional dwell-time assumptions.
3. Generate road geometry segment-by-segment between ordered stops using a routing provider.
4. Preview the generated path against expected road usage and adjust with route waypoints, alternative segment geometry, or an edited polyline where the generated road path is wrong.
5. Save and approve the route geometry version before a pilot trip is tracked.
6. Assign designated tracker operators and configure tracker-start reminder time separately from stop arrival time.

## 8. Functional requirements

Priority legend: **P0** required for pilot; **P1** valuable if time allows; **Later** excluded from the first pilot.

### 8.1 Identity, configuration and access

| ID | Priority | Requirement | Acceptance summary |
|---|---|---|---|
| FR-01 | P0 | Google sign-in for both apps | A user can sign in, stay signed in, and sign out; failed authentication is handled safely. |
| FR-02 | P0 | Manually configured bus and route catalog | App lists only backend-configured buses/routes/stops. No public registration. |
| FR-03 | P0 | Route-stop order | Each route has ordered stops and a schedule; selected stop belongs to selected route. |
| FR-04 | P0 | Designated tracker assignment | Only an assigned operator can start, stop or take over tracking for a bus. |
| FR-05 | P0 | Signed-in read access | Signed-in commuters can read allowed registered buses, routes, active trip summaries, and current location. |
| FR-06 | P0 | Enforced database rules | Unauthenticated reads/writes and unauthorized location writes are denied. Server-only fields cannot be edited by clients. |
| FR-07 | P0 | Home pin and commute settings | Commuter can save/update a home coordinate and preferred bus, route, stop, and warning lead time. |

### 8.2 Bus tracking and route data

| ID | Priority | Requirement | Acceptance summary |
|---|---|---|---|
| FR-08 | P0 | Scheduled start reminder | Assigned operator receives a reminder at the configured time when notifications are available. |
| FR-09 | P0 | Explicit Start tracking | Tracking begins only after the operator taps Start tracking and required permissions are granted. |
| FR-10 | P0 | Foreground location service | During an active trip, Tracker exposes a persistent notification and handles location-service stop/error states. |
| FR-11 | P0 | Timestamped GPS updates | Each fix contains coordinates, device/server timestamp, accuracy, optional speed/heading, bus, trip and operator/session IDs. |
| FR-12 | P0 | Stop tracking | Operator can end the trip; location publishing stops and the active feed is closed. |
| FR-13 | P0 | Stale-feed detection | No fresh accepted location for 60 seconds marks the feed stale and triggers warning/fallback behaviour. |
| FR-14 | P0 | Controlled takeover | Replacement operator may take over after the stale threshold; old session writes are rejected. |
| FR-15 | P0 | Route geometry generation | Generate a candidate path from ordered stops and provide a way to review and correct the path before approval. |
| FR-16 | P0 | Route-progress calculation | Backend projects GPS fixes onto the approved route geometry and estimates progress toward the selected stop. |
| FR-17 | P1 | Route mismatch diagnostics | Flag repeated GPS points far from the approved path so the admin can correct route geometry or investigate detours. |

### 8.3 ETA, departure recommendation and notifications

| ID | Priority | Requirement | Acceptance summary |
|---|---|---|---|
| FR-18 | P0 | Live bus ETA | Show ETA at the selected stop only when live feed freshness and route matching meet minimum quality checks. |
| FR-19 | P0 | ETA status labels | Distinguish live, warming up, stale, no tracker, schedule fallback, and completed-trip states. |
| FR-20 | P0 | Scooter journey estimate | Call the route service from a secured backend function; use two-wheeler mode where supported and cache briefly to control cost. |
| FR-21 | P0 | Dynamic safety margin | Calculate a margin that increases with estimated commute-time uncertainty; initial parameters are configurable and pilot-tuned. |
| FR-22 | P0 | Departure recommendation | Compute the latest leave-by time required to reach the stop about five minutes before predicted bus arrival plus the safety margin. |
| FR-23 | P0 | Advance warning | Send at the configured lead time before the current leave-by time. Initial default is 10 minutes. |
| FR-24 | P0 | Leave now notification | Send a prominent Leave now action when the latest leave-by time is reached or already passed. |
| FR-25 | P0 | Delay detection and recalculation | A live ETA 5+ minutes later than scheduled is marked a significant delay; recompute departure automatically. |
| FR-26 | P0 | Duplicate suppression | Do not send repeated copies of the same alert event when multiple GPS updates arrive. |
| FR-27 | P0 | Schedule fallback | If live tracking is absent/stale, show timetable time as schedule-based, with explicit status and last update where available. |
| FR-28 | P0 | Operator start reminder | If a scheduled trip has not started, notify assigned operator(s), with repeated reminders rate-limited. |
| FR-29 | P0 | Notification permission status | Explain when Android notifications are disabled or unavailable; do not imply an alert can be delivered if permissions are off. |
| FR-30 | P1 | Updated plan alert | If a recommendation materially shifts after a previous alert, send a rate-limited update with the new plan. |
| FR-31 | P1 | Mark on my way | Optional one-tap state to reduce irrelevant later departure prompts once the commuter starts travelling. |

### 8.4 Operations and observability

| ID | Priority | Requirement | Acceptance summary |
|---|---|---|---|
| FR-32 | P0 | Session lifecycle | Each bus can have at most one authoritative active tracking session at a time. |
| FR-33 | P0 | Audit events | Record who started/stopped/took over a trip, stale transitions, ETA calculations, and notification decisions. |
| FR-34 | P0 | Failure visibility | Backend logs route API errors, invalid GPS, failed notification sends, and scheduler errors without logging secret values. |
| FR-35 | P0 | Configurable schedule | Store stop arrival times, tracking reminder time, days, and route time zone separately. |
| FR-36 | P1 | Admin dashboard | A small internal status view for bus setup and route correction; a full multi-tenant admin platform is not required. |

## 9. ETA and departure calculation

### 9.1 Bus route model

A route is a direction-specific ordered list of stops plus an approved polyline. A bus's live GPS coordinate is not sufficient on its own: straight-line distance to the stop can be misleading where roads curve or loop. ETA must use route progress and distance along the actual approved route.

For the pilot, generate candidate road geometry between each consecutive stop with a routing service, stitch the segment polylines in stop order, then require review/correction because a generic road router may choose a path the bus does not actually use. Store a version and approval timestamp for the geometry.

### 9.2 GPS acceptance and route projection

1. Receive a fix with latitude/longitude, timestamp, reported horizontal accuracy, optional device speed and heading.
2. Reject impossible coordinates, timestamps materially in the future, duplicate/older fixes, and fixes with poor accuracy. Initial proposed quality threshold: reject fixes worse than 100 metres accuracy; tune this in field tests.
3. Project accepted coordinates to the nearest plausible point on the approved route polyline, considering previous progress, heading, direction and permitted detours.
4. Avoid backwards progress caused by GPS jitter. Allow a small tolerance for loops or route geometry changes.
5. Calculate remaining route distance to the selected stop along the correct direction.
6. Calculate a smoothed recent speed from the last few minutes of accepted points, including stopped/slow periods where reliable. Reject impossible speed jumps and do not trust a single speed reading.

### 9.3 Bus ETA method

Use a hybrid and transparent estimate rather than `straightLineDistance / instantaneousSpeed`:

- Estimate remaining route travel time from remaining route distance and smoothed recent route progress/speed.
- Blend with route segment/time-table priors when recent observations are insufficient or the bus has only just started moving.
- Include configurable dwell-time assumptions for stops ahead if those values are available.
- Recompute when a valid location arrives and when route/session state changes. UI countdown can tick locally between server calculations, but the server's timestamped ETA is authoritative.
- If fewer than a minimum number of valid points exist, route progress is ambiguous, GPS is stale, or the bus appears off-route, label the live ETA **warming up** or **unavailable** and use the timetable fallback instead of fabricating confidence.

Initial implementation starting points (to validate): GPS update target every 5-10 seconds while moving; stale after 60 seconds; route/speed smoothing window approximately 3 minutes; discard single-point spikes. These are engineering defaults, not guaranteed accuracy levels.

### 9.4 Scooter journey duration

Use Google Routes API with `travelMode=TWO_WHEELER` for a motorized scooter/motorcycle journey. Request traffic-aware results where supported and commercially appropriate. `TRAFFIC_AWARE` can return duration based on real-time traffic; static duration may also be available for comparison. Traffic-aware requests can have higher latency and cost. [2][3]

The API call must be made from a trusted server-side function, not from the Flutter client. The server keeps the key secret, applies quotas/rate limits, validates coordinates and user/session context, and caches repeated home-to-stop requests briefly. Do not call the Routes API on every GPS ping. Refresh only during an active commuter alert session, with a proposed minimum refresh interval of about three minutes or when the user changes home/stop.

`TWO_WHEELER` routes are supported in India, but the provider documents the mode as beta and bills it at a higher rate. If the mode, current traffic details, or API request is unavailable, use a labelled fallback estimate and increase uncertainty rather than failing silently. [2][4]

### 9.5 Recommended leave-by time

Define:

- `busEta`: current predicted bus arrival at the selected boarding stop, or scheduled arrival when using fallback.
- `boardingBuffer`: 5 minutes, from product discovery.
- `scooterDuration`: current traffic-aware scooter duration estimate from home to stop.
- `safetyMargin`: base margin plus an uncertainty premium.
- `targetStopArrival = busEta - boardingBuffer`
- `recommendedLeaveBy = targetStopArrival - scooterDuration - safetyMargin`

Initial safety-margin proposal:

- `baseMargin = 2 minutes`.
- Compute `uncertainty = abs(currentTrafficAwareDuration - baselineDuration)` when both are available; otherwise use variation across recent estimates or an API/data-quality penalty.
- `uncertaintyPremium = clamp(0.5 * uncertainty, 0, 5 minutes)`.
- `safetyMargin = baseMargin + uncertaintyPremium`.

These starting values are assumptions for the pilot and should be configurable on the backend and tuned against actual trips. Do not present the formula as a statistical guarantee.

### 9.6 Delay logic

- `delayMinutes = liveBusEta - scheduledArrivalAtSelectedStop`.
- If the result is at least 5 minutes, show a **Significant delay** state and recalculate `recommendedLeaveBy` immediately.
- Recalculate on smaller live ETA changes too, but do not send a new push for every update.
- A delay may move the recommended departure later, reducing waiting. An earlier bus ETA may move it earlier, helping prevent a missed bus.
- If `recommendedLeaveBy` is already in the past, send Leave now immediately and make the lateness clear. Do not quietly shift the recommendation into the future just to avoid showing that the commuter is late.
- If the bus has already passed the selected stop or trip is completed, stop departure alerts and mark the commute session completed/missed as appropriate.

### 9.7 Notification state machine

Each commuter's alert session for a service date must be idempotent. Store its current recommendation version and which action alerts have been sent.

States: `INACTIVE` -> `MONITORING` -> `ADVANCE_SENT` -> `LEAVE_NOW_SENT` -> `COMPLETED` or `CANCELLED`. `LIVE_STALE` and `SCHEDULE_FALLBACK` are data-quality states overlaying the session, not substitutes for its lifecycle.

- On activation, create one session for the configured bus/route/stop and service date.
- Send advance warning once when now reaches the configured lead time before current `recommendedLeaveBy`.
- Send Leave now once when now reaches `recommendedLeaveBy`, unless it is already past at activation, in which case send immediately.
- Recompute on accepted bus ETA and scooter-duration changes.
- Do not duplicate an event after retries. Use a deterministic idempotency key such as `(alertSessionId, recommendationVersion, eventType)`.
- Before Leave now, if the recommendation shifts materially, update the countdown and reconcile the pending scheduled action. If it shifts later, do not send a duplicate advance alert. If the user already received Leave now and a significant delay changes the plan, send one rate-limited update stating the bus delay and current recommendation.
- Once the bus passes the stop, the tracking session ends, the commuter cancels, or the service date expires, stop pending alerts.
- All scheduled sends are best effort; server event creation and push-request logging are testable, but physical delivery can be delayed or blocked by OS settings/network.

## 10. System architecture

### 10.1 Proposed stack

| Layer | Choice | Responsibility |
|---|---|---|
| Mobile | Flutter + Dart, two Android apps | Shared visual language, platform location permissions, tracker and commuter flows |
| Identity | Firebase Authentication with Google provider | User identity and session management |
| Static data/config | Cloud Firestore | Users' commuter settings, buses, routes, stops, schedules, operator assignments metadata, route-geometry versions, alert preferences |
| Live state | Firebase Realtime Database (RTDB) | Active trip state, latest location, freshness timestamp, session generation, live ETA/cache status |
| Backend logic | Cloud Functions for Firebase, TypeScript/Node.js | Authoritative trip starts/stops/handover, ETA/departure calculation, route API proxy, notification decisions |
| Scheduled checks | Cloud Scheduler plus scheduled Cloud Function | Tracker-start reminders, stale-session sweeps, expiration and recovery checks |
| Push | Firebase Cloud Messaging (FCM) | Operator reminders, advance warnings, Leave now alerts, material plan changes |
| Mapping/routing | Google Maps SDK + Google Routes API | Home pin, bus route display, route generation, scooter travel-duration estimates |
| Secrets | Google Cloud Secret Manager / server environment secrets | Route API key and backend credentials |

### 10.2 Data flow

1. Tracker requests a start through a trusted callable/HTTP function.
2. Backend checks Firebase identity, operator assignment, bus status, and whether another authoritative session exists. It creates a unique trip/session generation.
3. Tracker starts the foreground location service only after the operator action and publishes location updates to its allowed live path.
4. Backend/RTDB event handling validates freshness and session identity, projects location on the approved route, calculates bus ETA, and stores a server timestamp.
5. For an active commuter alert session, backend obtains/caches scooter duration and computes `recommendedLeaveBy`.
6. Backend reconciles the notification state machine and requests FCM sends only when a defined event becomes due.
7. Commuter subscribes to allowed live state for the chosen bus and displays status/countdown. It never calculates an authoritative departure using untrusted, client-injected bus coordinates.

### 10.3 Architectural guardrails

- No Google Routes API key in Flutter assets, source code, or app-config files.
- No production use of Firebase test-mode rules.
- Server timestamps determine staleness; do not rely solely on tracker-device clocks.
- Active trip ownership and session generation are controlled by the backend. A client cannot overwrite the `currentTrackerUid`, operator assignment, or trip state.
- Use RTDB for high-frequency moving location and Firestore for relatively static configuration/profile data to avoid writing every GPS ping into the main config collections.
- Use server-side transactions/atomic compare-and-set for start, stop and handover.
- Keep the first route/bus config small and easy to inspect. Avoid overengineering for a network-scale fleet until pilot metrics justify it.

## 11. Data model

Proposed logical model; concrete fields can be adjusted during implementation.

### 11.1 Firestore collections/documents

**`users/{uid}`**

- `displayName`, `email`, `photoUrl` (only as required)
- `roleFlags`: commuter/operator/admin granted server-side
- `createdAt`, `lastSeenAt`
- Avoid collecting extra profile data not needed for the MVP.

**`buses/{busId}`**

- `displayName` or fleet label, `routeIds`, `isActive`
- `operatorUids` or operator assignment references
- `trackerReminderTime`, `serviceDays`, `timeZone`
- `createdAt`, `updatedAt`

**`routes/{routeId}`**

- `name`, `direction`, `timeZone`, `isActive`
- `orderedStopIds[]`
- `geometryVersion`, `approvedGeometry`, `geometryUpdatedAt`, `geometryApprovedBy`
- `generatedFromProvider`, `routeQualityStatus`

**`stops/{stopId}`**

- `name`, `latitude`, `longitude`, `isActive`

**`routes/{routeId}/stopTimes/{stopId}`** (or an equivalent normalized collection)

- `sequenceIndex`, `scheduledArrivalLocalTime`, optional `dwellSeconds`, `distanceAlongRouteMeters`

**`users/{uid}/commutePreferences/{preferenceId}`**

- `homeLatitude`, `homeLongitude`
- `busId`, `routeId`, `boardingStopId`
- `advanceWarningMinutes` (default 10)
- `enabled`/saved preference state
- `createdAt`, `updatedAt`

**`operatorAssignments/{busId_uid}`** or equivalent

- `busId`, `operatorUid`, `status`, `assignedAt`, `assignedBy`

**`alertSessions/{alertSessionId}`**

- `commuterUid`, `preferenceId`, `serviceDate`, `busId`, `routeId`, `boardingStopId`
- `status`, `recommendationVersion`, `scheduledArrival`, `busEta`, `scooterDurationSeconds`, `safetyMarginSeconds`, `recommendedLeaveBy`
- `advanceNotificationStatus`, `leaveNowStatus`, `lastMaterialChangeAt`
- `createdAt`, `updatedAt`, `completedAt`

**`notificationEvents/{eventId}`**

- `idempotencyKey`, `alertSessionId`, `recipientUid`, `type`, `payloadSummary`
- `createdAt`, `sendAttemptAt`, `sendResult`, `retryCount`
- Never store unnecessary sensitive message details or service secrets.

### 11.2 Realtime Database live path

`/liveBuses/{busId}`

- `status`: `not_started | active | stale | ended`
- `activeTripId`, `sessionGeneration`, `trackerUid`
- `startedAtServer`, `lastLocationAtServer`, `lastHeartbeatAtServer`
- `latestLocation`: `{ lat, lng, accuracyM, speedMps?, headingDeg?, deviceTimestamp, serverTimestamp }`
- `routeProgress`: `{ progressMeters, remainingMeters, nearestRouteSegmentIndex, qualityStatus }`
- `busEta`: `{ arrivalAtStop, computedAtServer, confidenceLabel, sourceStatus, delayMinutes }`

Trip history can live under `/trips/{tripId}` with immutable lifecycle events, tracker handovers and audit summaries. Do not retain detailed location history longer than required for pilot debugging and ETA evaluation; set a retention period before real-user testing.

## 12. Security, privacy and permissions

- Require Firebase Authentication for both apps.
- Allow read access only according to product policy; for the prototype, signed-in users may read registered bus and active-trip status.
- Only designated operator UIDs assigned to a bus can start a trip or publish location for it.
- All assignments and high-privilege bus configuration are written by an administrator process or trusted server function, never arbitrary clients.
- A tracker can write only to the currently active trip session that the backend assigned to it. After stop/takeover, old session writes must fail.
- Validate coordinate ranges, timestamps, accuracy, payload shape, and rate limits at the boundary.
- Keep the Routes API credential server-side and restrict the key to required APIs and billing quotas. Use secret storage and rotation.
- Request location permission in context and only when the operator intends to start tracking. Explain that live location is shared with signed-in Fibus users while the trip is active.
- Commuter home coordinates are personal location data. Store them under the user, keep them unreadable by other commuters, and do not expose them to tracker operators.
- Provide a way to delete/change saved home coordinates and commute preferences. Document data retention and deletion for trip histories.
- Do not log raw home coordinates, authentication tokens, API secrets or sensitive profile information in routine analytics.
- Android 13+ requires notification runtime permission for standard notifications; check permission and show an in-app status when disabled. [6]
- Track location only during an active trip session. Show the Android foreground-service notification and stop collecting promptly when the trip ends.
- Firebase Realtime Database rules must enforce read/write access at the server and default deny until rules are deliberately configured and tested. [5]

## 13. UX and screen inventory

### Commuter app

1. **Welcome / Google sign-in**
2. **Home pin setup**: map pin placement, confirm and save
3. **Choose commute**: bus/route list, ordered stop list, save preferred commute
4. **Today dashboard**: selected bus and stop, live/schedule status label, bus ETA, scooter duration, recommended leave time, countdown, Activate alerts for today / Cancel alerts
5. **Notification settings**: advance warning lead time, alert permissions status
6. **Stale/no tracker state**: plain explanation, last update time if available, scheduled arrival fallback, operator reminder status where useful
7. **Trip completed / missed state**: stop active alerts and show a neutral result state

### Tracker app

1. **Google sign-in**
2. **Assigned buses**
3. **Trip preview**: bus, route, expected stop timetable, reminder context
4. **Active tracking**: clear “Tracking live” status, persistent notification, last GPS update, permission/network warning, End trip
5. **Takeover flow**: identify stale existing feed, confirm Take over, show the new authoritative trip session
6. **Error states**: permission denied, GPS off, data connection absent, bus already tracked, operator no longer assigned

### Admin/configuration utility

- Create/edit bus, route, stops, stop times, time zone and tracker reminder time.
- Generate candidate route geometry, preview it, correct a path that does not follow the actual bus road, and explicitly approve a geometry version.
- Assign/unassign operator UIDs.
- Inspect current session, last GPS update, stale-state status, and notification/send errors.

## 14. Edge cases and expected behaviour

| Scenario | Expected behaviour |
|---|---|
| Operator does not start tracking | Commuter sees “Tracking has not started”; use scheduled arrival as labelled fallback; send operator reminder. |
| Operator denies location permission | Do not start the trip; explain steps to enable permission. Do not show live status. |
| GPS switched off or permission revoked mid-trip | Tracker shows failure and attempts no unauthorized background workaround; backend marks the feed stale after 60 seconds. |
| Network outage on tracker phone | Location uploads pause; timestamps reveal stale data. When connectivity returns, reject old/out-of-order fixes and do not let them overwrite newer data. |
| Location is noisy or jumps off-route | Flag poor quality; ignore impossible speed/progress jumps; show low-confidence or unavailable ETA as appropriate. |
| Bus makes an unconfigured detour | Do not pretend route-distance ETA is accurate. Flag route mismatch and fall back to schedule/low-confidence state until reconciled. |
| Two operators start same bus | Backend grants only one authoritative session. Other operator sees “Already being tracked” unless takeover is eligible. |
| Previous operator reconnects after takeover | Reject writes from the superseded session generation. |
| Commuter uses wrong stop or route | Selected stop must belong to selected route; confirmation screen displays bus/route/stop identity. |
| Current time is already after leave-by time | Send Leave now immediately and show that the recommendation has passed. |
| Bus ETA changes after advance alert | Recompute recommendation; update countdown; avoid repeated advance alerts. Send material plan update only under rate-limit rules. |
| Delay occurs after Leave now alert | Show updated delay/recommendation and, if material, send one rate-limited update. Never imply the original alert can be retracted. |
| FCM token missing or push permission disabled | Mark notification channel unavailable; show in-app warning and offer OS settings instructions. Delivery cannot be guaranteed. |
| Route API times out or exceeds quota | Use a cached/last valid duration if recent and label it; otherwise use a static/backup estimate with larger safety margin and clear reduced-confidence status. |
| Schedule crosses midnight or time-zone changes | Use route's local time zone and service date; test DST/time-zone behaviour if deployed outside India. |
| Operator reminder job is late or fails | Retry with bounded policy; log failure. The UI must not claim tracking started merely because a reminder was sent. |
| User cancels today's alert session | Stop future commuter alerts for that session; do not stop bus tracking used by other commuters. |
| Bus reaches/passes the selected stop | Close or complete the session; stop sending departure recommendations for that stop. |

## 15. Non-functional requirements

### Reliability and freshness

- Active moving tracker attempts to publish a location approximately every 5-10 seconds, subject to OS, GPS and network conditions.
- A location feed with no fresh accepted fix for 60 seconds is stale.
- Commuter UI must display last-update age and avoid showing stale points as live.
- Active trip start/stop/takeover transitions must be atomic and idempotent.
- Backend functions should retry safe operations and record outcomes, while notification events use idempotency keys to prevent duplicates.

### Performance

- Target live ETA recalculation within 10 seconds after an accepted GPS update reaches the backend, excluding provider/network delays.
- Target commuter dashboard loads within 3 seconds on ordinary mobile connectivity once signed in and data is cached.
- Route geometry should load from approved stored data rather than recalculating on every app open.
- Avoid routing API calls for inactive commuters and avoid one scooter route call for every bus GPS ping.

### Battery and network

- Only use continuous high-accuracy location while Tracker is in an explicitly active trip.
- Reduce GPS update frequency when stationary if testing confirms stale detection remains sound; never compromise takeover detection.
- Display GPS/network errors clearly. Do not silently keep presenting an old point as current.

### Accessibility and usability

- Primary action labels must be unambiguous: Activate alerts for today, Start tracking, End trip, and Leave now.
- Use both text and visual state for live/stale/schedule fallback; do not rely on colour alone.
- Notification copy should state the action and current estimate, for example: “Leave in about 10 minutes” or “Leave now to aim for the 7:45 AM stop arrival.”
- Support 12-hour local display while storing times in a normalized format.

### Observability

- Track counts of valid GPS updates, stale transitions, takeovers, ETA confidence states, API usage/errors, alert decisions, send failures and commute completions.
- Avoid collecting more personal location data than necessary. Use aggregated metrics for product evaluation.

## 16. Analytics and success metrics

### North-star outcome

**A commuter who follows Fibus's recommendation reaches the stop shortly before the bus while spending less time waiting and rarely missing it.**

### Pilot metrics

1. **Bus ETA error:** compare each stored prediction with actual bus arrival at the selected stop. Initial target: median absolute error of 5 minutes or less for predictions made 10-20 minutes before arrival, after at least 20 valid pilot trips. If this is not met, show lower confidence and improve route matching before expanding.
2. **Departure safety:** in journeys where the commuter confirms they followed the recommendation, target at least 90% arrival at the stop before the observed bus arrival. Track the margin and report misses separately.
3. **Waiting time:** measure arrival-at-stop time minus actual bus arrival time; compare against the commuter's self-reported manual baseline during pilot. Do not claim improvement without a baseline.
4. **Missed-bus rate:** record confirmed cases where commuter arrives after the bus. Compare with baseline over the pilot; a small sample is directional, not statistically conclusive.
5. **Tracker reliability:** percentage of scheduled pilot trips with an operator-started live feed; percentage of tracked minutes with fresh GPS; number of takeovers and mean recovery time.
6. **Notification quality:** duplicate alert count, backend send success/failure, permission-disabled sessions, and user-reported too-early/too-late alerts.
7. **Engagement:** daily alert activation rate and percentage of sessions followed through to a completion state.

Metrics are hypotheses for the pilot, not promises of product performance.

## 17. MVP acceptance criteria

The MVP is ready for a controlled pilot only when all P0 criteria below pass.

### Authentication and access

- Both apps support Google sign-in/sign-out and recover gracefully from auth errors.
- Signed-out users cannot access protected bus/trip data.
- A signed-in but unassigned user cannot start or publish a bus trip.
- Commuter A cannot read Commuter B's saved home coordinates or commute preferences.
- Firebase rules and server-side authorization tests pass against the production-like project configuration.

### Tracker lifecycle

- Assigned operator receives a reminder at the configured reminder time within the tested scheduler's operational tolerance; delivery is labelled best-effort.
- Operator must open Tracker and tap Start tracking before GPS collection begins.
- Active tracking shows a persistent notification and stops on End trip.
- A fresh valid GPS point appears to signed-in commuters with an update timestamp.
- After 60 seconds with no fresh valid point, the state becomes stale and the UI does not label the old point live.
- Eligible replacement can take over; old session's writes are rejected after takeover.
- Unauthorized start, simultaneous start, and old-session replay tests are denied.

### ETA and departure logic

- With a route and an adequate sequence of valid GPS points, backend ETA is derived from route progress rather than straight-line distance.
- When live data is absent/stale/low confidence, the app labels the timetable fallback and never labels it live.
- Scooter duration is retrieved through a backend function; client builds contain no Routes API secret.
- Formula matches: `recommendedLeaveBy = busEta - 5 min - scooterDuration - safetyMargin`.
- A live ETA at least five minutes later than schedule sets Significant delay and recomputes leave-by time.
- When leave-by time is in the past, Leave now triggers promptly and the UI explains it is already late.

### Notifications

- Advance warning lead can be changed in settings and persists across sessions.
- Advance and Leave now notifications use distinct IDs/events and do not duplicate under backend retries or bursts of GPS updates.
- A changed ETA updates the countdown and reconciles pending alerts.
- Notification-disabled state is visible and doesn't falsely claim a push is enabled.
- Tracking-not-started flow shows schedule fallback and attempts a bounded reminder to the assigned operator.

### Route and configuration

- Admin can create the pilot bus, route, ordered stops, timetable and tracker assignment.
- Generated route geometry can be previewed, corrected and approved.
- The tested route geometry matches the physical bus route closely enough for ETA evaluation; known mismatches are documented.
- Tracker reminder time and scheduled arrival time are separately configurable.

### Pilot test plan

Run at least 20 observed trips if feasible, covering on-time, late, stopped-in-traffic, no-start, GPS loss, weak network, takeover, and route-mismatch scenarios. Record actual bus arrival and compare each ETA forecast. Do not expand to multiple buses until the single-route telemetry and alert quality are understood.

## 18. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| No volunteer starts tracking | Live ETA unavailable, user trust drops | Scheduled start reminder, clear no-tracker status, schedule fallback, operator adherence metric |
| Phone OS kills/restricts tracking | Missing/stale GPS | Explicit user-started location foreground service, persistent notification, device testing, clear stale detection; do not promise auto-start while app is closed. Android restricts background FGS starts. [1] |
| GPS noise or route mismatch | Incorrect bus ETA | Ordered approved route geometry, map projection, accuracy/speed filters, off-route status, route-correction tool |
| Route provider chooses the wrong road | ETA follows a road bus doesn't use | Admin previews and corrects route; test against observed GPS before pilot |
| Scooter ETA uncertainty | Commuter leaves too late/early | Traffic-aware estimates, dynamic safety margin, confidence labels, fallback, pilot calibration |
| Google API costs/limits | Unexpected operating expense or throttling | Server-side calls, cache, request budgets, quotas/alerts, only refresh during active alert sessions; two-wheeler mode carries higher rates. [2] |
| Push notification delay/permission disabled | Missed action reminder | Check notification permission, log send result, provide in-app countdown/status; communicate best-effort delivery. FCM behavior depends on app state and delivery constraints. [7] |
| Alert spam from ETA changes | User disables notifications | Server-side state machine, idempotency keys, material-change threshold, bounded retries |
| Unauthorized location injection | Fake bus movement or privacy breach | Designated operator assignment, backend-owned session, strict database rules, session generations, validation and audit logs |
| Privacy concerns | Loss of user trust | Collect only needed data, restrict home coordinates to owner, visible active tracking, data retention/delete policy |
| Timetable inaccurate/out of date | Fallback misleads user | Admin maintenance, last-updated label, no-start warnings; schedule fallback remains an estimate |
| Device battery/network differences | Uneven tracker reliability | Test on actual devices/operators, expose update time, document supported Android baseline and battery optimisation guidance |

## 19. Phased implementation plan

### Phase 0: Validate route and architecture (1-3 development days as a planning estimate)

- Confirm pilot bus, route, ordered stops, schedule, time zone and actual tracker-start reminder time.
- Verify Google Maps Platform account, billing, Routes API two-wheeler availability and cost in the pilot area.
- Create and review route geometry; compare the generated path with the real route.
- Configure Firebase projects, package IDs, Google sign-in, server secrets, environment separation and restrictive database rules.
- Define a controlled test device and baseline commute measurement.

**Exit gate:** a reviewed route and working authenticated Firebase environment exist; no public/test-mode database permissions.

### Phase 1: Reliable tracker lifecycle

- Build Tracker sign-in, assigned bus list, Start tracking, persistent location foreground service, timestamped GPS publishing, End trip and visible health state.
- Implement backend-owned start/stop state and single authoritative session per bus.
- Add 60-second stale detection and session-generation protection.
- Implement operator start reminder and basic handover path.

**Exit gate:** location updates stay fresh on supported test devices; stale state and takeover tests pass.

### Phase 2: Commuter setup and timetable fallback

- Build Google sign-in, home pin, route/stop selection, saved commute and Activate alerts for today.
- Display registered bus, route, stop, scheduled arrival, and tracking status.
- Add clear no-tracker/stale warning and schedule fallback.
- Add notification permission onboarding and in-app notification status.

**Exit gate:** commute setup persists correctly, and no-live-tracker cases are honest and understandable.

### Phase 3: ETA and route correction

- Generate candidate route geometry from ordered stops and build a preview/correction workflow.
- Implement GPS filtering, route projection, progress, remaining route distance, speed smoothing and ETA confidence state.
- Compare predictions with actual bus arrival during supervised runs.
- Tune smoothing/filter defaults until ETA is stable enough for a limited pilot.

**Exit gate:** measured ETA performance is documented and known route mismatch is visible.

### Phase 4: Smart departure and notifications

- Integrate secured Routes API function for scooter journey duration, cache and quotas.
- Implement dynamic safety-margin calculation and leave-by time.
- Add configurable advance warning, Leave now, significant-delay state, updated-plan rate limit and idempotent notifications.
- Add reminder/alert event logs and failure states.

**Exit gate:** formula-level tests and real device notification tests pass; duplicate-alert tests pass.

### Phase 5: Controlled pilot and refine

- Run 20+ observed trips if feasible, including failure scenarios.
- Record ETA error, departure safety, waiting time, missed buses, tracker adherence and notification quality.
- Gather commuter feedback after each pilot week and adjust route geometry, safety-margin parameters, warning lead and update thresholds.
- Only then decide whether to add more buses/routes or return-trip support.

**Exit gate:** pilot results support expansion; known limitations and measured error are disclosed.

## 20. Open implementation details (not discovery blockers)

These can be selected by the engineering team without another product-discovery round:

- Exact Flutter plugins and Android target SDK after checking their maintenance status and current Android requirements.
- Firestore vs RTDB document paths and concrete query/index layout.
- Initial GPS sampling interval, quality threshold and ETA smoothing parameters.
- Cloud Scheduler cadence and retry policy, respecting cost and acceptable reminder latency.
- Default advance-warning value (proposed: 10 minutes) and default safety-margin settings (proposed: 2-minute base plus up to 5-minute uncertainty premium).
- Whether route correction is performed in a minimal internal map tool or an admin seed-script workflow for the one-route pilot.
- How long to retain detailed GPS history; must be decided before real users begin testing.

\newpage

## 21. References

These official technical references were checked on 26 October 2026. Details can change; recheck during implementation.

1. Android Developers, **Restrictions on starting a foreground service from the background**. https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
2. Google Maps Platform, **Get a two-wheeled vehicle route** (TWO_WHEELER mode, beta warning and billing note). https://developers.google.com/maps/documentation/routes/route_two_wheel
3. Google Maps Platform, **Set the level of traffic data** (TRAFFIC_AWARE / TRAFFIC_AWARE_OPTIMAL, latency and cost trade-offs). https://developers.google.com/maps/documentation/routes/config_trade_offs-rm
4. Google Maps Platform, **Countries and regions supported for two-wheeled vehicles** (India listed as supported). https://developers.google.com/maps/documentation/routes/coverage-two-wheeled
5. Firebase, **Understand Realtime Database Security Rules**. https://firebase.google.com/docs/database/security
6. Android Developers, **Notification runtime permission**. https://developer.android.com/develop/ui/compose/notifications/notification-permission
7. Firebase, **Receive messages in Android apps**. https://firebase.google.com/docs/cloud-messaging/android/receive-messages
8. Firebase, **Authenticate with Google on Android**. https://firebase.google.com/docs/auth/android/google-signin

---

**Final product definition:** Fibus is a two-app Android MVP that uses a designated passenger-operated GPS feed and a route-aware ETA to recommend when a commuter should leave home for a chosen bus stop. It dynamically adjusts for bus delays and scooter travel uncertainty, sends two-stage notifications, and falls back transparently to the timetable whenever live data is unavailable.
