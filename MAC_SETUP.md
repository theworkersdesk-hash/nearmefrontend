# hloppl — End‑to‑End Mac Development Setup

> Step‑by‑step guide to stand up the **entire hloppl stack** (formerly "Vibe") on a fresh
> macOS machine. Written so a human **or Claude Code** can follow it top‑to‑bottom.
>
> Stack: **Flutter** app + **Node/Express/TypeScript** backend + **Next.js** admin panel,
> backed by **PostgreSQL 16 + PostGIS**, **Redis**, **Firebase**, and a **Google Maps** proxy.

---

## 0. TL;DR (for the impatient / for Claude)

```bash
# 1. Prereqs (Homebrew, then everything else)
brew install --cask docker android-studio
brew install node@20 postgresql@16 redis git
# Flutter + Xcode + CocoaPods — see §2

# 2. Clone the repos into one workspace folder
mkdir -p ~/dev/hloppl && cd ~/dev/hloppl
git clone git@github.com:theworkersdesk-hash/nearmefrontend.git   frontend
git clone git@github.com:theworkersdesk-hash/nearmeBackendApp.git backend
# admin: NO git remote yet — see §1.1 (copy folder or create a repo)

# 3. Secrets — copy the workspace docker-compose.yml + create .env files (§4)
#    backend/.env, admin/.env, backend/firebase-service-account.json,
#    frontend android/app/google-services.json, frontend lib/firebase_options.dart

# 4. Bring up infra + services
docker compose up -d db redis          # Postgres(5434) + Redis(6382); migrations auto-run
cd backend && npm install && npm run dev        # backend on :3000
cd ../admin && npm install && npm run dev        # admin on :3020
cd ../frontend && flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000   # or 10.0.2.2 for Android emu
```

If anything below is unclear, the authoritative source of truth is
[`HANDOFF.md`](HANDOFF.md) (project history + decisions) and the root `docker-compose.yml`.

---

## 1. Repository & Folder Map

Everything lives under **one workspace folder** (e.g. `~/dev/hloppl/`). The root holds the
shared `docker-compose.yml` that orchestrates all services.

```
hloppl/                         ← workspace root (NOT a git repo itself)
├── docker-compose.yml          ← orchestrates db, redis, backend, admin (+ web/mail profiles)
├── MAC_SETUP.md                ← this file
├── HANDOFF.md                  ← project history + decisions
├── frontend/    → git repo → git@github.com:theworkersdesk-hash/nearmefrontend.git   (Flutter)
├── backend/     → git repo → git@github.com:theworkersdesk-hash/nearmeBackendApp.git (Node/Express/TS)
├── admin/       → git repo (LOCAL ONLY — no remote yet, see §1.1)                    (Next.js 16)
├── database/
│   └── migrations/   ← 000–014 *.sql, auto-run on first Postgres boot
├── postgres/         ← copy of migrations (kept in sync)
├── redis/            ← redis config assets
└── deploy/           ← production deploy notes/assets
```

### 1.1 ⚠️ The admin panel has no Git remote

`admin/` is a git repo locally but was never pushed to GitHub. To get it onto the Mac you have **two options**:

- **Option A — create a repo and push** (recommended, from the *current Linux* machine):
  ```bash
  cd admin
  git remote add origin git@github.com:theworkersdesk-hash/nearme-admin.git   # create the empty repo on GitHub first
  git push -u origin main
  ```
  Then on the Mac: `git clone git@github.com:theworkersdesk-hash/nearme-admin.git admin`
- **Option B — copy the folder** directly to the Mac (AirDrop / scp / USB). Exclude
  `node_modules/`, `.next/`, and `.env`.

> There is also a legacy frontend repo `nearme-frontend` (with a hyphen). The **current**
> frontend is `nearmefrontend` (no hyphen) — use that one.

---

## 2. Install Prerequisites (macOS)

### 2.1 Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Apple Silicon: add brew to PATH as the installer instructs (eval "$(/opt/homebrew/bin/brew shellenv)")
```

### 2.2 Git + SSH key for GitHub

```bash
brew install git
ssh-keygen -t ed25519 -C "you@theworkersdesk"          # if you don't have a key
pbcopy < ~/.ssh/id_ed25519.pub                          # paste into GitHub → Settings → SSH keys
ssh -T git@github.com                                    # expect: "Hi <user>! ..."
```
The org repos are under **`theworkersdesk-hash`** — the SSH key you register must have push
access to that org.

### 2.3 Node.js 20 LTS (backend + admin)

Backend requires **Node ≥ 20**; Next.js 16 (admin) requires **Node ≥ 20.9**. Use nvm so you can
pin per‑project.

```bash
brew install nvm
mkdir -p ~/.nvm
# add to ~/.zshrc:  export NVM_DIR="$HOME/.nvm"; source $(brew --prefix nvm)/nvm.sh
nvm install 20
nvm alias default 20
node -v      # v20.x
```

### 2.4 Docker Desktop (Postgres + Redis + optional services)

```bash
brew install --cask docker
open -a Docker          # launch once to finish setup; wait until the whale icon is steady
docker compose version  # confirm Compose v2
```

### 2.5 Flutter 3.41.x + Dart 3.11.x

The project pins `sdk: ">=3.5.0 <4.0.0"` and `flutter: ">=3.24.0"`. The reference dev machine
uses **Flutter 3.41.5 / Dart 3.11.3 (stable)**. Match that.

```bash
# Recommended: install via the official tarball or FVM so you can pin 3.41.5.
brew install --cask flutter          # quick path (may be a slightly newer stable)
# OR pin exactly with FVM:
#   dart pub global activate fvm && fvm install 3.41.5 && fvm use 3.41.5
flutter --version                    # expect 3.41.x / Dart 3.11.x
```

### 2.6 iOS toolchain (only if building for iOS/macOS)

```bash
xcode-select --install                 # command line tools
# Install full Xcode from the App Store, then:
sudo xcodebuild -license accept
sudo gem install cocoapods             # or: brew install cocoapods
```

### 2.7 Android toolchain (for Android builds/emulator)

```bash
brew install --cask android-studio
# Launch Android Studio → SDK Manager: install Android SDK + a system image, create an AVD.
flutter doctor --android-licenses      # accept all
flutter doctor                          # everything should be green (Xcode + Android)
```

---

## 3. Clone the Repos

```bash
mkdir -p ~/dev/hloppl && cd ~/dev/hloppl
git clone git@github.com:theworkersdesk-hash/nearmefrontend.git   frontend
git clone git@github.com:theworkersdesk-hash/nearmeBackendApp.git backend
# admin: see §1.1
```

You also need the workspace **`docker-compose.yml`** (and the `database/`, `postgres/`, `redis/`
helper folders) at the workspace root. These are not inside any single repo — copy them from the
Linux machine, or recreate `docker-compose.yml` from the reference in §5.

---

## 4. Secrets & Config Files (the gitignored bits)

**None of these are in Git.** They must be created on the Mac. Get real values from your
password manager / Firebase console / Google Cloud console.

| File | Repo | Purpose | How to create |
|---|---|---|---|
| `backend/.env` | backend | server config, DB/Redis URLs, JWT, Firebase, Twilio, SMTP, R2, **GOOGLE_MAPS_API_KEY** | `cp backend/.env.example backend/.env` then fill in |
| `backend/firebase-service-account.json` | backend | Firebase Admin SDK (FCM, auth verify) | Firebase Console → Project settings → Service accounts → Generate key |
| `admin/.env` | admin | DB URL, `AUTH_SECRET`, super‑admin creds | `cp admin/.env.example admin/.env` then fill in |
| `frontend/android/app/google-services.json` | frontend | Firebase Android config | Firebase Console → Android app → download |
| `frontend/ios/Runner/GoogleService-Info.plist` | frontend | Firebase iOS config | Firebase Console → iOS app → download |
| `frontend/lib/firebase_options.dart` | frontend | FlutterFire config | `dart pub global activate flutterfire_cli` → `flutterfire configure` |

### 4.1 backend/.env — the important knobs

```dotenv
PORT=3000
NODE_ENV=development
CORS_ORIGIN=*

# Google Maps — SERVER-SIDE ONLY, never shipped to the app.
# Enable in Google Cloud: Geocoding API, Places API, Maps Static API.
# Leave empty to disable maps (endpoints return 503, app still works via manual address).
GOOGLE_MAPS_API_KEY=

# DB / Redis — for NATIVE (host) dev these point at the Docker-published ports.
# NOTE the ports: docker publishes Postgres on 5434 and Redis on 6382 (see §5).
DATABASE_URL=postgresql://vibe:vibe_password@localhost:5434/vibe_db
REDIS_URL=redis://localhost:6382

JWT_SECRET=change-me-access-secret
JWT_REFRESH_SECRET=change-me-refresh-secret

FIREBASE_PROJECT_ID=vibe-app
FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
FIREBASE_STORAGE_BUCKET=

# Twilio (SMS OTP), SMTP (email OTP), R2 (support attachments) — fill if used.
# Leave SMTP_HOST empty → OTP codes are just logged (works out of the box for dev).
ALLOW_MOCK_PREMIUM=false      # keep false except when testing the paywall locally
```

> **Port gotcha:** the reference `.env.example` shows `localhost:5432`/`6379` because that is the
> in‑container default. On the host, Docker **publishes** Postgres on **5434** and Redis on
> **6382** (to avoid clashing with other local stacks). For **native** `npm run dev`, use the
> **published** ports as shown above. Inside Docker, compose overrides these to `db:5432` /
> `redis:6379` automatically.

### 4.2 admin/.env

```dotenv
DATABASE_URL=postgresql://vibe:vibe_password@localhost:5434/vibe_db
DATABASE_SSL=disable
AUTH_SECRET=            # openssl rand -hex 32
SESSION_MAX_AGE=28800
SUPER_ADMIN_EMAIL=admin@vibe.app
SUPER_ADMIN_PASSWORD=   # strong password
R2_PUBLIC_BASE_URL=https://pub-....r2.dev   # read-only public base, NO secret keys
PORT=3020
NODE_ENV=development
```

---

## 5. Infrastructure: Postgres + Redis (Docker)

The root `docker-compose.yml` defines every service. For local dev you typically only run the
**db** and **redis** containers and run backend/admin/flutter natively (faster reloads).

**Published host ports (memorize these):**

| Service | Host port | Container port | Notes |
|---|---|---|---|
| Postgres + PostGIS | **5434** | 5432 | image `postgis/postgis:16-3.4` |
| Redis | **6382** | 6379 | image `redis:7-alpine` |
| Backend (docker) | **3010** | 3000 | only when run via compose |
| Admin | **3020** | 3020 | Next.js |
| Flutter web (profile) | 8080 | 80 | `--profile web` |
| Mailhog (profile) | 1025 / 8025 | — | `--profile mail`, UI at :8025 |

```bash
cd ~/dev/hloppl
docker compose up -d db redis          # start just the datastores
docker compose ps                       # both should be healthy
```

**Migrations auto-run on first boot** of an empty Postgres volume (the compose file mounts
`./database/migrations` into `/docker-entrypoint-initdb.d`). There are 15 migrations
(`000_extensions.sql` … `014_event_quota.sql`).

- To **re-run migrations from scratch** (destructive — wipes data):
  ```bash
  docker compose down -v && docker compose up -d db redis
  ```
- If Postgres already existed and you added a new migration, apply it manually:
  ```bash
  docker exec -i vibe_db psql -U vibe -d vibe_db < database/migrations/0XX_new.sql
  ```
- Backend also has `npm run migrate` (runs `src/scripts/migrate.ts`) as an alternative path.

> **DB password gotcha:** the compose default is `POSTGRES_PASSWORD=vibe_password` (user `vibe`,
> db `vibe_db`). Some older `.env` samples reference a different password/host (`vibe_postgres`).
> For local Docker, use **`vibe` / `vibe_password` / localhost:5434**.

---

## 6. Backend (Node / Express / TypeScript)

```bash
cd ~/dev/hloppl/backend
nvm use 20
npm install
# ensure backend/.env exists (§4.1) and db+redis are up (§5)
npm run dev            # nodemon + ts-node, listens on PORT (3000)
```

Verify:
```bash
curl http://localhost:3000/api/health        # or whatever the health route is
```

Useful scripts:
| Command | What it does |
|---|---|
| `npm run dev` | hot-reload dev server (ts-node) |
| `npm run build` | `tsc` → `dist/` |
| `npm start` | run compiled `dist/index.js` |
| `npm test` | `node --test` suite (`TS_NODE_TRANSPILE_ONLY=1`) — **27+ tests incl. Google Maps proxy** |
| `npm run typecheck` | `tsc --noEmit` |
| `npm run lint` | eslint |

> To run backend via ts-node you may need `TS_NODE_TRANSPILE_ONLY=1` (already set in the `test`
> script). `tsc --noEmit` is clean on its own.

### 6.1 Google Maps proxy (key stays server-side)

Endpoints under `/api/maps/*` (all authed): `geocode`, `reverse-geocode`, `places/autocomplete`,
`places/details`, `static`. If `GOOGLE_MAPS_API_KEY` is unset, they return **503
`MAPS_UNCONFIGURED`** and the app degrades gracefully (manual address entry still works). To go
live, set the key in `backend/.env` and enable **Geocoding API, Places API, Maps Static API** in
Google Cloud.

---

## 7. Admin Panel (Next.js 16 / React 19)

```bash
cd ~/dev/hloppl/admin
nvm use 20
npm install
# ensure admin/.env exists (§4.2) and Postgres is up
npm run dev            # Next.js on :3020  → http://localhost:3020
```
Talks **directly to Postgres** (no backend dependency). Log in with the super‑admin creds from
`admin/.env`. Scripts: `npm run build`, `npm start`, `npm test` (vitest), `npm run lint`.

---

## 8. Frontend (Flutter app)

```bash
cd ~/dev/hloppl/frontend
flutter pub get
# ensure firebase config files exist (§4): google-services.json, firebase_options.dart

# Run against your local backend. The API base URL is a dart-define (never hardcoded):
flutter run --dart-define=API_BASE_URL=http://localhost:3000        # iOS sim / macOS / web
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000         # Android emulator
flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:3000    # physical device
```

- Default (no dart-define) points at **production**: `https://nearme.theworkersdesk.tech`.
- Package id: `com.nearme.vibe` (unchanged). Visible app name: **hloppl**.
- Native plugins needing platform config: `firebase_*`, `google_sign_in`, `geolocator`,
  `permission_handler`, `image_picker`, `url_launcher`. On iOS run `cd ios && pod install` if
  Flutter doesn't do it automatically.

Verify:
```bash
flutter analyze          # expect: No issues found!
flutter test             # unit/widget tests incl. maps_service_test.dart (6 tests)
flutter doctor           # all green
```

### 8.1 Building releases

```bash
flutter build apk --split-per-abi --dart-define=API_BASE_URL=https://nearme.theworkersdesk.tech
flutter build appbundle --dart-define=API_BASE_URL=https://nearme.theworkersdesk.tech
flutter build ios       # requires signing in Xcode
```

---

## 9. Full‑Stack Bring‑Up Checklist

```bash
# From workspace root
cd ~/dev/hloppl

# 1. Datastores
docker compose up -d db redis && docker compose ps          # healthy?

# 2. Backend
( cd backend && nvm use 20 && npm install && npm run dev ) & # :3000

# 3. Admin
( cd admin && nvm use 20 && npm install && npm run dev ) &   # :3020

# 4. App
cd frontend && flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Sanity checks:
- [ ] `docker compose ps` → `vibe_db` + `vibe_redis` healthy
- [ ] Backend `npm test` → all pass (incl. maps proxy)
- [ ] `curl localhost:3000/api/...` returns JSON
- [ ] Admin loads at `http://localhost:3020` and super‑admin can log in
- [ ] `flutter analyze` clean, `flutter test` passes
- [ ] App boots, hits backend, maps preview renders (if `GOOGLE_MAPS_API_KEY` set) or degrades cleanly

---

## 10. Production reference (context only)

Prod runs at `https://nearme.theworkersdesk.tech` (backend behind nginx/Cloudflare SSL, PM2 /
Docker). Do not point local dev writes at prod. See `deploy/` for details.

---

## 11. Common Pitfalls

| Symptom | Cause / Fix |
|---|---|
| `ECONNREFUSED` to Postgres | Wrong port — host is **5434**, not 5432. Check `backend/.env`. |
| Redis connection refused | Host Redis is **6382**, not 6379. |
| Migrations didn't run | They only auto-run on a **fresh** volume. `docker compose down -v` to reset (wipes data). |
| `req.user` type error under ts-node | Set `TS_NODE_TRANSPILE_ONLY=1` (already in the test script). |
| App can't reach backend on Android emulator | Use `10.0.2.2`, not `localhost`, in `API_BASE_URL`. |
| Firebase build errors | Missing `google-services.json` / `firebase_options.dart` — see §4. |
| Maps returns 503 | `GOOGLE_MAPS_API_KEY` unset or APIs not enabled in Google Cloud. |
| admin can't be cloned | It has no remote — see §1.1. |
| `flutter` version mismatch | Pin 3.41.5 (FVM) to match `pubspec` constraints. |

---

_Last updated: 2026-09-05. Companion doc: [`HANDOFF.md`](HANDOFF.md)._
