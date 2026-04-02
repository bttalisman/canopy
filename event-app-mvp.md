# Unified Event App — MVP Plan

## The Problem

Every major event (festivals, fairs, conferences, expos) builds its own app from scratch. Attendees download a new app for each event, learn a new UI, enter their info again, then delete it days later. Organizers spend thousands on an app that gets used once. The result: fragmented, low-quality experiences on both sides.

## The Idea

A single app that attendees keep installed year-round. Events plug into it like channels. Organizers get a powerful toolkit without building anything. Attendees get one app for everything happening in their city.

## Target Market (MVP)

- **City**: Seattle
- **Event types**: Festivals and fairs (Bumbershoot, Bite of Seattle, Seattle Pride, Seafair, Northwest Folklife, PAX West, Emerald City Comic Con, etc.)
- **Why Seattle**: Dense event calendar, tech-savvy population, manageable size for hand-selling to organizers

## Core Features (MVP)

### 1. Event Discovery Feed
- "What's happening this week/weekend" across all participating events
- Filter by date, type, neighborhood
- Save/bookmark events to a personal calendar
- No account required to browse

### 2. Interactive Maps
- Per-event venue maps with labeled stages, vendors, restrooms, first aid, exits
- GPS-based "you are here" dot
- Organizer uploads a custom map image; pins are placed via a web dashboard
- Directions between points within the venue

### 3. Live Schedule
- Filterable by stage/track, time, category
- "My Schedule" — save sessions, get reminders (push notification 10 min before)
- Real-time updates: cancellations, delays, stage changes (organizer pushes via dashboard)
- Conflict detection: "You have two things at 3pm"

### 4. Push Notifications
- Per-event opt-in
- Organizer sends via dashboard: schedule changes, weather alerts, contest announcements, emergency info
- User controls: mute, per-event toggles, quiet hours

### 5. Ticketing (Link-Out for MVP)
- Deep link to the event's existing ticketing provider (Eventbrite, AXS, etc.)
- Display ticket barcode/QR if the provider supports passbook/wallet integration
- **Do not build a ticketing system.** Integrate, don't compete.

## What's NOT in the MVP

- In-app purchasing / payments
- Social features (friend lists, group coordination)
- Vendor/food ordering
- Contests and gamification
- Chat / messaging
- Multi-city support
- Advertising platform

These are all reasonable v2+ features but would bloat the MVP.

## Architecture

### Mobile App
- **Framework**: React Native (single codebase, iOS + Android)
- **State**: local-first with sync — app should work offline at crowded outdoor events where cell service is poor
- **Maps**: MapLibre GL (open source) for base map + custom overlay layer for venue maps
- **Notifications**: Firebase Cloud Messaging (FCM) for Android, APNs for iOS, via Expo Notifications

### Backend
- **API**: Node.js + Express (or Fastify), REST
- **Database**: PostgreSQL (events, schedules, map pins, users)
- **Auth**: Email/password + Apple/Google sign-in (for saved schedules and preferences)
- **File storage**: S3-compatible (venue map images, event logos)
- **Hosting**: Railway or Fly.io for MVP simplicity

### Organizer Dashboard (Web)
- **Framework**: Next.js
- **Features**: upload venue map, place pins, manage schedule, send notifications, view basic analytics (app opens, schedule saves)
- **Access**: invite-only during MVP, one login per event

## Data Model (Simplified)

```
Event
  id, name, slug, description, dates, location, logo_url, map_image_url
  organizer_id, ticketing_url, is_active

Stage (or "Track" or "Zone")
  id, event_id, name, location_on_map (x, y)

ScheduleItem
  id, event_id, stage_id, title, description
  start_time, end_time, category, is_cancelled

MapPin
  id, event_id, label, type (restroom | food | stage | first_aid | exit | custom)
  x, y (on the venue map image), description

User
  id, email, display_name, auth_provider

UserSavedItem
  user_id, schedule_item_id

Notification
  id, event_id, title, body, sent_at, type (update | alert | promo)
```

## Go-To-Market (MVP)

### Phase 1: Seed Content (Weeks 1–4)
- Manually add 5–10 upcoming Seattle events (public schedule data, map screenshots)
- No organizer buy-in needed yet — just prove the attendee experience
- Soft launch to friends, local Reddit, Seattle tech Slack groups

### Phase 2: First Organizer Partners (Weeks 5–8)
- Approach 2–3 small/mid festivals with the working app + their event already in it
- Pitch: "Your event is already here. Want the dashboard to manage it?"
- Free for the first year — we need their content more than their money

### Phase 3: Validate Retention (Weeks 9–12)
- Key metric: do users keep the app installed between events?
- Secondary: do organizers actually use the dashboard, or do we do all the data entry?
- Decide go/no-go on expanding

## Revenue Model (Post-MVP)

- **Organizer SaaS**: tiered pricing for dashboard access (free tier for small events, paid for push notifications, analytics, branding)
- **Promoted events**: paid placement in the discovery feed
- **Ticketing referral fees**: affiliate commission from ticketing providers
- **NOT ads**: banner ads in an event app are a terrible experience

## Key Risks

| Risk | Mitigation |
|------|------------|
| Organizers won't share data | Start by scraping public schedules; prove value first |
| App store discovery is hard | Don't rely on it — QR codes at events, organizer cross-promotion |
| Cell service at events is poor | Offline-first: cache event data, maps, schedule on device |
| Users won't keep it installed | The discovery feed ("what's this weekend") gives a reason to open between events |
| Big players enter the space | Eventbrite could do this but hasn't; speed and local focus are the advantage |

## Success Criteria for MVP

1. **3 events live** with organizer-managed dashboards
2. **500 installs** with at least 2 events viewed per user on average
3. **30% retention** — user opens the app for a second event (different from the first)
4. At least 1 organizer says "this replaced what we were going to build"

## Rough Timeline

| Week | Milestone |
|------|-----------|
| 1–2 | Data model, API, auth, basic mobile scaffold |
| 3–4 | Event detail screen, schedule view, offline caching |
| 5–6 | Interactive maps (custom overlay + pins) |
| 7–8 | Push notifications, organizer dashboard (schedule + map management) |
| 9–10 | Discovery feed, polish, beta testing at 1 real event |
| 11–12 | App store submission, first organizer outreach |
