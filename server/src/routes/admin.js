const { Router } = require('express');
const Anthropic = require('@anthropic-ai/sdk');
const cheerio = require('cheerio');
const { pool } = require('../db/pool');

const router = Router();

// Simple API key auth middleware
function requireAuth(req, res, next) {
  const key = req.headers['x-admin-key'];
  if (!key || key !== process.env.ADMIN_API_KEY) {
    return res.status(401).json({ error: 'Invalid or missing admin API key' });
  }
  next();
}

router.use(requireAuth);

// =====================
// EVENTS
// =====================

// POST /api/admin/events
router.post('/events', async (req, res) => {
  try {
    const { name, slug, description, startDate, endDate, location, neighborhood,
            logoSystemImage, imageURL, mapImageURL, ticketingURL, latitude, longitude, category } = req.body;

    const { rows } = await pool.query(`
      INSERT INTO events (name, slug, description, start_date, end_date, location, neighborhood,
                          logo_system_image, image_url, map_image_url, ticketing_url, latitude, longitude, category)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
      RETURNING *
    `, [name, slug, description || '', startDate, endDate, location, neighborhood || '',
        logoSystemImage || 'party.popper', imageURL, mapImageURL || null, ticketingURL, latitude, longitude, category || 'community']);

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error creating event:', err);
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/admin/events/:id
router.put('/events/:id', async (req, res) => {
  try {
    const { name, description, startDate, endDate, location, neighborhood,
            logoSystemImage, imageURL, mapImageURL, mapCalibration, ticketingURL, latitude, longitude, category, isActive } = req.body;

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
        map_image_url = COALESCE($10, map_image_url),
        map_calibration = COALESCE($11, map_calibration),
        ticketing_url = COALESCE($12, ticketing_url),
        latitude = COALESCE($13, latitude),
        longitude = COALESCE($14, longitude),
        category = COALESCE($15, category),
        is_active = COALESCE($16, is_active),
        updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `, [req.params.id, name, description, startDate, endDate, location, neighborhood,
        logoSystemImage, imageURL, mapImageURL, mapCalibration, ticketingURL, latitude, longitude, category, isActive]);

    if (rows.length === 0) return res.status(404).json({ error: 'Event not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error('Error updating event:', err);
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/admin/events/:id
router.delete('/events/:id', async (req, res) => {
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
router.post('/events/:eventId/stages', async (req, res) => {
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
router.delete('/stages/:id', async (req, res) => {
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
router.post('/events/:eventId/schedule', async (req, res) => {
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
router.post('/events/:eventId/schedule/bulk', async (req, res) => {
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
router.put('/schedule/:id', async (req, res) => {
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
router.delete('/schedule/:id', async (req, res) => {
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
router.post('/events/:eventId/pins', async (req, res) => {
  try {
    const { label, pinType, x, y, description } = req.body;
    const { rows } = await pool.query(`
      INSERT INTO map_pins (event_id, label, pin_type, x, y, description)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `, [req.params.eventId, label, pinType || 'custom', x, y, description || '']);

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error creating map pin:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/events/:eventId/pins/bulk
router.post('/events/:eventId/pins/bulk', async (req, res) => {
  try {
    const { pins } = req.body;
    const results = [];

    for (const pin of pins) {
      const { rows } = await pool.query(`
        INSERT INTO map_pins (event_id, label, pin_type, x, y, description)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING *
      `, [req.params.eventId, pin.label, pin.pinType || 'custom', pin.x, pin.y, pin.description || '']);
      results.push(rows[0]);
    }

    res.status(201).json(results);
  } catch (err) {
    console.error('Error bulk creating pins:', err);
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/admin/pins/:id
router.delete('/pins/:id', async (req, res) => {
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
router.get('/events/:eventId/devices/count', async (req, res) => {
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
router.post('/events/:eventId/push', async (req, res) => {
  try {
    const { title, body, category } = req.body;
    if (!title || !body) {
      return res.status(400).json({ error: 'title and body are required' });
    }

    // Look up event name to prefix the notification
    const eventResult = await pool.query('SELECT name FROM events WHERE id = $1', [req.params.eventId]);
    const eventName = eventResult.rows[0]?.name || 'Event';
    const fullTitle = `${eventName}: ${title}`;

    const result = await sendPushToEvent(req.params.eventId, fullTitle, body);

    // Record in push_notifications history
    const { rows } = await pool.query(
      `INSERT INTO push_notifications (event_id, title, body, sent_count, failed_count)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [req.params.eventId, fullTitle, body, result.sent, result.failed]
    );

    res.json({ notification: rows[0], ...result });
  } catch (err) {
    console.error('Error sending push:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/schedule/:id/push — send notification to users who saved this item
router.post('/schedule/:id/push', async (req, res) => {
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
router.get('/events/:eventId/push', async (req, res) => {
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

// =====================
// LLM SCHEDULE PARSING
// =====================

// POST /api/admin/parse-schedule — parse raw text into structured schedule items
router.post('/parse-schedule', async (req, res) => {
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
router.post('/import-url', async (req, res) => {
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
// AI MAP PIN DETECTION
// =====================

// POST /api/admin/detect-map-pins — use Claude Vision to detect pins/landmarks on a map image
router.post('/detect-map-pins', async (req, res) => {
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

    const imgBuffer = await imgResponse.arrayBuffer();
    const base64 = Buffer.from(imgBuffer).toString('base64');

    // Determine media type
    const contentType = imgResponse.headers.get('content-type') || 'image/png';
    const mediaType = contentType.includes('jpeg') || contentType.includes('jpg') ? 'image/jpeg' : 'image/png';

    const client = new Anthropic();

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
            text: `Analyze this venue/event map image${eventName ? ` for "${eventName}"` : ''}. Identify all notable locations, landmarks, facilities, and points of interest visible on the map.

For each location found, provide:
- label: the name as shown on the map (or a descriptive name if no label visible)
- pinType: one of "Stage", "Food", "Restroom", "First Aid", "Exit", or "Custom"
- x: horizontal position as a decimal from 0 (left edge) to 1 (right edge)
- y: vertical position as a decimal from 0 (top edge) to 1 (bottom edge)
- description: brief description of what this location is

Look for:
- Stages, performance areas, theaters, amphitheaters → "Stage"
- Food courts, restaurants, bars, concessions, food trucks → "Food"
- Restrooms, bathrooms, toilets → "Restroom"
- First aid stations, medical → "First Aid"
- Entrances, exits, gates, parking → "Exit"
- Everything else (landmarks, attractions, info booths, etc.) → "Custom"

Return ONLY a JSON array of objects. If you can't identify any locations, return [].
Be as precise as possible with x,y coordinates — estimate the center of each location on the map image.`
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

module.exports = router;
