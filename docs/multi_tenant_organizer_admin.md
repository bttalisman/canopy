# Multi-Tenant Organizer Admin: What's Required

Moving from "you and a couple of trusted people log in to admin" to "external event organizers self-serve their own events" is the difference between an internal tool and a real multi-tenant SaaS. Here's what needs to be in place, grouped by risk level.

---

## Must-haves (cannot ship without these)

### 1. Real authentication
Right now `admin.html` is gated by a single shared API key in a header (`adminHeaders()`). That worked when "admins" was you and one other person. It cannot work for organizers because:
- Anyone with the key has full god-mode access to *every* event.
- You can't revoke one person without rotating for everyone.
- No identity attached to actions ("who edited this?").

You need **per-user accounts with passwords**:
- A `users` table (id, email, password_hash, name, created_at, last_login_at).
- Use bcrypt or argon2 for hashing — never plain.
- Email + password login flow → returns a session token (JWT or opaque token in Postgres).
- Replace the API key header with `Authorization: Bearer <token>`.
- **Email verification** before a new account can do anything.
- **Password reset** flow (email a one-time link).
- Probably **2FA** for organizer accounts (TOTP) — low-effort, high-trust win.

### 2. Authorization (who can edit what)
Even with accounts, you need rules. The minimum:
- A `user_event_roles` join table: `(user_id, event_id, role)` where role ∈ `owner`, `editor`, `viewer`.
- Every admin endpoint must check that the requesting user has the right role for the event in the URL — not just "is logged in."
- A separate `is_superadmin` flag on the users table for you/staff to manage everything across organizers.
- The Map Editor, schedule editor, push notification UI, etc. must all enforce this — right now they trust the client.

This is the single biggest piece of work. **Every admin route in `server/src/routes/admin.js` needs an authorization check added.**

### 3. Scoped event lists
The admin currently shows *every* event in the system. Once organizers sign in, they should only see events they own (plus optionally a "discover other public events" view). Modify the events list endpoint to filter by `user_id`.

### 4. Approval / moderation workflow
Letting random people publish events into a city-facing app means you need a gate:
- New events default to `status='draft'` or `status='pending_review'`, **not visible** in the iOS app.
- A superadmin (you) reviews and clicks "approve" → status changes to `active`.
- Organizers can edit drafts freely; edits to approved events optionally re-trigger review.
- The iOS API should only return `active` events.

Without this, an organizer types "FREE iPhones at Cal Anderson 7pm tonight" and it shows up in your app.

### 5. Push notification rate limits
You already have a push endpoint. Right now an admin can send unlimited pushes to every device subscribed to an event. An organizer with that power could spam tens of thousands of users — and Apple will revoke your APNs cert if they do it badly.

- Per-event push quota (e.g. 5/day, 25/week).
- Profanity / length / formatting checks.
- Scheduled vs immediate sending (most "I'm cancelling" or "schedule changed" pushes are predictable in advance).
- Logging of every push sent (who, when, what, how many devices).

### 6. Audit logging
For everything organizers can do, write an audit row: `(user_id, event_id, action, before, after, timestamp)`. Without this you have zero recourse when "someone deleted my event" turns into a support ticket.

---

## Should-haves (high risk if skipped, but launchable without)

### 7. Input validation + sanitization
Right now the admin form trusts everything the client sends. With external users you need server-side validation on every field:
- String length caps (name, description).
- URL format and protocol whitelist (https only).
- Date sanity checks (end ≥ start, not in the past for new events, not >2 years out).
- HTML escaping anywhere event content is displayed (the iOS app currently treats it as plain text, which is safe — but if you ever render in a webview, you have an XSS hole).
- Image upload size limits and type checks if you let organizers upload (right now it's URL-based, which has its own SSRF risks).

### 8. CSRF protection on the admin web UI
The current admin web app is a same-origin SPA so it's lower risk, but with real auth you'll want either:
- SameSite cookies (strict or lax) and CSRF tokens, *or*
- Just use `Authorization: Bearer` tokens (no cookies → no CSRF). This is the simpler path.

### 9. Rate limiting on auth endpoints
Login, password reset, signup. Without rate limits, you'll get credential-stuffing attempts the day after launch. Use a middleware like `express-rate-limit` keyed on IP + email.

### 10. Rotating the existing API key
Once accounts exist, **revoke the shared `adminHeaders()` API key entirely**. As long as it works, it's a backdoor.

### 11. Soft delete + recovery
Organizers will accidentally delete events. Currently `DELETE /api/admin/events/:id` is a real DB delete (cascades to schedule items, pins, everything). Switch to a `deleted_at` timestamp and a 30-day recovery window. Saves you a lot of "please restore my event" support pain.

### 12. Image storage
If you let organizers upload images instead of pasting URLs, you need somewhere to store them — currently you're hand-dropping files into `server/src/public/images/`. That's fine for you but doesn't scale to 100 organizers. Options:
- **Cheapest:** keep the local filesystem, accept uploads via multipart, scope filenames by `user_id/event_id`, set sane size limits. Works until you outgrow Railway's disk.
- **Better:** S3-compatible object storage (Cloudflare R2 is free up to 10GB and has no egress fees). One-time setup, then organizers can upload directly.

### 13. Per-organizer profile / contact info
Phone, email, organization name, optional verified org badge. Useful for the city pitch ("here's the actual permittee for each event") and for support.

---

## Nice-to-haves (worth doing when you can)

### 14. Dashboard / analytics for organizers
"Your event has been viewed 1,200 times, saved by 340 users, 12 push notifications sent." Organizers want this badly and it's the carrot that makes the per-permit fee model work.

### 15. Bulk import / CSV
Multi-day festivals with hundreds of schedule items will not type them in by hand. You already have the paste-schedule view internally — generalize it.

### 16. Versioning of approved events
Once an event is approved and live, organizer edits should create a draft version that you can review before publishing. Otherwise "reviewer approves Bumbershoot, organizer edits to add a sponsor's racist joke, joke is live in the app for 4 hours before you notice."

### 17. A separate organizer portal vs. internal admin
The current `admin.html` is built for *you* — it has Ticketmaster import, push tools, all events list, etc. Organizers don't need (and shouldn't see) any of that. Eventually you'll want a separate, friendlier `/organizer` route that shows only the relevant subset. Same backend, different UI shell.

### 18. Terms of service and a content policy
Anyone uploading content to a multi-user platform needs to accept terms. Templates exist; have a lawyer skim them once.

---

## Operational / legal (don't forget)

### 19. Privacy policy update
Adding accounts means you're now a data controller for organizers' personal info (name, email, possibly phone). Your existing iOS privacy policy probably doesn't cover this — needs an update. Apple won't care for the iOS app, but organizers will, and the city will ask.

### 20. Backups
Once organizers depend on you, "the database got corrupted and we lost 200 events" is an existential failure. Postgres on Railway has automated backups but verify they're actually running and you know how to restore. Test the restore at least once.

### 21. Customer support inbox
Organizers will email you. Set up a `support@canopy...` address that doesn't go to the email you can't access anymore.

### 22. Support documentation
Even one Notion page with screenshots showing "how to add an event, schedule, map pins" saves you hours of repeated explanation.

---

## Suggested order of implementation

If you're going to tackle this in phases:

**Phase 1 (auth foundation, 1–2 weeks):** items 1, 2, 3, 10. Without these, you can't even start.

**Phase 2 (safety net, 1 week):** items 4, 5, 6, 7, 11. Lets you actually let strangers in.

**Phase 3 (polish for first organizer, ~1 week):** items 9, 12, 13, 22. Makes it possible to onboard the first real external user without hand-holding.

**Phase 4 (everything else):** when you have real users telling you what they need.

---

## Honest take

Items 1, 2, 4 are the wall — you cannot let external users in without those. Items 5 and 6 are the wall after that. Together, these five items represent maybe 2–3 weeks of focused work and they're essentially building a small auth/permissions framework on top of what you have.

Two practical alternatives to consider before building all this:

- **Stay closed for now**: Keep onboarding organizers manually — *you* enter their event into admin while you talk to them. Caps you at maybe 20–30 events but lets you skip Phase 1 entirely. This is fine if you're focused on the city pitch.
- **Use an off-the-shelf auth provider**: Clerk, Auth0, Supabase Auth, or Firebase Auth — they handle items 1, 9, and most of 7 for you, sometimes for free below a usage threshold. Saves you 1–2 weeks and gives you better security than you'd write yourself.

Seriously consider the Clerk/Supabase route. Building auth correctly is more work than it looks, and it's the one place where rolling your own usually ends in a security bulletin.
