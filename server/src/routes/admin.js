const { Router } = require('express');
const Anthropic = require('@anthropic-ai/sdk');
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
            logoSystemImage, imageURL, ticketingURL, latitude, longitude, category } = req.body;

    const { rows } = await pool.query(`
      INSERT INTO events (name, slug, description, start_date, end_date, location, neighborhood,
                          logo_system_image, image_url, ticketing_url, latitude, longitude, category)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
      RETURNING *
    `, [name, slug, description || '', startDate, endDate, location, neighborhood || '',
        logoSystemImage || 'party.popper', imageURL, ticketingURL, latitude, longitude, category || 'community']);

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
            logoSystemImage, imageURL, ticketingURL, latitude, longitude, category, isActive } = req.body;

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
        ticketing_url = COALESCE($10, ticketing_url),
        latitude = COALESCE($11, latitude),
        longitude = COALESCE($12, longitude),
        category = COALESCE($13, category),
        is_active = COALESCE($14, is_active),
        updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `, [req.params.id, name, description, startDate, endDate, location, neighborhood,
        logoSystemImage, imageURL, ticketingURL, latitude, longitude, category, isActive]);

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
    const { stageId, title, description, startTime, endTime, category } = req.body;
    const { rows } = await pool.query(`
      INSERT INTO schedule_items (event_id, stage_id, title, description, start_time, end_time, category)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *
    `, [req.params.eventId, stageId, title, description || '', startTime, endTime, category || 'General']);

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
        INSERT INTO schedule_items (event_id, stage_id, title, description, start_time, end_time, category)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING *
      `, [req.params.eventId, item.stageId, item.title, item.description || '',
          item.startTime, item.endTime, item.category || 'General']);
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
    const { stageId, title, description, startTime, endTime, category, isCancelled } = req.body;

    const { rows } = await pool.query(`
      UPDATE schedule_items SET
        stage_id = COALESCE($2, stage_id),
        title = COALESCE($3, title),
        description = COALESCE($4, description),
        start_time = COALESCE($5, start_time),
        end_time = COALESCE($6, end_time),
        category = COALESCE($7, category),
        is_cancelled = COALESCE($8, is_cancelled),
        updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `, [req.params.id, stageId, title, description, startTime, endTime, category, isCancelled]);

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

module.exports = router;
