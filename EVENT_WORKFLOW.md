# hloppl — Event Workflow (APIs + Frontend Design)

> The create-event workflow, ticketing, visibility tiers, auto-deactivation, and
> the premium plan. Built 2026-09-13. Backend = Node/Express/TS + Postgres/PostGIS;
> frontend = Flutter/Riverpod. Companion to [`HANDOFF.md`](HANDOFF.md).

## Create-event fields
| Field | Rule |
|---|---|
| Event name (`title`) | required, **≤ 30 chars** |
| Description | required, **≤ 150 chars** ("What's it about?") |
| Date & time (`eventDate`) | required, must be future |
| Banner (`coverImageUrl`) | optional; uploaded via `POST /events/banner` → URL |
| Location | offline: GPS **or** typed address (lat/lng + address); online: `meetingLink` |
| Entry (`isPaid`) | dropdown Free / Paid; paid requires `price` (whole ₹, > 0) |
| No. of tickets (`maxParticipants`) | optional; **free ≤ 50**, premium unlimited |
| Visibility (`visibilityRadiusM`) | 2 / 5 / 10 / 25 km (free) · **50 km premium-only** |

## Plans & limits
| | Free | Premium (₹99/mo · ₹219/3mo) |
|---|---|---|
| Events / month | 3 | Unlimited |
| Tickets per event | ≤ 50 | Unlimited |
| Visibility radius | ≤ 25 km | up to 50 km |
| Pre-event reminders | — | ✓ |

Free-host caps are enforced at create time (`assertWithinPlanLimits`); premium bypasses them.

## Lifecycle / auto-deactivation
- **Sold out** — when the final seat is booked (`POST /events/:id/join`), the event is
  deactivated immediately and the **host is notified** (FCM). No more bookings.
- **Unsold** — a cron (`*/5`) deactivates any active event entering its **final hour**
  (`event_date` within 60 min), so bookings close 1 hour before start.
- **Reminders** — a cron (`*/5`) pushes a "starts in ~1 hour" notice to attendees, but
  **only for premium hosts' events** (60–65 min window, once, via `reminder_sent`).

## API
All under `/api/events`, authenticated.
| Method | Path | Notes |
|---|---|---|
| GET | `/events?lat=&lng=&mode=&category=&page=&limit=` | Feed; offline events filtered by their visibility radius around the viewer |
| GET | `/events/:id` | Detail |
| POST | `/events` | Create (validation + free-host caps + quota) |
| GET | `/events/quota` | `{used, limit, remaining, isPremium, premiumUntil, resetsAt, canCreate}` |
| GET | `/events/plans` | Plan catalog + free/premium capability matrix |
| POST | `/events/banner` | Multipart (`image`) → `{url}` |
| POST | `/events/subscribe` | `{plan: monthly\|quarterly}` — mock purchase (gated by `ALLOW_MOCK_PREMIUM`) |
| POST | `/events/:id/join` · DELETE `/leave` | RSVP; join triggers sold-out check |

**Errors**: `400 VALIDATION_ERROR` (name/desc/price/visibility tier), `402 EVENT_QUOTA_EXCEEDED`
(monthly limit, or free caps on tickets/visibility), `400` "Event is full" on join.

⚠️ `POST /events/subscribe` grants premium with **no payment** — gated behind `ALLOW_MOCK_PREMIUM`
(off by default). Replace with a verified payment webhook before production.

## Schema (migration 015_event_workflow.sql, mirrored to all 3 migration dirs)
`events` += `is_paid BOOL`, `price INT` (₹, null=free, CHECK ≥0), `visibility_radius_m INT`
(CHECK ∈ {2000,5000,10000,25000,50000}, default 5000). Tickets reuse `max_participants`.

## Frontend
- **Create screen** (`create_event_screen.dart`): banner picker (upload → preview), name/desc
  with char counters, Free/Paid dropdown + ₹ price, tickets (digits only), visibility chips with
  the 50 km chip **locked** (lock icon) → opens the paywall; exceeding the free ticket cap also
  opens it.
- **Paywall** (`widgets/events/premium_plans_sheet.dart`): bottom sheet listing both plans with
  per-month effective price + perk list; `subscribe(plan)` then invalidates the quota. Reused by
  the profile "Upgrade" action and the create-screen locks.
- **Model/service** carry `isPaid`/`price`/`visibilityRadiusM`; `event_service` adds
  `plans()`, `uploadBanner()`, `subscribe(plan)`; feed sends viewer `lat/lng`.
- Event detail shows a **Free / ₹price** chip.

## Verification (2026-09-13)
Backend `tsc` clean, **42 tests**; frontend `analyze` clean, **11 tests**. Migration applied to
dev DB. HTTP e2e vs docker DB: plans/quota OK; name>30, paid-without-price, bad-visibility → 400;
free 50 km → 402; subscribe quarterly → 90-day premium; premium 50 km create → 201; filling the
last seat flipped `is_active` false (sold-out deactivation) and ran the host-notify path.
