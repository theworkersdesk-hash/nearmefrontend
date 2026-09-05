# hloppl — Project Handoff

> Summary of what **hloppl** (formerly "Vibe") is, how it's built, what's been done across all
> working sessions, and where things stand. Companion to [`MAC_SETUP.md`](MAC_SETUP.md) (the
> how‑to‑run guide). Read this to get oriented; read `MAC_SETUP.md` to actually stand it up.
>
> _Last updated: 2026‑09‑05._

---

## 1. What it is

**hloppl** is an **India‑first, location‑based social app** — "find your tribe." Users discover
people nearby (fixed **5 km** radius), connect (double opt‑in), chat in real time, and browse /
create local **events** ("Explore vibes"). It is **not** the "Undiscovered" startup platform
described in the auto‑loaded parent `/home/akshat/Downloads/CLAUDE.md` — **ignore that file for
this repo.** The canonical spec for hloppl lives in the `files (1)/` folder
(`claude.md`, `HLD.md`, `LLD.md`, `techstack.md`, `plan.md`) and in `design.pdf` (10‑page mobile
mockup) at the repo root.

### Brand
Renamed **Vibe → hloppl** on 2026‑08‑23. Visible strings + Dart code symbols changed. Deliberately
**unchanged**: pubspec package `name: vibe` (imports are relative), the Android package id
**`com.nearme.vibe`**, and Firebase `google-services.json` — changing those breaks Firebase /
sign‑in. English‑word uses ("Explore vibes ✨", "good vibes") kept intentionally.

---

## 2. Architecture

| Layer | Tech | Location | Repo |
|---|---|---|---|
| Mobile/web app | **Flutter + Riverpod**, Dio, Hive (offline cache), Firebase, Socket.IO client, geolocator | `frontend/` | `theworkersdesk-hash/nearmefrontend` |
| API | **Node + Express + TypeScript**, Socket.IO, zod, JWT, pg, ioredis | `backend/` | `theworkersdesk-hash/nearmeBackendApp` |
| Admin panel | **Next.js 16 + React 19**, direct‑to‑Postgres, JWT (jose), Tailwind | `admin/` | **local only — no remote** |
| Database | **PostgreSQL 16 + PostGIS 3.4** (geo `ST_DWithin`) | `database/migrations/` | (in backend/root) |
| Cache | **Redis 7** (server cache‑aside) + **Hive** (on‑device) | — | — |
| Auth/push | **Firebase** (Google Sign‑In, FCM, Storage), Twilio SMS OTP, SMTP email OTP | — | — |
| Maps | **Google Maps** via backend proxy (key server‑side only) | `backend/src/services/maps.service.ts` | — |
| Media | **Cloudflare R2** (support attachments), Firebase Storage (photos) | — | — |

**Docker host ports** (remapped to avoid clashes with other local stacks):
Postgres **5434**→5432, Redis **6382**→6379, Backend **3010**→3000 (docker), Admin **3020**,
Flutter web **8080**, Mailhog **1025/8025**.

**Key schema/infra notes:**
- Migrations auto‑run via `docker-entrypoint-initdb.d` on **first** DB boot (empty volume only;
  `docker compose down -v` to re‑run). 15 migrations: `000_extensions` … `014_event_quota`.
- `users.generation_category` is set by the **`trg_users_generation` trigger**, not a stored
  generated column (the LLD's generated‑column version fails — `CURRENT_DATE` is non‑immutable).
- Redis cache‑aside in `backend/src/config/redis.ts` (event feed/detail; invalidated on writes;
  degrades to DB‑only if down). Hive is the Flutter client cache
  (`frontend/lib/services/local_cache_service.dart`).
- Frontend API base URL is a **`--dart-define=API_BASE_URL`** (never hardcoded). Default =
  production `https://nearme.theworkersdesk.tech`.

---

## 3. Build history (chronological)

### Phase 0–7 — core build (week of 2026‑07‑20)
Full app built end‑to‑end: **auth** (email/phone OTP), **discovery** (PostGIS `ST_DWithin`),
**connections** (double opt‑in), **real‑time chat** (Socket.IO REST + sockets), **events**,
**notifications** (FCM), **photo upload** (multer → Firebase Storage), **block/unblock**,
**offline cache** (Hive client‑side + Redis server‑side). Backend hardened with auth /
rate‑limit / pagination migrations. `tsc --noEmit` clean; 11 unit tests pass. Verified
end‑to‑end via Docker. Frontend restyled to match `design.pdf` (purple aesthetic, gradient pill
buttons, lavender fields, per‑tab headers — no shared AppBar).

### Production infra (week of 2026‑07‑20/27)
Prod at **`nearme.theworkersdesk.tech`** — `docker-compose.prod`, nginx + Cloudflare SSL, PM2.
4 git repos initialized + Docker stack (postgres/redis/backend on a shared network).

### APK + Google OAuth (week of 2026‑07‑27)
Release APK builds (**split‑per‑ABI**, Firebase wired, package id `com.nearme.vibe`). Fixed
Google OAuth (error handling, service account, `.env` config).

### Help & Support feature (week of 2026‑07‑27)
User‑side support tickets — backend + Flutter UI, **R2** image attachments, migrations
**011–012**. (R2 env values were still pending on the server at the time.)

### Admin panel (weeks of 2026‑07‑27 → 08‑03)
Standalone **Next.js 16** app (`admin/`), talks **directly to Postgres**. JWT auth (env
super‑admin + bcrypt admins), audit logging, migration **013**. Runs on **:3020**. Then 5 more
features: **dashboard analytics, moderation, user enrichment, password‑change, CSV export**.
16 tests pass; Playwright E2E on seeded data (commit `d900052`).

### 5 km radius + event quota (2026‑08‑22)
- **People‑find radius fixed at 5 km, server‑enforced** (`DISCOVER_RADIUS_METERS = 5000`);
  client `radius` ignored. Flutter dropped the radius slider.
- **Location refresh on app open** (`home_shell.dart` `WidgetsBindingObserver` →
  `location.sync()` + `discover.refresh()` on resume).
- **Event creation quota: 3 free/month, then premium.** Migration **`014_event_quota.sql`**
  adds `users.is_premium` + `premium_until`. Usage **derived** by counting this month's `events`
  rows (create‑then‑delete can't game it). `createEvent()` throws **`QuotaExceededError`** (402,
  `EVENT_QUOTA_EXCEEDED`). Endpoints `GET /events/quota`, `POST /events/subscribe`.
  ⚠️ **Security:** `/subscribe` grants premium with **no payment check** — gated behind env flag
  **`ALLOW_MOCK_PREMIUM`** (default `false`). **Replace with a verified payment webhook before
  production.**
- **Create Event moved to the Profile tab** (removed the events FAB; added a quota card +
  Create/Upgrade button in `profile_screen.dart`).

### Explore vibes redesign (2026‑08‑23)
Events tab rebuilt to match **design.pdf page 7**. Dropped the All/Online/Offline segmented
tabs. Three sections: **Offline Experiences** (horizontal carousel of real offline events with
client‑side distance badges), **Play Arena** (real online events as game tiles, "N playing"),
**Groups Near You** (**static demo** cards, "coming soon" — no groups backend). Search collapses
sections to a flat filtered list. New: `widgets/events/explore_widgets.dart`,
`screens/events/event_list_screen.dart`, `userPositionProvider`.

### hloppl rebrand (2026‑08‑23)
Vibe → hloppl across visible strings **and** code symbols (`HlopplApp`, `HlopplButton`,
`HlopplTextField`, `hloppl_*` files, `hloppl_cache`/`hloppl_prefs` Hive boxes). `flutter analyze`
clean. (Package id / Firebase config intentionally untouched.)

### Google Maps integration (2026‑08‑23)
Maps for **event location** + **person location**, key kept **backend‑only** (never shipped).
- **Backend proxy** `/api/maps/*` (all authed): `geocode`, `reverse-geocode`,
  `places/autocomplete`, `places/details`, `static` (proxies the PNG). Uses Node 20 global
  `fetch` (no new dep). `GOOGLE_MAPS_API_KEY` optional — unset ⇒ **503 `MAPS_UNCONFIGURED`** and
  the app degrades (manual address entry still works). Files: `services/maps.service.ts`,
  `controllers/maps.controller.ts`, `validation/maps.schema.ts`, `routes/maps.routes.ts`;
  new `ServiceUnavailableError`.
- **Frontend**: `maps_service.dart` (`GeoPoint`/`PlaceSuggestion`), `ApiService.getBytes()`,
  and widgets `StaticMapView`, `LocationPicker`, `CurrentLocationMap`. Wired into **create‑event**
  (LocationPicker replaces manual lat/lng), **event‑detail** (map + tap‑for‑directions), and the
  **discover filter sheet** (current‑location map = the 5 km people‑find centre).
- **Tests:** backend **27/27** (14 new — parsers, schema, fetch‑stubbed wrappers);
  frontend `maps_service_test.dart` **6/6**. `tsc` + `flutter analyze` clean. Verified over HTTP:
  401 → 400 → 503 (unconfigured) → real Google call with a dummy key.

### This session (2026‑09‑05)
- **Pushed the frontend** to the new repo **`git@github.com:theworkersdesk-hash/nearmefrontend.git`**
  (committed the hloppl rebrand + Explore redesign + Google Maps work — 40 files — then pushed
  `main`). The push used the `github-work` SSH alias (authenticates as the org owner).
- Wrote **`MAC_SETUP.md`** and this **`HANDOFF.md`**.

---

## 4. Current status

| Component | State |
|---|---|
| Backend | Feature‑complete for current scope; `tsc` clean; 27 tests pass (incl. maps). |
| Frontend | `flutter analyze` clean; 6 maps tests pass; pushed to `nearmefrontend`. |
| Admin | Feature‑complete; E2E tested; **not pushed to any GitHub remote.** |
| Database | 15 migrations (000–014), auto‑run on fresh volume. |
| Maps | Wired end‑to‑end; needs a real `GOOGLE_MAPS_API_KEY` to go live. |
| Production | Live at `nearme.theworkersdesk.tech`. |

### Repos (org `theworkersdesk-hash`)
- **frontend** → `git@github.com:theworkersdesk-hash/nearmefrontend.git` ✅ (current)
- **backend** → `git@github.com:theworkersdesk-hash/nearmeBackendApp.git`
- **admin** → ⚠️ **no remote** — must be pushed or copied to the Mac (see `MAC_SETUP.md` §1.1)
- legacy: `nearme-frontend` (hyphen) — old frontend repo, superseded

---

## 5. Open items / things to do next

1. **Push the admin panel** to a GitHub repo (currently local‑only) so it reaches the Mac —
   otherwise copy the folder. See `MAC_SETUP.md` §1.1.
2. **Provide a real `GOOGLE_MAPS_API_KEY`** in `backend/.env` and enable Geocoding + Places +
   Maps Static APIs in Google Cloud to activate live maps.
3. **Replace the mock premium endpoint** (`POST /events/subscribe`, `ALLOW_MOCK_PREMIUM`) with a
   real payment webhook (signature + paid‑intent verification) before production.
4. Confirm **R2 env values** on the server for support attachments (were pending).
5. On the Mac: recreate all gitignored secrets/config (see `MAC_SETUP.md` §4) and run the
   full‑stack bring‑up checklist (§9).

---

## 6. Gotchas cheat‑sheet

- **Ports:** Postgres **5434**, Redis **6382**, backend docker **3010** / native **3000**, admin **3020**.
- **DB creds (local docker):** user `vibe`, db `vibe_db`, password `vibe_password`.
- **Android emulator** must use `10.0.2.2`, not `localhost`, for `API_BASE_URL`.
- **ts-node** needs `TS_NODE_TRANSPILE_ONLY=1` (already in the `npm test` script) for the
  `req.user` augmentation.
- **Migrations** only auto‑run on an empty volume — `docker compose down -v` resets (wipes data).
- **Ignore** `/home/akshat/Downloads/CLAUDE.md` (that's the unrelated "Undiscovered" project).
