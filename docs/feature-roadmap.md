# Canopy — Feature Roadmap & White-Label Competitive Features

## Already Built
- Personalized schedules / My Schedule with bookmarking
- Interactive venue maps with typed pins (MapKit)
- Offline-capable (SwiftData local-first)
- Real-time schedule updates via backend API
- Ticketing link-out to external providers
- Event discovery feed with filtering (time, category, search)
- Conflict detection for saved schedule items
- User location on venue maps
- Admin dashboard for event/schedule management
- AI-powered schedule import (paste text or URL)
- Ticketmaster integration for event discovery

## High-Value Features to Add

### For Attendees

| Feature | Description | Effort |
|---------|-------------|--------|
| Push notifications | Schedule changes, weather alerts, emergency info. Per-event opt-in. | Medium |
| Artist/performer profiles | Bios, photos, social links, linked to schedule items | Low |
| Live polling & voting | During sessions, fan-choice awards | Medium |
| Social/activity feed | Attendees post photos, reactions at events | High |
| Gamification | Scavenger hunts, achievement badges, leaderboards | High |
| Weather integration | Auto-posted weather updates per event day | Low |
| Ride-sharing integration | Link out to Uber/Lyft with venue destination pre-filled | Low |

### For Organizers (Paid Tier)

| Feature | Description | Why They'd Pay |
|---------|-------------|----------------|
| Segmented push notifications | Target by location, ticket type, interests | Direct attendee communication |
| Analytics dashboard | Session saves, map views, app opens, popular stages | Data they can't get anywhere else |
| Sponsor placements | Branded map pins, sponsored sessions in schedule, banner spots | Helps organizers sell sponsorships |
| Lead capture | Sponsors scan attendee QR codes at booths | Sponsors demand measurable ROI |
| Crowd density heatmaps | See where attendees cluster via geofencing | Safety + operational planning |
| Post-event reports | Exportable data for stakeholders | Proves event success to sponsors/boards |
| Real-time capacity alerts | Amber/red warnings per zone | Safety compliance |

### Revenue Generators

| Feature | Description | Revenue Impact |
|---------|-------------|----------------|
| Mobile food/drink pre-ordering | Skip-the-line pickup at vendor booths | Aloompa's biggest revenue feature |
| In-app upsells | VIP upgrades, parking, meet-and-greets post-ticket-purchase | Direct transaction revenue |
| Cashless payments | NFC/wristband integration | Festivals report 15-30% higher per-attendee spend |
| Sponsor packages | Bronze/silver/gold tiers bundling push, map pins, schedule badges, ROI reports | Recurring B2B revenue |
| Promoted events | Paid placement in discovery feed | Self-serve ad revenue |
| Ticketing referral fees | Affiliate commission from Eventbrite, AXS, etc. | Passive revenue per ticket sold |

## Recommended Priority Order

### Phase 1: Get Users (Now)
- Polish existing features
- Seed 10-15 Seattle events
- App Store submission
- Soft launch

### Phase 2: Get Organizers (After proving attendee value)
1. **Push notifications** — low effort, high value, core reason organizers pay
2. **Analytics dashboard** — "500 people saved your headliner" is the organizer pitch
3. **Organizer accounts** — self-service login scoped to their events
4. **Sponsor placements** — map pins, schedule badges, lets organizers offset costs

### Phase 3: Revenue (After organizer adoption)
5. **Sponsor packages** — tiered pricing for bundles of features
6. **Promoted events** — paid discovery feed placement
7. **Food pre-ordering** — big revenue but big build
8. **Ticketing referrals** — affiliate links to ticketing providers

## Pricing Models Observed in Market

- **Per-event licensing**: $500-$5,000 mid-tier; $20,000+ enterprise
- **Per-attendee**: tiered by event size
- **Annual subscription**: discounted multi-event rates
- **Revenue share**: percentage of in-app transactions
- **Sponsorship-funded**: app costs offset by selling sponsor placements
- **Non-profit discounts**: 10% off (industry standard)

## Key Insight

The white-label platforms charge $500-$20,000+ per event because each event gets its own app. Canopy's advantage: organizers get the same features at a fraction of the cost because they're sharing infrastructure. A $50-200/month SaaS tier undercuts every white-label competitor while being more profitable per-organizer at scale.

## Integration Notes

### Eventbrite API
Investigated April 2026. Eventbrite deprecated public event search in 2019 — the `GET /v3/events/search/` endpoint now only returns events you own or have been granted access to. You cannot discover all public events in a city like with Ticketmaster. 

**Potential future use**: organizer-connected import. If an organizer links their Eventbrite account (OAuth), we can pull their event details automatically. This would be a good paid-tier feature ("Connect Eventbrite → auto-import"). Authentication is OAuth 2.0 via their developer portal.

### Ticketmaster API
Currently integrated via server-side proxy. Works well for concert/sports discovery. Does not cover community events, farmers markets, street fairs, etc. Price range data is available but inconsistent — many events return no pricing.

## Sources

- Aloompa (Coachella, Bonnaroo, Lollapalooza)
- Eventbase (SXSW, CES, Olympics)
- Appmiral (Tomorrowland, Live Nation EU)
- Guidebook (conferences, associations)
- Whova (50,000+ events)
- Greencopper (acquired by Spotify/Eventbrite ecosystem)
