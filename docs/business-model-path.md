# Canopy — Business Model & Path to Revenue

## Current State

- **You** curate all event data (via Claude Code, admin dashboard, or URL import)
- All users see the same events for free
- No organizer involvement yet
- Backend hosted on Railway, iOS app on device

## Revenue Model (from MVP spec)

1. **Organizer SaaS** — tiered pricing for dashboard access (free tier for small events, paid for push notifications, analytics, branding)
2. **Promoted events** — paid placement in the discovery feed
3. **Ticketing referral fees** — affiliate commission from ticketing providers
4. **NOT ads** — banner ads in an event app are a terrible experience

## The Tension

You're doing the organizers' job for free right now. That's actually fine for Phase 1 — the spec says to seed content manually and prove the attendee experience first. You don't need revenue yet, you need users.

## Path to Revenue

### Phase 1: Seed Content (Now)

- Curate 10–15 Seattle events manually
- Get the app in front of attendees at real events
- Prove people actually use it — bookmark sessions, check maps, keep the app installed between events
- Key metric: do users keep the app installed and open it for a second event?

### Phase 2: First Organizer Partners

- Approach organizers with the working app: "Your event is already in here, 500 people used it last weekend. Want to manage your own schedule and send push notifications?"
- The dashboard becomes **their** product, not yours
- Free for the first year — you need their content more than their money

### Phase 3: Monetize

- Organizers who want push notifications, analytics, and branding pay a monthly fee
- Free tier: event listed in app, basic schedule management
- Paid tier: push notifications, real-time updates, analytics (app opens, schedule saves), custom branding
- Promoted events: paid placement in the discovery feed
- Ticketing referrals: affiliate commission from Eventbrite, AXS, etc.

## What Needs to Be Built for Phase 2

- **Organizer accounts** — login system scoped to their events only
- **Self-service dashboard** — the admin dashboard already does 80% of this, just needs multi-tenant auth
- **Push notifications** — organizers send updates to attendees who opted into their event
- **Basic analytics** — app opens, schedule saves, map views per event

## What Needs to Happen for Phase 1

- Polish the app for real users
- Add more Seattle events (10–15 total)
- App Store submission
- Soft launch: friends, local Reddit, Seattle tech Slack groups
- QR codes at events pointing to the app
- Validate: do users keep it installed between events?
