# Admin Script Runner

The admin app has a built-in script runner (click **Script** in the header) for running JavaScript against the admin API.

## How it works

- All newlines are replaced with spaces before execution
- Smart quotes and other unicode characters are sanitized to ASCII
- Scripts must use **semicolons** between statements
- The joined code is shown in the output before running

## Available variables

- `h` — auth headers object (includes `Content-Type: application/json`)
- `API` — the base URL (e.g., `https://www.canopyevents.app`)
- `toast(msg)` — show a toast notification
- `log(...)` — output to the result panel (use instead of `console.log`)
- `fetch` — standard fetch API

## Writing scripts for the runner

**Always use semicolons between statements.** Lines get joined with spaces, so without semicolons `const x = 1 const y = 2` is a syntax error.

**Keep string values on one line.** If a string wraps across lines, the textarea inserts a real newline inside the string which breaks it.

**Good:**
```js
const r = await fetch(API + '/api/admin/events', {headers:h}); const events = await r.json(); log(events.length)
```

**Bad (no semicolons):**
```js
const r = await fetch(API + '/api/admin/events', {headers:h})
const events = await r.json()
log(events.length)
```

**Bad (string wraps across lines):**
```js
const r = await fetch(API + '/api/admin/events', {method:'POST', headers:h, body:JSON.stringify({description:'This is a very long
description that wraps'})}); // BROKEN - newline inside string
```

## Common patterns

### Create an event
```js
const r = await fetch(API + '/api/admin/events', {method:'POST', headers:h, body:JSON.stringify({name:'Event Name', slug:'event-name-2026', description:'Description here.', startDate:'2026-06-01T17:00:00Z', endDate:'2026-06-01T23:00:00Z', location:'Venue Name', neighborhood:'Neighborhood', category:'community', city:'seattle', isFree:true, isAccessible:true})}); const ev = await r.json(); log('Created:', ev.name, ev.id)
```

### Add schedule sessions to an event
```js
const eid = 'PASTE-EVENT-ID-HERE'; const dates = ['2026-06-01','2026-07-01','2026-08-01']; for (let i=0;i<dates.length;i++){const d=dates[i];const title=new Date(d+'T12:00:00Z').toLocaleDateString('en-US',{weekday:'long',month:'long',day:'numeric'});await fetch(API+'/api/admin/events/'+eid+'/schedule',{method:'POST',headers:h,body:JSON.stringify({title:title,description:'Session description.',startTime:d+'T17:00:00Z',endTime:d+'T23:00:00Z',category:'General'})});log('Created:',title)}
```

### Update session descriptions for an event
```js
const r = await fetch(API + '/api/events/EVENT-SLUG-HERE'); const ev = await r.json(); for(let i=0;i<ev.scheduleItems.length;i++){const si=ev.scheduleItems[i];await fetch(API+'/api/admin/schedule/'+si.id,{method:'PUT',headers:h,body:JSON.stringify({description:'New description here.'})});log(i,si.title)}
```

### Find event ID by name
```js
const r = await fetch(API + '/api/admin/events', {headers:h}); const events = await r.json(); const e = events.find(e => e.name.includes('Search Term')); log(e.name, e.id)
```

### Count events by category
```js
const r = await fetch(API + '/api/admin/events', {headers:h}); const events = await r.json(); const cats = {}; for (const e of events) { cats[e.category] = (cats[e.category]||0)+1; } log(cats)
```

### Find events without images
```js
const r = await fetch(API + '/api/admin/events', {headers:h}); const events = await r.json(); const noImg = events.filter(e => !e.image_url); log(noImg.length + ' events without images:'); noImg.forEach(e => log('-', e.name))
```

### List venues and event counts
```js
const vr = await fetch(API + '/api/admin/venues', {headers:h}); const venues = await vr.json(); const er = await fetch(API + '/api/admin/events', {headers:h}); const events = await er.json(); venues.forEach(v => { const count = events.filter(e => e.venue_id === v.id).length; log(v.name, ':', count, 'events') })
```

### Events in next 7 days
```js
const r = await fetch(API + '/api/admin/events', {headers:h}); const events = await r.json(); const now = new Date(); const week = new Date(now.getTime() + 7*24*60*60*1000); const upcoming = events.filter(e => new Date(e.start_date) >= now && new Date(e.start_date) <= week); log(upcoming.length + ' events in next 7 days:'); upcoming.forEach(e => log('-', e.name))
```

### Count events by neighborhood
```js
const r = await fetch(API + '/api/admin/events', {headers:h}); const events = await r.json(); const hoods = {}; for (const e of events) { const n = e.neighborhood || '(none)'; hoods[n] = (hoods[n]||0)+1; } Object.entries(hoods).sort((a,b)=>b[1]-a[1]).forEach(([k,v])=>log(v,k))
```

## API endpoints available

- `GET /api/admin/events` — list all events (raw DB columns)
- `GET /api/events/:slug` — single event with stages, schedule, pins (camelCase)
- `POST /api/admin/events` — create event
- `PUT /api/admin/events/:id` — update event
- `DELETE /api/admin/events/:id` — delete event
- `POST /api/admin/events/:eventId/schedule` — add schedule item
- `PUT /api/admin/schedule/:id` — update schedule item
- `DELETE /api/admin/schedule/:id` — delete schedule item
- `GET /api/admin/venues` — list venues
- `POST /api/admin/venues` — create venue
- `PUT /api/admin/venues/:id` — update venue
