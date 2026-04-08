# City-Specific Features for Canopy

Features that would specifically appeal to municipal stakeholders (Special Events Office, Office of Arts & Culture, SDOT, Mayor's Office, etc.) and help close a city contract or permit-attached revenue model.

Group them by who in city government cares — different audiences, different priorities.

---

## For the Special Events / Permitting Office

### 1. Permit ID display
A small badge on each event card showing "Permitted by City of Seattle #SE-2026-0142." Trivial to add (just a string field on Event), but instantly signals legitimacy and gives the events office a reason to care: every listing becomes proof of compliance.

### 2. Event organizer contact info (admin-only)
A field that's not shown in-app but visible in the admin portal. Lets the events office reach the organizer through your system. Cheap, makes the admin look like a real CRM, not a toy.

### 3. "Submit your event" public form
A web form (just an admin route) where organizers can self-submit an event for review. This is huge — it offloads data entry from the city *and* you, and demonstrates that the platform can scale without a paid coordinator.

### 4. Cancellation / reschedule push notifications
You already have push infrastructure. Add a one-button "this event is cancelled" or "moved to X" that fires push notifications to everyone who saved it. Cities care about this enormously — weather cancellations are a real headache.

---

## For the Office of Arts & Culture / Tourism

### 5. Accessibility filters
ADA / wheelchair accessible, ASL interpreter, sensory-friendly times, gender-neutral restrooms. These are pin types you already have the model for. The city *will* ask about this — having it built shows you understand civic priorities.

### 6. Free vs ticketed filter
Cities care a lot about equitable access. A "Free events" toggle in the filter row signals you're not just an upsell for ticketed events.

### 7. Multi-language support (at least Spanish)
Even just localizing the UI strings (not event content). Seattle is officially committed to language access — having Spanish makes you "ready for civic adoption" instead of "we'd need to add this for you."

### 8. Neighborhood equity heatmap (admin dashboard)
A view in admin that shows event count per neighborhood. The events office will love this because it surfaces a real equity question they already think about: are events concentrated in Capitol Hill / Downtown vs. distributed to South Seattle? You become the tool that helps them answer it.

---

## For the Department of Transportation (SDOT) & Transit

### 9. "Getting there" recommendations
You already have lat/lng + transit. For each event, show: nearest bus stops, light rail station, bike racks, parking garages with current price. SDOT cares deeply about modal shift — anything that nudges users toward transit is gold.

### 10. Street closure overlays
Pull from Seattle's published street closure data feed (it exists as an open dataset). Show on the event map: "These streets will be closed Sat 9am–6pm." Solves a real friction point.

### 11. Estimated attendance / crowding indicators
Even rough — "expect 5K+, plan extra travel time." Gives the city visibility into demand patterns.

---

## For the Mayor's Office / Communications

### 12. Featured / official events tab
A toggle in admin to mark something as "City of Seattle official" with a small civic seal badge. Lets the mayor's office push civic events (snow response info sessions, vaccine clinics, primary debates) to a captive audience without standing up their own app.

### 13. Civic alerts channel
A separate notification category — opt-in or opt-out — for things like air quality alerts, snow emergencies, voting reminders. Cities desperately want a way to push these without going through Twitter/X. If you offer to be that channel, you're suddenly infrastructure, not an app.

### 14. Public analytics dashboard
A read-only web page (no login) showing aggregate stats: "12,400 Seattle residents used Canopy this month, viewed 86 events, planned routes to 41 venues." Gives the city quotable numbers for press releases. Costs you nothing and creates political capital.

---

## For Procurement & Legal

These aren't user-facing features, but you'll need them to actually close a deal. Build them now and you'll be ready:

### 15. Data export (CSV/JSON) for any event or date range
Government loves owning their data.

### 16. Basic security posture page
Even a one-pager showing "data hosted in US, encrypted at rest, no PII collected, GDPR/CCPA compliant" goes a long way. SOC 2 is the gold standard but not required for a pilot.

### 17. WCAG 2.1 AA compliance pass on the iOS app
The city's procurement process will require this. SwiftUI gets you most of the way; auditing color contrast, dynamic type support, and VoiceOver labels finishes it.

### 18. Open API for city to query their own events
Turns "vendor app" into "platform we can integrate with."

---

## Recommended quick wins (a single weekend of work)

If you want maximum demo impact for minimum effort, build these four:

1. **Permit ID badge** — trivial, signals legitimacy.
2. **Accessibility filter** — shows civic awareness.
3. **Free / ticketed toggle** — shows equity awareness.
4. **Featured "City of Seattle Official" badge with civic seal** — lets you literally show them their own logo inside your app during the meeting. This is the move that closes deals.

That last one is psychological gold. When a city person sees their seal in a real product, it stops being abstract. Suddenly they're imagining their boss seeing it, and they want to be the person who made it happen.
