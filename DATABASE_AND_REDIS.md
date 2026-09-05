# hloppl — Database & Redis Guide

> Everything about the **PostgreSQL 16 + PostGIS** database and the **Redis 7** cache for
> **hloppl** (formerly "Vibe") — setup (Docker **and** native macOS), connection details, the
> full schema/migration list, PostGIS geo usage, the cache‑aside model, and backup/restore.
>
> Companion to [`MAC_SETUP.md`](MAC_SETUP.md) (full stack) and [`HANDOFF.md`](HANDOFF.md)
> (project history). `MAC_SETUP.md` §5 has the quick Docker version; **this file is the deep
> reference.**
>
> _Last updated: 2026‑09‑05._

---

## 1. At a glance

| | PostgreSQL | Redis |
|---|---|---|
| Version / image | **16 + PostGIS 3.4** (`postgis/postgis:16-3.4`) | **7** (`redis:7-alpine`) |
| Role | Source of truth (users, connections, messages, events, OTP, support, admin) | First‑layer cache (cache‑aside) + rate‑limit assist |
| Host port (Docker) | **5434** → 5432 | **6382** → 6379 |
| Container name | `vibe_db` | `vibe_redis` |
| Local creds | user `vibe` / pw `vibe_password` / db `vibe_db` | no auth (dev) |
| Persistence | named volume `postgres-data` | named volume `redis-data` (AOF `--appendonly yes`) |
| If it's down | app is broken (required) | app still works — degrades to **DB‑only** |

> **Port gotcha:** the in‑container defaults are 5432/6379, but Docker **publishes** them on
> **5434/6382** on the host to avoid clashing with other local stacks. Native (non‑Docker) apps
> connect to `localhost:5434` / `localhost:6382`. Inside Docker, compose rewrites the URLs to
> `db:5432` / `redis:6379` automatically.

---

## 2. PostgreSQL — setup

### Option A — Docker (recommended, matches production behavior)

The root `docker-compose.yml` runs Postgres with PostGIS and **auto‑runs the migrations** on the
first boot of an empty volume (it mounts `./database/migrations` into
`/docker-entrypoint-initdb.d`).

```bash
cd ~/dev/hloppl
docker compose up -d db          # start just Postgres
docker compose ps                 # wait for vibe_db → healthy
docker compose logs -f db         # watch first-boot migration run
```

Connect:
```bash
# from the host (psql installed via: brew install libpq  OR  brew install postgresql@16)
psql "postgresql://vibe:vibe_password@localhost:5434/vibe_db"
# or exec into the container (no host psql needed)
docker exec -it vibe_db psql -U vibe -d vibe_db
```

### Option B — Native macOS (Homebrew)

Only if you prefer no Docker for the DB. You must install PostGIS too.

```bash
brew install postgresql@16 postgis
brew services start postgresql@16
createuser -s vibe            # or: psql postgres -c "CREATE ROLE vibe LOGIN PASSWORD 'vibe_password' SUPERUSER;"
createdb -O vibe vibe_db
psql -d vibe_db -c "ALTER USER vibe WITH PASSWORD 'vibe_password';"
# native Postgres listens on 5432 by default — either change your .env to :5432,
# or run it on 5434 to match Docker:  (edit postgresql.conf: port = 5434)
```

Then apply migrations **in order** (native install does NOT auto‑run them):
```bash
for f in database/migrations/*.sql; do
  echo "applying $f"; psql "postgresql://vibe:vibe_password@localhost:5434/vibe_db" -f "$f" || break
done
# or use the backend helper:
cd backend && npm run migrate
```

---

## 3. Migrations

Migrations live in **`database/migrations/`** and are mirrored to **`backend/migrations/`** and
**`postgres/migrations/`** — keep all three in sync when adding one.

- **Auto‑run:** only via Docker, and only on a **fresh** volume (empty `postgres-data`).
- **Reset (destructive — wipes all data):**
  ```bash
  docker compose down -v && docker compose up -d db redis
  ```
- **Apply one new migration to an existing DB:**
  ```bash
  docker exec -i vibe_db psql -U vibe -d vibe_db < database/migrations/0XX_new.sql
  ```

### Migration list (000 → 014)

| # | File | What it does |
|---|---|---|
| 000 | `000_extensions.sql` | `postgis`, `uuid-ossp`, `pgcrypto` extensions |
| 001 | `001_create_users.sql` | `users` table + GIST geo index + `updated_at` & **generation** triggers |
| 002 | `002_create_connections.sql` | `connections` (double opt‑in friend requests) + status indexes |
| 003 | `003_create_messages.sql` | `messages` (chat) + per‑connection & unread indexes |
| 004 | `004_create_events.sql` | `events` (online/offline) + GIST geo index |
| 005 | `005_create_event_participants.sql` | `event_participants` join table |
| 006 | `006_create_otps.sql` | `otps` (email/phone OTP) + cleanup index |
| 007 | `007_create_blocked_users.sql` | `blocked_users` (block/unblock) |
| 008 | `008_event_reminders.sql` | `events.reminder_sent` column + reminder index (cron) |
| 009 | `009_index_hygiene.sql` | extra index on `messages.sender_id` |
| 010 | `010_token_invalidation.sql` | `users.tokens_valid_from` (JWT invalidation cutoff) |
| 011 | `011_add_is_admin.sql` | `users.is_admin` flag |
| 012 | `012_create_support.sql` | `support_tickets` + `support_messages` + 3 enums (Help & Support) |
| 013 | `013_create_admin.sql` | `admins` + append‑only `admin_audit_logs` (admin panel) |
| 014 | `014_event_quota.sql` | `users.is_premium` + `premium_until` + `idx_events_creator_created` (event quota) |

---

## 4. Schema overview (tables)

| Table | Purpose | Notes |
|---|---|---|
| `users` | accounts + profile + geo | `location GEOGRAPHY(Point,4326)`, GIST‑indexed; see §5 |
| `connections` | friend requests | `sender_id`/`receiver_id` + `status` (double opt‑in) |
| `messages` | 1:1 chat | tied to a connection; `is_read` unread index |
| `events` | local events | `mode` online/offline, `location` GIST‑indexed, `event_date`, `reminder_sent` |
| `event_participants` | event RSVPs | `(event_id, user_id, status)` |
| `otps` | email/phone OTP | `identifier`, `type`, `is_used`, `expires_at` |
| `blocked_users` | blocks | `blocker_id` / `blocked_id` |
| `support_tickets` / `support_messages` | Help & Support | enums: category/status/author |
| `admins` / `admin_audit_logs` | admin panel | audit logs are **append‑only** (trigger‑enforced) |

### `users` table (key columns)

```
id                  UUID PK  DEFAULT gen_random_uuid()
email               VARCHAR(255) UNIQUE NOT NULL
phone               VARCHAR(20)  UNIQUE NOT NULL
password_hash       VARCHAR(255)              -- NULL for Google sign-in
full_name, age, gender, bio, profile_photo_url, interests TEXT[]
generation_category VARCHAR(20)  -- 'gen_z' | 'millennial' | 'gen_x'  (see gotcha)
location            GEOGRAPHY(Point, 4326)    -- GIST-indexed for ST_DWithin
firebase_uid        VARCHAR(128) UNIQUE
fcm_token           TEXT
email_verified, phone_verified, is_active   BOOLEAN
is_admin, is_premium                        BOOLEAN  (migrations 011 / 014)
premium_until, tokens_valid_from, last_seen, created_at, updated_at  TIMESTAMPTZ
```

### ⚠️ Schema gotcha — `generation_category`

`generation_category` is **derived from `age` by the `trg_users_generation` trigger**, **not** a
stored generated column. The birth‑year calc uses `CURRENT_DATE`, which Postgres rejects as
non‑immutable inside a `GENERATED ALWAYS AS (...) STORED` expression. Do **not** "fix" it into a
generated column — it will fail to migrate. The trigger sets: `>=1997 → gen_z`, `>=1981 →
millennial`, else `gen_x` (NULL when age is NULL).

---

## 5. PostGIS — geo queries

- Both `users.location` and `events.location` are `GEOGRAPHY(Point, 4326)` (WGS‑84 lat/lng),
  each backed by a **GIST index** (`idx_users_location`, `idx_events_location`).
- **People‑find is a fixed 5 km radius, server‑enforced** — `DISCOVER_RADIUS_METERS = 5000` in
  `backend/src/services/discover.service.ts`; any client‑supplied radius is ignored. It uses
  `ST_DWithin(location, :point, 5000)` (meters, because the column is `GEOGRAPHY`).
- Store points as `ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography` — **lng first, then
  lat**.

Quick check:
```sql
-- how many users within 5km of a point (lng, lat)
SELECT count(*) FROM users
WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint(77.2090, 28.6139),4326)::geography, 5000);
```

---

## 6. Redis — setup

### Option A — Docker (recommended)

```bash
docker compose up -d redis
docker exec -it vibe_redis redis-cli ping     # → PONG
# from host (brew install redis for the CLI):
redis-cli -p 6382 ping
```

Redis runs with **AOF persistence** (`--appendonly yes`, volume `redis-data`).

### Option B — Native macOS

```bash
brew install redis
brew services start redis            # listens on 6379 by default
# either set REDIS_URL=redis://localhost:6379, or run on 6382 to match Docker
redis-cli ping
```

### Config in `backend/.env`

```dotenv
REDIS_URL=redis://localhost:6382     # native dev against Docker Redis; empty ⇒ DB-only
CACHE_TTL_FEED=60                     # event feed cache TTL (seconds)
CACHE_TTL_EVENT=120                   # event detail cache TTL (seconds)
```

> **Redis is optional.** Unset `REDIS_URL` (or if Redis is down) → the backend logs a warning
> and serves everything straight from Postgres. Nothing breaks; it's just slower.

---

## 7. How the cache is used (cache‑aside)

Implemented in `backend/src/config/redis.ts`: `cached(key, ttlSeconds, loader)` returns the
cached JSON if present, else runs `loader()`, stores it with `EX ttl`, and returns it.
`invalidate(keys, prefix)` deletes exact keys and/or everything under a prefix, and is called
after writes.

| Cache key | TTL | Written by | Invalidated when |
|---|---|---|---|
| `events:list:<mode>:<category>:<limit>:<offset>` | `CACHE_TTL_FEED` (60s) | event feed reads | any event create/update/delete (whole `events:list:` prefix) |
| `events:detail:<eventId>` | `CACHE_TTL_EVENT` (120s) | event detail reads | that event's create/update/delete |
| `maps:geocode:<address>` | 24h | Maps geocode proxy | TTL only |
| `maps:reverse:<rounded lat,lng>` | 24h | Maps reverse‑geocode | TTL only |
| `maps:autocomplete:<input>` | 5m | Maps places autocomplete | TTL only |
| `maps:place:<placeId>` | 24h | Maps place details | TTL only |

Inspect at runtime:
```bash
redis-cli -p 6382 keys 'events:*'
redis-cli -p 6382 keys 'maps:*'
redis-cli -p 6382 get 'events:detail:<uuid>'
redis-cli -p 6382 flushall            # clear the whole cache (safe; it just re-fills from DB)
```

---

## 8. Backup & restore (Postgres)

```bash
# Dump (custom format, compressed)
docker exec vibe_db pg_dump -U vibe -Fc vibe_db > hloppl_$(date +%F).dump

# Restore into a fresh DB
docker exec -i vibe_db pg_restore -U vibe -d vibe_db --clean --if-exists < hloppl_YYYY-MM-DD.dump

# Plain SQL dump (portable / human-readable)
docker exec vibe_db pg_dump -U vibe --no-owner vibe_db > hloppl_$(date +%F).sql
```

Redis (dev) generally needs no backup — it's a rebuildable cache. The AOF file lives in the
`redis-data` volume if you ever need it.

---

## 9. Handy commands

```bash
# Postgres
docker exec -it vibe_db psql -U vibe -d vibe_db          # shell
\dt                                                       # list tables (inside psql)
\d+ users                                                 # describe a table
SELECT count(*) FROM users;                               # sanity

# Which migrations ran? (there's no migrations table — check objects)
docker exec vibe_db psql -U vibe -d vibe_db -c "\dt"
docker exec vibe_db psql -U vibe -d vibe_db -c "\d users" | grep -E "is_premium|is_admin"

# Redis
redis-cli -p 6382 info keyspace                           # how many keys
redis-cli -p 6382 monitor                                 # live command stream (debug)
```

---

## 10. Troubleshooting

| Symptom | Fix |
|---|---|
| `ECONNREFUSED :5432` | Wrong port — host Postgres is **5434**. Update `DATABASE_URL`. |
| `ECONNREFUSED :6379` | Host Redis is **6382** (Docker). Update `REDIS_URL`. |
| Migrations didn't run | They only auto‑run on a **fresh** volume. `docker compose down -v` (wipes data) or apply manually (§3). |
| `password authentication failed` | Local Docker creds are `vibe` / `vibe_password` / `vibe_db`. Ignore older samples that reference host `vibe_postgres` or another password. |
| `type "geography" does not exist` | PostGIS extension missing — ensure `000_extensions.sql` ran (native installs need `brew install postgis`). |
| Generation column migration fails | You turned `generation_category` into a STORED generated column — revert to the trigger (§4). |
| Cache seems stale | TTL is 60s/120s; or `redis-cli -p 6382 flushall`. Cache always re‑fills from DB. |
| App slow but working | Redis is probably down/unset — backend fell back to DB‑only (check logs). |
