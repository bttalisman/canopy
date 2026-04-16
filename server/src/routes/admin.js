const { Router } = require('express');
const Anthropic = require('@anthropic-ai/sdk');
const cheerio = require('cheerio');
const cloudinary = require('cloudinary').v2;
const { pool } = require('../db/pool');
const {
  requireSignedIn,
  requireSuperadmin,
  requireEventAccess,
  requireChildEventAccess,
  isSuperadmin,
  getAuth,
} = require('../middleware/auth');

const router = Router();

// All admin routes require a valid Clerk session.
router.use(requireSignedIn);

// Lookup helpers for child resources — find parent event_id from a child id.
const lookupStageEvent = 'SELECT event_id FROM stages WHERE id = $1';
const lookupScheduleEvent = 'SELECT event_id FROM schedule_items WHERE id = $1';
const lookupPinEvent = 'SELECT event_id FROM map_pins WHERE id = $1';

// =====================
// EVENTS
// =====================

// GET /api/admin/events — list events scoped to the requester's org
// (or all events for superadmins). Includes drafts/pending, unlike the
// public /api/events endpoint.
router.get('/events', async (req, res) => {
  try {
    const auth = getAuth(req);
    const cityFilter = req.query.city || null;
    if (isSuperadmin(req)) {
      const query = cityFilter
        ? 'SELECT * FROM events WHERE city = $1 ORDER BY name ASC'
        : 'SELECT * FROM events ORDER BY name ASC';
      const params = cityFilter ? [cityFilter] : [];
      const { rows } = await pool.query(query, params);
      return res.json(rows);
    }
    if (!auth?.orgId) {
      return res.status(403).json({ error: 'No organization selected' });
    }
    const query = cityFilter
      ? 'SELECT * FROM events WHERE owner_org_id = $1 AND city = $2 ORDER BY name ASC'
      : 'SELECT * FROM events WHERE owner_org_id = $1 ORDER BY name ASC';
    const params = cityFilter ? [auth.orgId, cityFilter] : [auth.orgId];
    const { rows } = await pool.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('admin GET /events error:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/events
router.post('/events', async (req, res) => {
  try {
    const auth = getAuth(req);
    const superadmin = isSuperadmin(req);
    if (!superadmin && !auth?.orgId) {
      return res.status(403).json({ error: 'Select an organization first' });
    }

    const { name, slug, description, startDate, endDate, location, neighborhood,
            logoSystemImage, imageURL, mapImageURL, ticketingURL, latitude, longitude, category, city, venueId,
            priceMin, priceMax } = req.body;

    // Superadmins create active events; organizers create pending_review.
    const status = superadmin ? 'active' : 'pending_review';
    const ownerOrgId = auth?.orgId || null;
    const createdByUserId = auth?.userId || null;

    const { rows } = await pool.query(`
      INSERT INTO events (name, slug, description, start_date, end_date, location, neighborhood,
                          logo_system_image, image_url, map_image_url, ticketing_url, latitude, longitude, category,
                          owner_org_id, created_by_user_id, status, city, venue_id, price_min, price_max)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)
      RETURNING *
    `, [name, slug, description || '', startDate, endDate, location, neighborhood || '',
        logoSystemImage || 'party.popper', imageURL, mapImageURL || null, ticketingURL, latitude, longitude, category || 'community',
        ownerOrgId, createdByUserId, status, city || 'seattle', venueId || null, priceMin || null, priceMax || null]);

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error creating event:', err);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/admin/ticketmaster-browse — browse TM events for import (superadmin only)
router.get('/ticketmaster-browse', requireSuperadmin, async (req, res) => {
  try {
    const apiKey = process.env.TICKETMASTER_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'Ticketmaster API key not configured' });
    }

    const metros = {
      'Seattle':  { latlong: '47.6062,-122.3321', radius: '30' },
      'Tacoma':   { latlong: '47.2529,-122.4443', radius: '15' },
    };
    const cityName = req.query.city || 'Seattle';
    const metro = metros[cityName];

    const params = new URLSearchParams({
      apikey: apiKey,
      page: req.query.page || '0',
      size: req.query.size || '50',
      sort: 'date,asc',
    });

    if (metro) {
      params.set('latlong', metro.latlong);
      params.set('radius', metro.radius);
      params.set('unit', 'miles');
    } else {
      params.set('city', cityName);
      params.set('stateCode', 'WA');
    }

    if (req.query.keyword) params.set('keyword', req.query.keyword);

    const response = await fetch(`https://app.ticketmaster.com/discovery/v2/events.json?${params}`);
    if (!response.ok) {
      return res.status(response.status).json({ error: `Ticketmaster API error: ${response.status}` });
    }

    const data = await response.json();
    const rawEvents = data._embedded?.events || [];

    const simplified = rawEvents.map(ev => {
      const venue = ev._embedded?.venues?.[0];
      // Prefer 16:9 ratio image, fallback to largest
      const images = ev.images || [];
      const img16x9 = images.find(i => i.ratio === '16_9' && i.width >= 640);
      const imageURL = img16x9?.url || images[0]?.url || null;
      const priceRange = ev.priceRanges?.[0];
      const classification = ev.classifications?.[0];

      return {
        tmId: ev.id,
        name: ev.name,
        startDate: ev.dates?.start?.dateTime || ev.dates?.start?.localDate || null,
        endDate: ev.dates?.end?.dateTime || null,
        location: venue?.name || '',
        latitude: venue?.location?.latitude ? parseFloat(venue.location.latitude) : null,
        longitude: venue?.location?.longitude ? parseFloat(venue.location.longitude) : null,
        imageURL,
        ticketingURL: ev.url || null,
        category: classification?.segment?.name?.toLowerCase() || 'other',
        priceMin: priceRange?.min || null,
        priceMax: priceRange?.max || null,
      };
    });

    res.json(simplified);
  } catch (err) {
    console.error('admin GET /ticketmaster-browse error:', err);
    res.status(500).json({ error: 'Failed to fetch from Ticketmaster' });
  }
});

// POST /api/admin/events/import-from-tm — import a TM event into the DB (superadmin only)
router.post('/events/import-from-tm', requireSuperadmin, async (req, res) => {
  try {
    const { tmId, name, startDate, endDate, location, latitude, longitude,
            imageURL, ticketingURL, category, city, priceMin, priceMax, description } = req.body;

    console.log('[TM Import] Body:', JSON.stringify({ name, startDate, endDate, location, category, city }));
    if (!name || !startDate) {
      return res.status(400).json({ error: 'name and startDate are required' });
    }

    // Search TM for all performances of this show to find the full date range
    let resolvedEndDate = endDate;
    const apiKey = process.env.TICKETMASTER_API_KEY;
    if (apiKey && name) {
      try {
        const searchParams = new URLSearchParams({
          apikey: apiKey, keyword: name, size: '50', sort: 'date,asc',
        });
        const tmRes = await fetch(`https://app.ticketmaster.com/discovery/v2/events.json?${searchParams}`);
        if (tmRes.ok) {
          const tmData = await tmRes.json();
          const allEvents = tmData._embedded?.events || [];
          console.log(`[TM Import] TM search for "${name}" returned ${allEvents.length} events`);

          const locationLower = (location || '').toLowerCase();
          const matching = allEvents.filter(ev => {
            const evName = ev.name || '';
            const evVenue = (ev._embedded?.venues?.[0]?.name || '').toLowerCase();
            const nameMatch = evName === name;
            const venueMatch = !location || evVenue.includes(locationLower) || locationLower.includes(evVenue);
            if (nameMatch && !venueMatch) {
              console.log(`[TM Import] Name matched but venue didn't: TM="${evVenue}" vs import="${locationLower}"`);
            }
            return nameMatch && venueMatch;
          });

          const allDates = matching
            .map(ev => ev.dates?.start?.dateTime || ev.dates?.start?.localDate)
            .filter(Boolean)
            .sort();
          console.log(`[TM Import] ${matching.length} venue-matched events, ${allDates.length} dates: ${allDates.join(', ')}`);

          if (allDates.length > 1) {
            const lastDate = allDates[allDates.length - 1];
            resolvedEndDate = new Date(new Date(lastDate).getTime() + 3 * 60 * 60 * 1000).toISOString();
            console.log(`[TM Import] Date range: ${allDates[0]} → ${lastDate}`);
          }
        }
      } catch (e) {
        console.log('[TM Import] Could not resolve date range:', e.message);
      }
    }

    // Generate slug: tm-{slugified name}-{date}
    const datePart = startDate.slice(0, 10); // YYYY-MM-DD
    const nameSlug = name.toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '');
    let slug = `tm-${nameSlug}-${datePart}`;

    // Check for duplicate slugs and append suffix if needed
    const { rows: existing } = await pool.query(
      "SELECT slug FROM events WHERE slug LIKE $1 || '%'", [slug]
    );
    if (existing.length > 0) {
      const existingSlugs = new Set(existing.map(r => r.slug));
      if (existingSlugs.has(slug)) {
        let suffix = 2;
        while (existingSlugs.has(`${slug}-${suffix}`)) suffix++;
        slug = `${slug}-${suffix}`;
      }
    }

    // Try to match a venue by location name
    let venueId = null;
    if (location) {
      const { rows: venueRows } = await pool.query(
        'SELECT id FROM venues WHERE LOWER(name) = LOWER($1) LIMIT 1', [location]
      );
      if (venueRows.length > 0) {
        venueId = venueRows[0].id;
      }
    }

    // end_date is NOT NULL in schema, default to start + 3 hours
    const effectiveEndDate = resolvedEndDate || new Date(new Date(startDate).getTime() + 3 * 60 * 60 * 1000).toISOString();

    const { rows } = await pool.query(`
      INSERT INTO events (name, slug, description, start_date, end_date, location,
                          image_url, ticketing_url, latitude, longitude, category,
                          city, venue_id, price_min, price_max, is_active, status)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, true, 'active')
      RETURNING *
    `, [name, slug, description || '', startDate, effectiveEndDate, location || '',
        imageURL || null, ticketingURL || null, latitude || null, longitude || null,
        category || 'community', city || 'seattle', venueId, priceMin || null, priceMax || null]);

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('admin POST /events/import-from-tm error:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/events/:id/approve — superadmin only
router.post('/events/:id/approve', requireSuperadmin, async (req, res) => {
  try {
    const { rows } = await pool.query(
      "UPDATE events SET status = 'active', updated_at = NOW() WHERE id = $1 RETURNING *",
      [req.params.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Event not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/admin/events/:id
router.put('/events/:id', requireEventAccess, async (req, res) => {
  try {
    const { name, description, startDate, endDate, location, neighborhood,
            logoSystemImage, imageURL, mapImageURL, mapCalibration, mapPinSize, ticketingURL, latitude, longitude, category, isActive,
            permitId, isAccessible, isFree, isCityOfficial, city, venueId, priceMin, priceMax } = req.body;

    const { rows } = await pool.query(`
      UPDATE events SET
        name = COALESCE($2, name),
        description = COALESCE($3, description),
        start_date = COALESCE($4, start_date),
        end_date = COALESCE($5, end_date),
        location = COALESCE($6, location),
        neighborhood = COALESCE($7, neighborhood),
        logo_system_image = COALESCE($8, logo_system_image),
        image_url = COALESCE($9, image_url),
        map_image_url = CASE WHEN $10::text = '' THEN NULL ELSE COALESCE($10, map_image_url) END,
        map_calibration = COALESCE($11, map_calibration),
        map_pin_size = COALESCE($12, map_pin_size),
        ticketing_url = COALESCE($13, ticketing_url),
        latitude = COALESCE($14, latitude),
        longitude = COALESCE($15, longitude),
        category = COALESCE($16, category),
        is_active = COALESCE($17, is_active),
        permit_id = COALESCE($18, permit_id),
        is_accessible = COALESCE($19, is_accessible),
        is_free = COALESCE($20, is_free),
        is_city_official = COALESCE($21, is_city_official),
        city = COALESCE($22, city),
        venue_id = CASE WHEN $23::text = '__KEEP__' THEN venue_id ELSE $24::uuid END,
        price_min = COALESCE($25, price_min),
        price_max = COALESCE($26, price_max),
        updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `, [req.params.id, name, description, startDate, endDate, location, neighborhood,
        logoSystemImage, imageURL, mapImageURL, mapCalibration, mapPinSize, ticketingURL, latitude, longitude, category, isActive,
        permitId, isAccessible, isFree, isCityOfficial, city,
        venueId !== undefined ? 'SET' : '__KEEP__', venueId || null, priceMin || null, priceMax || null]);

    if (rows.length === 0) return res.status(404).json({ error: 'Event not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error('Error updating event:', err);
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/admin/events/:id
router.delete('/events/:id', requireEventAccess, async (req, res) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM events WHERE id = $1', [req.params.id]);
    if (rowCount === 0) return res.status(404).json({ error: 'Event not found' });
    res.json({ deleted: true });
  } catch (err) {
    console.error('Error deleting event:', err);
    res.status(500).json({ error: err.message });
  }
});

// =====================
// STAGES
// =====================

// POST /api/admin/events/:eventId/stages
router.post('/events/:eventId/stages', requireEventAccess, async (req, res) => {
  try {
    const { name, mapX, mapY } = req.body;
    const { rows } = await pool.query(`
      INSERT INTO stages (event_id, name, map_x, map_y)
      VALUES ($1, $2, $3, $4)
      RETURNING *
    `, [req.params.eventId, name, mapX || 0, mapY || 0]);

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error creating stage:', err);
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/admin/stages/:id
router.delete('/stages/:id', requireChildEventAccess(lookupStageEvent), async (req, res) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM stages WHERE id = $1', [req.params.id]);
    if (rowCount === 0) return res.status(404).json({ error: 'Stage not found' });
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================
// SCHEDULE ITEMS
// =====================

// POST /api/admin/events/:eventId/schedule
router.post('/events/:eventId/schedule', requireEventAccess, async (req, res) => {
  try {
    const { stageId, title, description, startTime, endTime, category, performerName, performerBio, performerImageURL, performerLinks } = req.body;
    const { rows } = await pool.query(`
      INSERT INTO schedule_items (event_id, stage_id, title, description, start_time, end_time, category, performer_name, performer_bio, performer_image_url, performer_links)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      RETURNING *
    `, [req.params.eventId, stageId, title, description || '', startTime, endTime, category || 'General', performerName || null, performerBio || null, performerImageURL || null, performerLinks || null]);

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error creating schedule item:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/events/:eventId/schedule/bulk — add multiple at once
router.post('/events/:eventId/schedule/bulk', requireEventAccess, async (req, res) => {
  try {
    const { items } = req.body; // array of { stageId, title, description, startTime, endTime, category }
    const results = [];

    for (const item of items) {
      const { rows } = await pool.query(`
        INSERT INTO schedule_items (event_id, stage_id, title, description, start_time, end_time, category, performer_name, performer_bio, performer_image_url, performer_links)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        RETURNING *
      `, [req.params.eventId, item.stageId, item.title, item.description || '',
          item.startTime, item.endTime, item.category || 'General',
          item.performerName || null, item.performerBio || null, item.performerImageURL || null, item.performerLinks || null]);
      results.push(rows[0]);
    }

    res.status(201).json(results);
  } catch (err) {
    console.error('Error bulk creating schedule:', err);
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/admin/schedule/:id
router.put('/schedule/:id', requireChildEventAccess(lookupScheduleEvent), async (req, res) => {
  try {
    const { stageId, title, description, startTime, endTime, category, isCancelled, performerName, performerBio, performerImageURL, performerLinks } = req.body;

    const { rows } = await pool.query(`
      UPDATE schedule_items SET
        stage_id = COALESCE($2, stage_id),
        title = COALESCE($3, title),
        description = COALESCE($4, description),
        start_time = COALESCE($5, start_time),
        end_time = COALESCE($6, end_time),
        category = COALESCE($7, category),
        is_cancelled = COALESCE($8, is_cancelled),
        performer_name = COALESCE($9, performer_name),
        performer_bio = COALESCE($10, performer_bio),
        performer_image_url = COALESCE($11, performer_image_url),
        performer_links = COALESCE($12, performer_links),
        updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `, [req.params.id, stageId, title, description, startTime, endTime, category, isCancelled, performerName, performerBio, performerImageURL, performerLinks]);

    if (rows.length === 0) return res.status(404).json({ error: 'Schedule item not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/admin/schedule/:id
router.delete('/schedule/:id', requireChildEventAccess(lookupScheduleEvent), async (req, res) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM schedule_items WHERE id = $1', [req.params.id]);
    if (rowCount === 0) return res.status(404).json({ error: 'Schedule item not found' });
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================
// MAP PINS
// =====================

// POST /api/admin/events/:eventId/pins
router.post('/events/:eventId/pins', requireEventAccess, async (req, res) => {
  try {
    const { label, pinType, x, y, latitude, longitude, description } = req.body;
    const { rows } = await pool.query(`
      INSERT INTO map_pins (event_id, label, pin_type, x, y, latitude, longitude, description)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *
    `, [req.params.eventId, label, pinType || 'custom', x ?? 0, y ?? 0, latitude ?? null, longitude ?? null, description || '']);

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error creating map pin:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/events/:eventId/pins/bulk
router.post('/events/:eventId/pins/bulk', requireEventAccess, async (req, res) => {
  try {
    const { pins } = req.body;
    const results = [];

    for (const pin of pins) {
      const { rows } = await pool.query(`
        INSERT INTO map_pins (event_id, label, pin_type, x, y, latitude, longitude, description)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING *
      `, [req.params.eventId, pin.label, pin.pinType || 'custom', pin.x ?? 0, pin.y ?? 0, pin.latitude ?? null, pin.longitude ?? null, pin.description || '']);
      results.push(rows[0]);
    }

    res.status(201).json(results);
  } catch (err) {
    console.error('Error bulk creating pins:', err);
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/admin/pins/:id — update an existing pin (e.g. drag to new location)
router.put('/pins/:id', requireChildEventAccess(lookupPinEvent), async (req, res) => {
  try {
    const { label, pinType, x, y, latitude, longitude, description } = req.body;
    const { rows } = await pool.query(`
      UPDATE map_pins SET
        label = COALESCE($2, label),
        pin_type = COALESCE($3, pin_type),
        x = COALESCE($4, x),
        y = COALESCE($5, y),
        latitude = $6,
        longitude = $7,
        description = COALESCE($8, description)
      WHERE id = $1
      RETURNING *
    `, [req.params.id, label, pinType, x, y, latitude ?? null, longitude ?? null, description]);
    if (rows.length === 0) return res.status(404).json({ error: 'Pin not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error('Error updating map pin:', err);
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/admin/pins/:id
router.delete('/pins/:id', requireChildEventAccess(lookupPinEvent), async (req, res) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM map_pins WHERE id = $1', [req.params.id]);
    if (rowCount === 0) return res.status(404).json({ error: 'Pin not found' });
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================
// PUSH NOTIFICATIONS
// =====================

const { sendPushToEvent, sendPushToScheduleItem } = require('../services/apns');

// GET /api/admin/events/:eventId/devices/count — how many devices are subscribed
router.get('/events/:eventId/devices/count', requireEventAccess, async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT COUNT(*) FROM device_tokens WHERE event_id = $1',
      [req.params.eventId]
    );
    res.json({ count: parseInt(rows[0].count, 10) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/events/:eventId/push — send a push notification
router.post('/events/:eventId/push', requireEventAccess, async (req, res) => {
  try {
    const { title, body, category } = req.body;
    if (!title || !body) {
      return res.status(400).json({ error: 'title and body are required' });
    }

    // Look up event name to prefix the notification
    const eventResult = await pool.query('SELECT name FROM events WHERE id = $1', [req.params.eventId]);
    const eventName = eventResult.rows[0]?.name || 'Event';
    const pushTitle = `${eventName}: ${title}`;

    const result = await sendPushToEvent(req.params.eventId, pushTitle, body);

    // Record original title in history (without event name prefix)
    const { rows } = await pool.query(
      `INSERT INTO push_notifications (event_id, title, body, sent_count, failed_count)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [req.params.eventId, title, body, result.sent, result.failed]
    );

    res.json({ notification: rows[0], ...result });
  } catch (err) {
    console.error('Error sending push:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/schedule/:id/push — send notification to users who saved this item
router.post('/schedule/:id/push', requireChildEventAccess(lookupScheduleEvent), async (req, res) => {
  try {
    const { title, body } = req.body;
    if (!title || !body) {
      return res.status(400).json({ error: 'title and body are required' });
    }

    // Look up schedule item and its event for context
    const itemResult = await pool.query(
      `SELECT si.title as item_title, si.event_id, e.name as event_name
       FROM schedule_items si JOIN events e ON e.id = si.event_id
       WHERE si.id = $1`,
      [req.params.id]
    );
    if (itemResult.rows.length === 0) {
      return res.status(404).json({ error: 'Schedule item not found' });
    }

    const { event_name, event_id } = itemResult.rows[0];
    const fullTitle = `${event_name}: ${title}`;

    const result = await sendPushToScheduleItem(req.params.id, fullTitle, body);

    // Also record in push_notifications for history
    await pool.query(
      `INSERT INTO push_notifications (event_id, title, body, sent_count, failed_count)
       VALUES ($1, $2, $3, $4, $5)`,
      [event_id, fullTitle, body, result.sent, result.failed]
    );

    // Get subscriber count for this item
    const countResult = await pool.query(
      'SELECT COUNT(*) FROM device_saved_items WHERE schedule_item_id = $1',
      [req.params.id]
    );

    res.json({ ...result, subscribers: parseInt(countResult.rows[0].count, 10) });
  } catch (err) {
    console.error('Error sending item push:', err);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/admin/events/:eventId/push — notification history (paginated)
router.get('/events/:eventId/push', requireEventAccess, async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 10, 50);
    const offset = parseInt(req.query.offset) || 0;

    const [{ rows }, countResult] = await Promise.all([
      pool.query(
        `SELECT * FROM push_notifications
         WHERE event_id = $1
         ORDER BY created_at DESC
         LIMIT $2 OFFSET $3`,
        [req.params.eventId, limit, offset]
      ),
      pool.query(
        'SELECT COUNT(*) FROM push_notifications WHERE event_id = $1',
        [req.params.eventId]
      )
    ]);

    res.json({
      notifications: rows,
      total: parseInt(countResult.rows[0].count, 10)
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/admin/events/:eventId/push — clear notification history
router.delete('/events/:eventId/push', requireEventAccess, async (req, res) => {
  try {
    const { rowCount } = await pool.query(
      'DELETE FROM push_notifications WHERE event_id = $1',
      [req.params.eventId]
    );
    res.json({ deleted: rowCount });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================
// LLM SCHEDULE PARSING
// =====================

// POST /api/admin/parse-schedule — parse raw text into structured schedule items
router.post('/parse-schedule', requireSuperadmin, async (req, res) => {
  try {
    const { text, eventName, stages } = req.body;

    if (!text) {
      return res.status(400).json({ error: 'No text provided' });
    }

    if (!process.env.ANTHROPIC_API_KEY) {
      return res.status(500).json({ error: 'ANTHROPIC_API_KEY not configured on server' });
    }

    const client = new Anthropic();

    const stageList = (stages || []).map(s => s.name).join(', ');
    const stageInstruction = stageList
      ? `Available stages: ${stageList}. Match each item to the most appropriate stage name, or leave stageName empty if unclear.`
      : 'No stages are defined yet. Set stageName to whatever stage/location is mentioned, or leave empty.';

    const message = await client.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 4096,
      messages: [{
        role: 'user',
        content: `Extract schedule items from the following text for the event "${eventName || 'Unknown Event'}".

${stageInstruction}

Return a JSON array of objects with these fields:
- title (string, required): the session/performance name
- description (string): brief description if available
- startTime (string): ISO 8601 datetime, use the current year if not specified
- endTime (string): ISO 8601 datetime, estimate 1 hour duration if end time not given
- stageName (string): the stage or location name if mentioned
- category (string): one of Music, Comedy, Art, Film, Food, Panel, Workshop, Dance, Community, Performance, or General

Return ONLY the JSON array, no other text. If you can't parse anything, return an empty array [].

Text to parse:
${text}`
      }]
    });

    const content = message.content[0].text.trim();

    // Extract JSON from response (handle markdown code blocks)
    let jsonStr = content;
    const codeBlockMatch = content.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (codeBlockMatch) {
      jsonStr = codeBlockMatch[1].trim();
    }

    const items = JSON.parse(jsonStr);

    // Map stage names to stage IDs if stages were provided
    if (stages && stages.length > 0) {
      for (const item of items) {
        if (item.stageName) {
          const match = stages.find(s =>
            s.name.toLowerCase().includes(item.stageName.toLowerCase()) ||
            item.stageName.toLowerCase().includes(s.name.toLowerCase())
          );
          if (match) {
            item.stageId = match.id;
          }
        }
      }
    }

    res.json(items);
  } catch (err) {
    console.error('Error parsing schedule:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/import-url — scrape a URL and parse schedule from it
router.post('/import-url', requireSuperadmin, async (req, res) => {
  try {
    const { url, eventName, stages } = req.body;

    if (!url) {
      return res.status(400).json({ error: 'No URL provided' });
    }

    if (!process.env.ANTHROPIC_API_KEY) {
      return res.status(500).json({ error: 'ANTHROPIC_API_KEY not configured on server' });
    }

    // Fetch the page
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; CanopyBot/1.0)',
        'Accept': 'text/html,application/xhtml+xml'
      }
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch URL: HTTP ${response.status}`);
    }

    const html = await response.text();

    // Extract text content using cheerio
    const $ = cheerio.load(html);

    // Remove scripts, styles, nav, footer, etc.
    $('script, style, nav, footer, header, iframe, noscript, svg').remove();

    // Get the page title
    const pageTitle = $('title').text().trim();

    // Extract text from the main content area
    const text = $('body').text()
      .replace(/\s+/g, ' ')       // collapse whitespace
      .replace(/\n{3,}/g, '\n\n') // collapse blank lines
      .trim()
      .slice(0, 15000);           // limit to ~15k chars for the API

    if (text.length < 50) {
      return res.status(400).json({ error: 'Could not extract meaningful text from the page' });
    }

    // Send to Claude for parsing
    const client = new Anthropic();

    const stageList = (stages || []).map(s => s.name).join(', ');
    const stageInstruction = stageList
      ? `Available stages: ${stageList}. Match each item to the most appropriate stage name, or leave stageName empty if unclear.`
      : 'No stages are defined yet. Set stageName to whatever stage/location is mentioned, or leave empty.';

    const message = await client.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 4096,
      messages: [{
        role: 'user',
        content: `Extract schedule/lineup items from the following web page content for the event "${eventName || pageTitle || 'Unknown Event'}".

${stageInstruction}

Return a JSON array of objects with these fields:
- title (string, required): the session/performance/act name
- description (string): brief description if available
- startTime (string): ISO 8601 datetime. Use 2026 as the year if not specified. If only a date is given with no time, use 12:00 PM.
- endTime (string): ISO 8601 datetime. Estimate 1 hour duration if end time not given.
- stageName (string): the stage, venue, or location name if mentioned
- category (string): one of Music, Comedy, Art, Film, Food, Panel, Workshop, Dance, Community, Performance, or General

Return ONLY the JSON array, no other text. If you can't find schedule items, return an empty array [].
Focus on individual performances, sessions, or lineup items — not general event info.

Page title: ${pageTitle}
Page content:
${text}`
      }]
    });

    const content = message.content[0].text.trim();

    let jsonStr = content;
    const codeBlockMatch = content.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (codeBlockMatch) {
      jsonStr = codeBlockMatch[1].trim();
    }

    const items = JSON.parse(jsonStr);

    // Map stage names to IDs
    if (stages && stages.length > 0) {
      for (const item of items) {
        if (item.stageName) {
          const match = stages.find(s =>
            s.name.toLowerCase().includes(item.stageName.toLowerCase()) ||
            item.stageName.toLowerCase().includes(s.name.toLowerCase())
          );
          if (match) {
            item.stageId = match.id;
          }
        }
      }
    }

    res.json({ items, pageTitle, textLength: text.length });
  } catch (err) {
    console.error('Error importing from URL:', err);
    res.status(500).json({ error: err.message });
  }
});

// =====================
// DATABASE EXPORT / IMPORT
// =====================

// GET /api/admin/export — full JSON dump of all data
router.get('/export', requireSuperadmin, async (req, res) => {
  try {
    const [events, stages, scheduleItems, mapPins, pushNotifications, deviceTokens] = await Promise.all([
      pool.query('SELECT * FROM events ORDER BY start_date'),
      pool.query('SELECT * FROM stages ORDER BY event_id, name'),
      pool.query('SELECT * FROM schedule_items ORDER BY event_id, start_time'),
      pool.query('SELECT * FROM map_pins ORDER BY event_id, label'),
      pool.query('SELECT * FROM push_notifications ORDER BY created_at DESC LIMIT 100'),
      pool.query('SELECT COUNT(*) as count FROM device_tokens'),
    ]);

    const backup = {
      exportedAt: new Date().toISOString(),
      counts: {
        events: events.rows.length,
        stages: stages.rows.length,
        scheduleItems: scheduleItems.rows.length,
        mapPins: mapPins.rows.length,
        pushNotifications: pushNotifications.rows.length,
        deviceTokens: parseInt(deviceTokens.rows[0].count),
      },
      events: events.rows,
      stages: stages.rows,
      scheduleItems: scheduleItems.rows,
      mapPins: mapPins.rows,
      pushNotifications: pushNotifications.rows,
    };

    res.setHeader('Content-Disposition', `attachment; filename=canopy-backup-${new Date().toISOString().slice(0,10)}.json`);
    res.json(backup);
  } catch (err) {
    console.error('Export error:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/import — restore from a JSON backup
router.post('/import', requireSuperadmin, async (req, res) => {
  try {
    const { events, stages, scheduleItems, mapPins } = req.body;

    if (!events || !Array.isArray(events)) {
      return res.status(400).json({ error: 'Invalid backup format — expected events array' });
    }

    let imported = { events: 0, stages: 0, scheduleItems: 0, mapPins: 0 };

    for (const e of events) {
      try {
        await pool.query(`
          INSERT INTO events (id, name, slug, description, start_date, end_date, location, neighborhood,
            logo_system_image, image_url, map_image_url, map_calibration, map_pin_size, ticketing_url,
            latitude, longitude, category, is_active, created_at, updated_at)
          VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20)
          ON CONFLICT (slug) DO NOTHING
        `, [e.id, e.name, e.slug, e.description, e.start_date, e.end_date, e.location, e.neighborhood,
            e.logo_system_image, e.image_url, e.map_image_url, e.map_calibration, e.map_pin_size, e.ticketing_url,
            e.latitude, e.longitude, e.category, e.is_active, e.created_at, e.updated_at]);
        imported.events++;
      } catch(err) { /* skip duplicates */ }
    }

    for (const s of (stages || [])) {
      try {
        await pool.query(`
          INSERT INTO stages (id, event_id, name, map_x, map_y, created_at)
          VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING
        `, [s.id, s.event_id, s.name, s.map_x, s.map_y, s.created_at]);
        imported.stages++;
      } catch(err) {}
    }

    for (const si of (scheduleItems || [])) {
      try {
        await pool.query(`
          INSERT INTO schedule_items (id, event_id, stage_id, title, description, start_time, end_time,
            category, is_cancelled, performer_name, performer_bio, performer_image_url, performer_links,
            created_at, updated_at)
          VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15) ON CONFLICT DO NOTHING
        `, [si.id, si.event_id, si.stage_id, si.title, si.description, si.start_time, si.end_time,
            si.category, si.is_cancelled, si.performer_name, si.performer_bio, si.performer_image_url,
            si.performer_links, si.created_at, si.updated_at]);
        imported.scheduleItems++;
      } catch(err) {}
    }

    for (const p of (mapPins || [])) {
      try {
        await pool.query(`
          INSERT INTO map_pins (id, event_id, label, pin_type, x, y, description, created_at)
          VALUES ($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT DO NOTHING
        `, [p.id, p.event_id, p.label, p.pin_type, p.x, p.y, p.description, p.created_at]);
        imported.mapPins++;
      } catch(err) {}
    }

    res.json({ message: 'Import complete', imported });
  } catch (err) {
    console.error('Import error:', err);
    res.status(500).json({ error: err.message });
  }
});

// =====================
// TEMPLATE MATCHING
// =====================

// POST /api/admin/match-template — find all instances of a selected icon region in the map
router.post('/match-template', requireSuperadmin, async (req, res) => {
  try {
    const { mapImageURL, template, threshold = 0.55 } = req.body;

    if (!mapImageURL || !template) {
      return res.status(400).json({ error: 'mapImageURL and template region required' });
    }

    const sharp = require('sharp');

    // Fetch the map image
    const imgResponse = await fetch(mapImageURL);
    if (!imgResponse.ok) throw new Error(`Failed to fetch image: ${imgResponse.status}`);
    const imgBuffer = Buffer.from(await imgResponse.arrayBuffer());

    // Scale image down for processing speed
    const maxScanWidth = 1200;
    const origMeta = await sharp(imgBuffer).metadata();
    const scale = Math.min(1, maxScanWidth / origMeta.width);
    const scanWidth = Math.round(origMeta.width * scale);
    const scanHeight = Math.round(origMeta.height * scale);

    const scanBuffer = await sharp(imgBuffer)
      .resize(scanWidth, scanHeight)
      .removeAlpha()
      .raw()
      .toBuffer();

    // Extract template region at scan resolution
    const tLeft = Math.max(Math.round(template.x * scanWidth), 0);
    const tTop = Math.max(Math.round(template.y * scanHeight), 0);
    const tW = Math.max(Math.round(template.w * scanWidth), 1);
    const tH = Math.max(Math.round(template.h * scanHeight), 1);

    console.log(`[Template] Scan: ${scanWidth}x${scanHeight}, template: ${tW}x${tH} at (${tLeft},${tTop})`);

    // NCC matching at a given scale
    function matchAtScale(scanBuf, sW, sH, tw, th, origX, origY) {
      // Sample template pixels from scan buffer at target scale
      const tPixels = [];
      for (let ty = 0; ty < th; ty++) {
        for (let tx = 0; tx < tw; tx++) {
          const srcY = Math.min(Math.round(tTop + ty * (tH / th)), sH - 1);
          const srcX = Math.min(Math.round(tLeft + tx * (tW / tw)), sW - 1);
          const si = (srcY * sW + srcX) * 3;
          tPixels.push(scanBuf[si] || 0, scanBuf[si+1] || 0, scanBuf[si+2] || 0);
        }
      }

      const tLen = tw * th;
      let tMeanR = 0, tMeanG = 0, tMeanB = 0;
      for (let i = 0; i < tLen; i++) {
        tMeanR += tPixels[i*3]; tMeanG += tPixels[i*3+1]; tMeanB += tPixels[i*3+2];
      }
      tMeanR /= tLen; tMeanG /= tLen; tMeanB /= tLen;

      let tDenom = 0;
      for (let i = 0; i < tLen; i++) {
        const dr = tPixels[i*3] - tMeanR;
        const dg = tPixels[i*3+1] - tMeanG;
        const db = tPixels[i*3+2] - tMeanB;
        tDenom += dr*dr + dg*dg + db*db;
      }
      tDenom = Math.sqrt(tDenom);
      if (tDenom < 1) return [];

      const step = Math.max(Math.round(Math.min(tw, th) * 0.25), 1);
      const results = [];

      for (let sy = 0; sy <= sH - th; sy += step) {
        for (let sx = 0; sx <= sW - tw; sx += step) {
          if (Math.abs(sx - origX) < tw && Math.abs(sy - origY) < th) continue;

          let wMeanR = 0, wMeanG = 0, wMeanB = 0;
          for (let ty = 0; ty < th; ty++) {
            for (let tx = 0; tx < tw; tx++) {
              const si = ((sy + ty) * sW + (sx + tx)) * 3;
              wMeanR += scanBuf[si]; wMeanG += scanBuf[si+1]; wMeanB += scanBuf[si+2];
            }
          }
          wMeanR /= tLen; wMeanG /= tLen; wMeanB /= tLen;

          let num = 0, wDenom = 0;
          for (let ty = 0; ty < th; ty++) {
            for (let tx = 0; tx < tw; tx++) {
              const si = ((sy + ty) * sW + (sx + tx)) * 3;
              const ti = (ty * tw + tx) * 3;
              const dr = scanBuf[si] - wMeanR;
              const dg = scanBuf[si+1] - wMeanG;
              const db = scanBuf[si+2] - wMeanB;
              const tr = tPixels[ti] - tMeanR;
              const tg = tPixels[ti+1] - tMeanG;
              const tb = tPixels[ti+2] - tMeanB;
              num += dr*tr + dg*tg + db*tb;
              wDenom += dr*dr + dg*dg + db*db;
            }
          }
          wDenom = Math.sqrt(wDenom);
          if (wDenom < 1) continue;

          const ncc = num / (tDenom * wDenom);
          if (ncc >= threshold) {
            results.push({
              x: (sx + tw/2) / sW,
              y: (sy + th/2) / sH,
              similarity: Math.round(ncc * 100) / 100
            });
          }
        }
      }
      return results;
    }

    // Match at multiple scales
    const scales = [1.0, 0.8, 1.2, 0.6, 1.4];
    let allMatches = [];

    for (const s of scales) {
      const tw = Math.max(Math.round(tW * s), 1);
      const th = Math.max(Math.round(tH * s), 1);
      if (tw > scanWidth / 2 || th > scanHeight / 2) continue;
      console.log(`[Template] Matching at scale ${s}: ${tw}x${th}`);
      const results = matchAtScale(scanBuffer, scanWidth, scanHeight, tw, th, tLeft, tTop);
      allMatches.push(...results);
    }

    // Deduplicate across scales
    const minDist = Math.max(tW, tH) / scanWidth * 0.8;
    const matches = [];
    allMatches.sort((a, b) => b.similarity - a.similarity);
    for (const m of allMatches) {
      const tooClose = matches.some(existing =>
        Math.abs(existing.x - m.x) < minDist && Math.abs(existing.y - m.y) < minDist
      );
      if (!tooClose) matches.push(m);
    }

    matches.sort((a, b) => b.similarity - a.similarity);

    console.log(`[Template] Found ${matches.length} matches across ${scales.length} scales (threshold: ${threshold})`);
    res.json({ matches, count: matches.length });
  } catch (err) {
    console.error('Error matching template:', err);
    res.status(500).json({ error: err.message });
  }
});

// =====================
// AI MAP PIN DETECTION
// =====================

// POST /api/admin/detect-map-pins — use Claude Vision to detect pins/landmarks on a map image
router.post('/detect-map-pins', requireSuperadmin, async (req, res) => {
  try {
    const { mapImageURL, eventName } = req.body;

    if (!mapImageURL) {
      return res.status(400).json({ error: 'mapImageURL is required' });
    }

    if (!process.env.ANTHROPIC_API_KEY) {
      return res.status(500).json({ error: 'ANTHROPIC_API_KEY not configured on server' });
    }

    // Fetch the image and convert to base64
    const imgResponse = await fetch(mapImageURL);
    if (!imgResponse.ok) {
      throw new Error(`Failed to fetch map image: HTTP ${imgResponse.status}`);
    }

    const imgBuffer = Buffer.from(await imgResponse.arrayBuffer());
    let sizeKB = Math.round(imgBuffer.length / 1024);
    console.log(`[AI Map] Image fetched: ${sizeKB}KB`);

    // Resize if over 4MB to stay under the 5MB base64 limit
    let finalBuffer = imgBuffer;
    let mediaType = 'image/jpeg'; // always send as JPEG for smaller size

    const sharp = require('sharp');
    const metadata = await sharp(imgBuffer).metadata();
    console.log(`[AI Map] Image dimensions: ${metadata.width}x${metadata.height}`);

    // Scale down to max 2000px wide and convert to JPEG
    finalBuffer = await sharp(imgBuffer)
      .resize({ width: Math.min(metadata.width, 2000), withoutEnlargement: true })
      .jpeg({ quality: 80 })
      .toBuffer();

    const base64 = finalBuffer.toString('base64');
    sizeKB = Math.round(base64.length / 1024);
    console.log(`[AI Map] Resized to ${sizeKB}KB base64, sending as ${mediaType}`);

    const client = new Anthropic();

    console.log('[AI Map] Sending to Claude Vision...');
    const message = await client.messages.create({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 4096,
      messages: [{
        role: 'user',
        content: [
          {
            type: 'image',
            source: {
              type: 'base64',
              media_type: mediaType,
              data: base64,
            }
          },
          {
            type: 'text',
            text: `This is a venue map image${eventName ? ` for "${eventName}"` : ''}. I need you to find the EXACT positions of icons and symbols drawn on this map.

Look carefully at the map for these specific visual symbols/icons:
- Fork and knife icons, food/dining symbols → pinType: "Food"
- Restroom/bathroom/toilet icons (person figures, WC signs) → pinType: "Restroom"
- Medical cross, first aid symbols → pinType: "First Aid"
- Arrow signs, gate markers, entrance/exit signs → pinType: "Exit"
- Stage icons, music notes, performance area markers → pinType: "Stage"
- Any other labeled icons, numbered markers, or symbols → pinType: "Custom"

Also identify labeled buildings, venues, and landmarks that have text labels on the map.

For EACH icon or labeled location, return:
- label: the text label nearest to it, or a descriptive name (e.g. "Food Service", "Restrooms")
- pinType: one of "Stage", "Food", "Restroom", "First Aid", "Exit", or "Custom"
- x: the EXACT horizontal position of the CENTER of the icon/symbol, as a decimal from 0.0 (left edge of image) to 1.0 (right edge of image)
- y: the EXACT vertical position of the CENTER of the icon/symbol, as a decimal from 0.0 (top edge of image) to 1.0 (bottom edge of image)
- description: what this location is

CRITICAL: The x,y coordinates must point to the EXACT CENTER of each icon as drawn on the map. Be extremely precise — measure carefully relative to the full image dimensions. Do not guess approximate locations; find the actual drawn symbols and icons.

Return ONLY a JSON array. If no icons found, return [].`
          }
        ]
      }]
    });

    const content = message.content[0].text.trim();

    // Extract JSON
    let jsonStr = content;
    const codeBlockMatch = content.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (codeBlockMatch) {
      jsonStr = codeBlockMatch[1].trim();
    }

    const pins = JSON.parse(jsonStr);
    res.json({ pins, count: pins.length });
  } catch (err) {
    console.error('Error detecting map pins:', err);
    res.status(500).json({ error: err.message });
  }
});

// =====================
// SEATTLE OPEN DATA IMPORT
// =====================

// POST /api/admin/backfill-images — search Ticketmaster for images for events missing them
router.post('/backfill-images', requireSuperadmin, async (req, res) => {
  try {
    const apiKey = process.env.TICKETMASTER_API_KEY;
    if (!apiKey) return res.status(500).json({ error: 'Ticketmaster API key not configured' });

    const city = req.body.city || null;
    const query = city
      ? `SELECT id, name, location FROM events WHERE (image_url IS NULL OR image_url = '') AND city = $1`
      : `SELECT id, name, location FROM events WHERE image_url IS NULL OR image_url = ''`;
    const params = city ? [city] : [];
    const { rows: events } = await pool.query(query, params);

    console.log(`[Backfill] Found ${events.length} events without images${city ? ` (city: ${city})` : ''}`);

    let updated = 0;
    let skipped = 0;

    for (const event of events) {
      try {
        const searchParams = new URLSearchParams({
          apikey: apiKey,
          keyword: event.name,
          size: '1',
        });
        const tmRes = await fetch(`https://app.ticketmaster.com/discovery/v2/events.json?${searchParams}`);
        if (!tmRes.ok) { skipped++; continue; }

        const tmData = await tmRes.json();
        const tmEvent = tmData?._embedded?.events?.[0];
        if (!tmEvent) { skipped++; continue; }

        // Find best image (prefer 16_9 ratio, largest)
        const images = tmEvent.images || [];
        const best = images
          .filter(img => img.ratio === '16_9')
          .sort((a, b) => (b.width || 0) - (a.width || 0))[0]
          || images[0];

        if (!best?.url) { skipped++; continue; }

        await pool.query('UPDATE events SET image_url = $1 WHERE id = $2', [best.url, event.id]);
        updated++;
        console.log(`[Backfill] ${event.name} → ${best.url.substring(0, 60)}...`);

        // Rate limit: Ticketmaster allows ~5 req/sec
        await new Promise(r => setTimeout(r, 250));
      } catch (err) {
        console.error(`[Backfill] Error for ${event.name}:`, err.message);
        skipped++;
      }
    }

    res.json({ total: events.length, updated, skipped });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/import-seattle-events — import from Seattle Special Events Permits
router.post('/import-seattle-events', requireSuperadmin, async (req, res) => {
  try {
    const { minAttendance = 0, year = new Date().getFullYear() } = req.body;

    // Fetch permitted events from Seattle Open Data
    const attendanceFilter = minAttendance > 0 ? ` AND attendance>${minAttendance}` : '';
    const soqlUrl = `https://data.seattle.gov/resource/dm95-f8w5.json?$limit=500&$where=event_start_date>'${year}-01-01' AND permit_status!='Cancelled'${attendanceFilter}&$order=event_start_date`;

    console.log(`[Seattle Data] Fetching: ${soqlUrl}`);
    const response = await fetch(soqlUrl);
    if (!response.ok) throw new Error(`Seattle API error: ${response.status}`);

    const events = await response.json();
    console.log(`[Seattle Data] Got ${events.length} events with attendance > ${minAttendance}`);

    let imported = 0;
    let skipped = 0;

    for (const e of events) {
      const name = e.name_of_event;
      if (!name || !e.event_start_date) { skipped++; continue; }

      // Generate slug
      const slug = `seattle-${name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/-+/g, '-').slice(0, 50)}-${year}`;

      // Check for duplicates
      const existing = await pool.query('SELECT id FROM events WHERE slug = $1', [slug]);
      if (existing.rows.length > 0) { skipped++; continue; }

      // Map category
      let category = 'community';
      const cat = (e.event_category || '').toLowerCase();
      const subCat = (e.event_sub_category || '').toLowerCase();
      if (cat === 'athletic' || subCat.includes('run') || subCat.includes('cycling')) category = 'community';
      if (cat === 'commercial') category = 'fair';
      if (subCat.includes('music') || subCat.includes('concert')) category = 'concert';
      if (subCat.includes('festival')) category = 'festival';

      const startDate = e.event_start_date;
      const endDate = e.event_end_date || e.event_start_date;
      const neighborhood = e.neighborhood_s || '';
      const location = e.park_name || neighborhood || 'Seattle';
      const attendance = parseInt(e.attendance) || 0;

      const description = [
        e.event_category ? `${e.event_category} event` : '',
        e.event_sub_category ? `(${e.event_sub_category})` : '',
        attendance ? `Expected attendance: ${attendance.toLocaleString()}` : '',
        e.organization ? `Organized by ${e.organization}` : '',
      ].filter(Boolean).join('. ');

      const { rows } = await pool.query(`
        INSERT INTO events (name, slug, description, start_date, end_date, location, neighborhood, category, is_active)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true)
        RETURNING id, name
      `, [name, slug, description, startDate, endDate, location, neighborhood, category]);

      if (rows.length > 0) {
        imported++;
        console.log(`[Seattle Data] Imported: ${rows[0].name}`);
      }
    }

    res.json({
      total: events.length,
      imported,
      skipped,
      message: `Imported ${imported} events, skipped ${skipped} (duplicates or incomplete)`
    });
  } catch (err) {
    console.error('Error importing Seattle events:', err);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/admin/seattle-events-preview — preview what would be imported
router.get('/seattle-events-preview', requireSuperadmin, async (req, res) => {
  try {
    const minAttendance = parseInt(req.query.minAttendance) || 0;
    const year = parseInt(req.query.year) || new Date().getFullYear();

    const attendanceFilter = minAttendance > 0 ? ` AND attendance>${minAttendance}` : '';
    const soqlUrl = `https://data.seattle.gov/resource/dm95-f8w5.json?$limit=500&$where=event_start_date>'${year}-01-01' AND permit_status!='Cancelled'${attendanceFilter}&$order=event_start_date`;

    const response = await fetch(soqlUrl);
    if (!response.ok) throw new Error(`Seattle API error: ${response.status}`);

    const events = await response.json();

    // Check which ones already exist
    const previews = [];
    for (const e of events) {
      const name = e.name_of_event;
      if (!name || !e.event_start_date) continue;

      const slug = `seattle-${name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/-+/g, '-').slice(0, 50)}-${year}`;
      const existing = await pool.query('SELECT id FROM events WHERE slug = $1', [slug]);

      previews.push({
        name,
        startDate: e.event_start_date,
        endDate: e.event_end_date,
        category: e.event_category,
        subCategory: e.event_sub_category,
        neighborhood: e.neighborhood_s,
        location: e.park_name,
        attendance: parseInt(e.attendance) || 0,
        status: e.permit_status,
        alreadyImported: existing.rows.length > 0,
      });
    }

    res.json({ events: previews, total: previews.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================
// ANALYTICS
// =====================

// Per-event analytics
router.get('/analytics/event/:eventId', requireEventAccess, async (req, res) => {
  const { eventId } = req.params;
  try {
    const [devices, saves, uniqueSavers, timeline, pushStats] = await Promise.all([
      pool.query('SELECT COUNT(*)::int as count FROM device_tokens WHERE event_id = $1', [eventId]),
      pool.query(`SELECT COUNT(*)::int as count FROM device_saved_items dsi
        JOIN schedule_items si ON si.id = dsi.schedule_item_id WHERE si.event_id = $1`, [eventId]),
      pool.query(`SELECT COUNT(DISTINCT dsi.device_token)::int as count FROM device_saved_items dsi
        JOIN schedule_items si ON si.id = dsi.schedule_item_id WHERE si.event_id = $1`, [eventId]),
      pool.query(`SELECT DATE(created_at) as date, COUNT(*)::int as count
        FROM device_tokens WHERE event_id = $1
        GROUP BY DATE(created_at) ORDER BY date`, [eventId]),
      pool.query(`SELECT COUNT(*)::int as total_sent, COALESCE(SUM(sent_count),0)::int as delivered,
        COALESCE(SUM(failed_count),0)::int as failed
        FROM push_notifications WHERE event_id = $1`, [eventId]),
    ]);
    res.json({
      eventId,
      deviceCount: devices.rows[0].count,
      totalSaves: saves.rows[0].count,
      uniqueSavers: uniqueSavers.rows[0].count,
      registrationsByDay: timeline.rows,
      pushStats: pushStats.rows[0],
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Per-event session popularity
router.get('/analytics/event/:eventId/sessions', requireEventAccess, async (req, res) => {
  const { eventId } = req.params;
  try {
    const result = await pool.query(`
      SELECT si.id, si.title, si.start_time, si.end_time, si.category,
             s.name as stage_name, COUNT(dsi.id)::int as save_count
      FROM schedule_items si
      LEFT JOIN device_saved_items dsi ON dsi.schedule_item_id = si.id
      LEFT JOIN stages s ON s.id = si.stage_id
      WHERE si.event_id = $1
      GROUP BY si.id, si.title, si.start_time, si.end_time, si.category, s.name
      ORDER BY save_count DESC`, [eventId]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Cross-event overview analytics
router.get('/analytics/overview', requireSuperadmin, async (req, res) => {
  try {
    const [byNeighborhood, byCategory, freeVsTicketed, accessibility, platformStats] = await Promise.all([
      pool.query(`SELECT neighborhood, COUNT(*)::int as count FROM events
        WHERE neighborhood IS NOT NULL AND neighborhood != ''
        GROUP BY neighborhood ORDER BY count DESC`),
      pool.query(`SELECT category, COUNT(*)::int as count FROM events
        GROUP BY category ORDER BY count DESC`),
      pool.query(`SELECT
        COUNT(*) FILTER (WHERE is_free = true)::int as free_count,
        COUNT(*) FILTER (WHERE is_free = false OR is_free IS NULL)::int as ticketed_count
        FROM events`),
      pool.query(`SELECT
        COUNT(*) FILTER (WHERE is_accessible = true)::int as accessible_count,
        COUNT(*)::int as total FROM events`),
      pool.query(`SELECT COUNT(DISTINCT device_token)::int as unique_devices,
        COUNT(*)::int as total_subscriptions FROM device_tokens`),
    ]);
    res.json({
      byNeighborhood: byNeighborhood.rows,
      byCategory: byCategory.rows,
      freeVsTicketed: freeVsTicketed.rows[0],
      accessibility: accessibility.rows[0],
      platformStats: platformStats.rows[0],
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// CSV/JSON export
router.get('/analytics/export', requireSuperadmin, async (req, res) => {
  const { type = 'events', format = 'csv' } = req.query;
  try {
    let result;
    if (type === 'venues') {
      result = await pool.query(`SELECT * FROM venues ORDER BY name ASC`);
    } else if (type === 'sessions') {
      result = await pool.query(`
        SELECT e.name as event_name, si.title, si.category, si.start_time, si.end_time,
               s.name as stage_name, COUNT(dsi.id)::int as save_count
        FROM schedule_items si
        JOIN events e ON e.id = si.event_id
        LEFT JOIN stages s ON s.id = si.stage_id
        LEFT JOIN device_saved_items dsi ON dsi.schedule_item_id = si.id
        GROUP BY e.name, si.id, si.title, si.category, si.start_time, si.end_time, s.name
        ORDER BY save_count DESC`);
    } else {
      result = await pool.query(`
        SELECT e.name, e.slug, e.location, e.neighborhood, e.category,
               e.start_date, e.end_date, e.is_free, e.is_accessible,
               COUNT(DISTINCT dt.device_token)::int as device_count,
               COUNT(DISTINCT dsi.id)::int as total_saves
        FROM events e
        LEFT JOIN device_tokens dt ON dt.event_id = e.id
        LEFT JOIN schedule_items si ON si.event_id = e.id
        LEFT JOIN device_saved_items dsi ON dsi.schedule_item_id = si.id
        GROUP BY e.id ORDER BY e.start_date`);
    }

    if (format === 'json') {
      res.setHeader('Content-Disposition', `attachment; filename=canopy-${type}-${new Date().toISOString().slice(0,10)}.json`);
      return res.json(result.rows);
    }

    // CSV
    if (result.rows.length === 0) {
      res.setHeader('Content-Type', 'text/csv');
      return res.send('');
    }
    const columns = Object.keys(result.rows[0]);
    const escape = (val) => {
      if (val == null) return '';
      const s = String(val);
      if (s.includes(',') || s.includes('"') || s.includes('\n')) {
        return '"' + s.replace(/"/g, '""') + '"';
      }
      return s;
    };
    const csv = [columns.join(','), ...result.rows.map(r => columns.map(c => escape(r[c])).join(','))].join('\n');
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename=canopy-${type}-${new Date().toISOString().slice(0,10)}.csv`);
    res.send(csv);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Generate fake demo data
router.post('/analytics/generate-demo-data', requireSuperadmin, async (req, res) => {
  const { deviceCount = 200 } = req.body || {};
  try {
    const events = (await pool.query('SELECT id, start_date FROM events')).rows;
    const scheduleItems = (await pool.query('SELECT id, event_id FROM schedule_items')).rows;

    if (events.length === 0) return res.json({ devicesCreated: 0, savesCreated: 0 });

    const itemsByEvent = {};
    for (const si of scheduleItems) {
      if (!itemsByEvent[si.event_id]) itemsByEvent[si.event_id] = [];
      itemsByEvent[si.event_id].push(si.id);
    }

    let devicesCreated = 0;
    let savesCreated = 0;
    const rand = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
    const hex = () => Math.random().toString(16).slice(2, 10);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      for (let i = 0; i < deviceCount; i++) {
        const token = `demo-device-${hex()}${hex()}`;
        // Subscribe to 1-3 random events
        const numEvents = rand(1, Math.min(3, events.length));
        const shuffled = [...events].sort(() => Math.random() - 0.5).slice(0, numEvents);

        for (const event of shuffled) {
          // Spread registration over 14 days before event start
          const startDate = new Date(event.start_date);
          const daysBack = rand(1, 14);
          const createdAt = new Date(startDate.getTime() - daysBack * 86400000);

          const r = await client.query(
            `INSERT INTO device_tokens (device_token, event_id, created_at, updated_at)
             VALUES ($1, $2, $3, $3) ON CONFLICT DO NOTHING RETURNING id`,
            [token, event.id, createdAt]
          );
          if (r.rowCount > 0) devicesCreated++;

          // Save 1-8 random schedule items from this event
          const items = itemsByEvent[event.id] || [];
          if (items.length > 0) {
            const numSaves = rand(1, Math.min(8, items.length));
            const savedItems = [...items].sort(() => Math.random() - 0.5).slice(0, numSaves);
            for (const itemId of savedItems) {
              const saveDate = new Date(createdAt.getTime() + rand(0, daysBack) * 86400000);
              const sr = await client.query(
                `INSERT INTO device_saved_items (device_token, schedule_item_id, created_at)
                 VALUES ($1, $2, $3) ON CONFLICT DO NOTHING RETURNING id`,
                [token, itemId, saveDate]
              );
              if (sr.rowCount > 0) savesCreated++;
            }
          }
        }
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    res.json({ devicesCreated, savesCreated, deviceCount });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Clear demo data
router.delete('/analytics/demo-data', requireSuperadmin, async (req, res) => {
  try {
    const saved = await pool.query("DELETE FROM device_saved_items WHERE device_token LIKE 'demo-device-%'");
    const devices = await pool.query("DELETE FROM device_tokens WHERE device_token LIKE 'demo-device-%'");
    res.json({ devicesRemoved: devices.rowCount, savesRemoved: saved.rowCount });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================
// VENUE BOUNDARIES
// =====================

router.get('/venue-boundaries', async (req, res) => {
  try {
    const city = req.query.city || null;
    const query = city
      ? 'SELECT * FROM venue_boundaries WHERE city = $1 ORDER BY venue_name ASC'
      : 'SELECT * FROM venue_boundaries ORDER BY venue_name ASC';
    const params = city ? [city] : [];
    const { rows } = await pool.query(query, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/venue-boundaries', requireSuperadmin, async (req, res) => {
  try {
    const { venueName, coordinates, city } = req.body;
    if (!venueName || !coordinates) {
      return res.status(400).json({ error: 'venueName and coordinates are required' });
    }
    const { rows } = await pool.query(
      `INSERT INTO venue_boundaries (venue_name, coordinates, city)
       VALUES ($1, $2, $3) RETURNING *`,
      [venueName, JSON.stringify(coordinates), city || 'seattle']
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'A boundary for this venue already exists' });
    }
    res.status(500).json({ error: err.message });
  }
});

router.put('/venue-boundaries/:id', requireSuperadmin, async (req, res) => {
  try {
    const { venueName, coordinates, city } = req.body;
    const { rows } = await pool.query(
      `UPDATE venue_boundaries SET
         venue_name = COALESCE($2, venue_name),
         coordinates = COALESCE($3, coordinates),
         city = COALESCE($4, city),
         updated_at = NOW()
       WHERE id = $1 RETURNING *`,
      [req.params.id, venueName, coordinates ? JSON.stringify(coordinates) : null, city]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/venue-boundaries/:id', requireSuperadmin, async (req, res) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM venue_boundaries WHERE id = $1', [req.params.id]);
    if (rowCount === 0) return res.status(404).json({ error: 'Not found' });
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================
// VENUES
// =====================

// GET /api/admin/venues — list all venues, optionally filtered by city
router.get('/venues', async (req, res) => {
  try {
    const city = req.query.city || null;
    const query = city
      ? 'SELECT * FROM venues WHERE city = $1 ORDER BY name ASC'
      : 'SELECT * FROM venues ORDER BY name ASC';
    const params = city ? [city] : [];
    const { rows } = await pool.query(query, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/venues — create venue (superadmin only)
router.post('/venues', requireSuperadmin, async (req, res) => {
  try {
    const { name, address, latitude, longitude, city, boundaryCoordinates, website, capacity, isAccessible, aliases } = req.body;
    if (!name) {
      return res.status(400).json({ error: 'Venue name is required' });
    }
    const { rows } = await pool.query(`
      INSERT INTO venues (name, address, latitude, longitude, city, boundary_coordinates, website, capacity, is_accessible, aliases)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      RETURNING *
    `, [name, address || '', latitude || null, longitude || null, city || 'seattle',
        JSON.stringify(boundaryCoordinates || []), website || '', capacity || '', isAccessible || false,
        JSON.stringify(aliases || [])]);
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/admin/venues/:id — update venue (superadmin only)
router.put('/venues/:id', requireSuperadmin, async (req, res) => {
  try {
    const { name, address, latitude, longitude, city, boundaryCoordinates, website, capacity, isAccessible, aliases } = req.body;
    const { rows } = await pool.query(`
      UPDATE venues SET
        name = COALESCE($2, name),
        address = COALESCE($3, address),
        latitude = COALESCE($4, latitude),
        longitude = COALESCE($5, longitude),
        city = COALESCE($6, city),
        boundary_coordinates = COALESCE($7, boundary_coordinates),
        website = COALESCE($8, website),
        capacity = COALESCE($9, capacity),
        is_accessible = COALESCE($10, is_accessible),
        aliases = COALESCE($11, aliases),
        updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `, [req.params.id, name, address, latitude, longitude, city,
        boundaryCoordinates ? JSON.stringify(boundaryCoordinates) : null, website, capacity, isAccessible,
        aliases ? JSON.stringify(aliases) : null]);
    if (rows.length === 0) return res.status(404).json({ error: 'Venue not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/admin/venues/:id — delete venue (superadmin only)
router.delete('/venues/:id', requireSuperadmin, async (req, res) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM venues WHERE id = $1', [req.params.id]);
    if (rowCount === 0) return res.status(404).json({ error: 'Venue not found' });
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Geocode an address to lat/lng using Google Maps Geocoding API
router.post('/venues/geocode', requireSuperadmin, async (req, res) => {
  try {
    const { address } = req.body;
    if (!address) return res.status(400).json({ error: 'Address is required' });

    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    if (!apiKey) return res.status(500).json({ error: 'Google Maps API key not configured' });

    const encoded = encodeURIComponent(address);
    const response = await fetch(`https://maps.googleapis.com/maps/api/geocode/json?address=${encoded}&key=${apiKey}`);
    const data = await response.json();

    if (data.status !== 'OK' || !data.results?.length) {
      return res.status(404).json({ error: 'Address not found', status: data.status });
    }

    const result = data.results[0];
    const { lat, lng } = result.geometry.location;
    res.json({
      latitude: lat,
      longitude: lng,
      formattedAddress: result.formatted_address,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Seed venues from hardcoded VenueMapData
router.post('/venues/seed', requireSuperadmin, async (req, res) => {
  const seedVenues = [
    { name: 'Seattle Center', address: '305 Harrison St, Seattle, WA 98109', latitude: 47.6215, longitude: -122.3510, city: 'seattle' },
    { name: 'Climate Pledge Arena', address: '334 1st Ave N, Seattle, WA 98109', latitude: 47.6221, longitude: -122.3540, city: 'seattle' },
    { name: 'Washington State Convention Center', address: '705 Pike St, Seattle, WA 98101', latitude: 47.6117, longitude: -122.3316, city: 'seattle' },
    { name: 'T-Mobile Park', address: '1250 1st Ave S, Seattle, WA 98134', latitude: 47.5914, longitude: -122.3325, city: 'seattle' },
    { name: 'Lumen Field', address: '800 Occidental Ave S, Seattle, WA 98134', latitude: 47.5952, longitude: -122.3316, city: 'seattle' },
    { name: 'Paramount Theatre', address: '911 Pine St, Seattle, WA 98101', latitude: 47.6133, longitude: -122.3314, city: 'seattle' },
    { name: 'The Showbox', address: '1426 1st Ave, Seattle, WA 98101', latitude: 47.6087, longitude: -122.3404, city: 'seattle' },
    { name: 'Gas Works Park', address: '2101 N Northlake Way, Seattle, WA 98103', latitude: 47.6456, longitude: -122.3344, city: 'seattle' },
    { name: 'Volunteer Park', address: '1247 15th Ave E, Seattle, WA 98112', latitude: 47.6164, longitude: -122.3196, city: 'seattle' },
    { name: 'The Gorge Amphitheatre', address: '754 Silica Rd NW, George, WA 98848', latitude: 47.1028, longitude: -119.9962, city: 'seattle' },
    { name: 'Genesee Park', address: '4316 S Genesee St, Seattle, WA 98118', latitude: 47.5535, longitude: -122.2612, city: 'seattle' },
    { name: 'Capitol Hill Block Party', address: 'Pike/Pine Corridor, Capitol Hill, Seattle, WA', latitude: 47.6145, longitude: -122.3210, city: 'seattle' },
    { name: 'West Seattle Junction', address: 'California Ave SW & SW Alaska St, Seattle, WA 98116', latitude: 47.5605, longitude: -122.3868, city: 'seattle' },
    { name: 'Hing Hay Park', address: '423 Maynard Ave S, Seattle, WA 98104', latitude: 47.5984, longitude: -122.3232, city: 'seattle' },
    { name: 'Fremont', address: 'N 36th St & Fremont Ave N, Seattle, WA 98103', latitude: 47.6510, longitude: -122.3500, city: 'seattle' },
    { name: 'Judkins Park', address: '2150 S Norman St, Seattle, WA 98144', latitude: 47.5945, longitude: -122.3028, city: 'seattle' },
    { name: 'Ballard Avenue', address: 'Ballard Ave NW, Seattle, WA 98107', latitude: 47.6634, longitude: -122.3838, city: 'seattle' },
    { name: 'Tractor Tavern', address: '5213 Ballard Ave NW, Seattle, WA 98107', latitude: 47.6636, longitude: -122.3846, city: 'seattle' },
    { name: 'Chop Suey', address: '1325 E Madison St, Seattle, WA 98122', latitude: 47.6148, longitude: -122.3185, city: 'seattle' },
    { name: 'Neumos', address: '925 E Pike St, Seattle, WA 98122', latitude: 47.6140, longitude: -122.3197, city: 'seattle' },
  ];

  try {
    // Verify venues table exists
    try {
      const tableCheck = await pool.query("SELECT COUNT(*) FROM venues");
      console.log(`[Seed] Venues table exists, current count: ${tableCheck.rows[0].count}`);
    } catch (tableErr) {
      console.error('[Seed] Venues table does not exist:', tableErr.message);
      return res.status(500).json({ error: 'Venues table does not exist. Migration may not have run.' });
    }

    let created = 0;
    let skipped = 0;
    for (const v of seedVenues) {
      try {
        console.log(`[Seed] Inserting: ${v.name}`);
        await pool.query(
          `INSERT INTO venues (name, address, latitude, longitude, city)
           VALUES ($1, $2, $3, $4, $5)`,
          [v.name, v.address, v.latitude, v.longitude, v.city]
        );
        created++;
        console.log(`[Seed] Created: ${v.name}`);
      } catch (err) {
        console.error(`[Seed] Failed ${v.name}: ${err.message}`);
        skipped++;
      }
    }
    res.json({ created, skipped, total: seedVenues.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// =====================
// CLOUDINARY UPLOAD
// =====================

router.post('/cloudinary-signature', async (req, res) => {
  try {
    const secret = process.env.CLOUDINARY_API_SECRET;
    if (!secret) return res.status(500).json({ error: 'Cloudinary not configured' });

    const timestamp = Math.round(Date.now() / 1000);
    const folder = req.body.folder || 'canopy';
    const paramsToSign = { timestamp, folder, source: 'uw' };
    const signature = cloudinary.utils.api_sign_request(paramsToSign, secret);

    res.json({
      signature,
      timestamp,
      apiKey: process.env.CLOUDINARY_API_KEY,
      cloudName: process.env.CLOUDINARY_CLOUD_NAME,
      folder,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
