const express = require('express');
const router = express.Router();
const { pool } = require('../db/pool');

// POST /api/devices/register
// Public endpoint — devices self-register their push token, event subscriptions, and saved items
router.post('/register', async (req, res) => {
  try {
    const { deviceToken, eventIds, scheduleItemIds } = req.body;

    if (!deviceToken || typeof deviceToken !== 'string') {
      return res.status(400).json({ error: 'deviceToken is required' });
    }

    const events = Array.isArray(eventIds) ? eventIds : [];
    const items = Array.isArray(scheduleItemIds) ? scheduleItemIds : [];

    // Upsert event subscriptions
    for (const eventId of events) {
      await pool.query(
        `INSERT INTO device_tokens (device_token, event_id)
         VALUES ($1, $2)
         ON CONFLICT (device_token, event_id)
         DO UPDATE SET updated_at = NOW()`,
        [deviceToken, eventId]
      );
    }

    // Clean up stale event subscriptions
    if (events.length > 0) {
      await pool.query(
        `DELETE FROM device_tokens WHERE device_token = $1 AND event_id != ALL($2)`,
        [deviceToken, events]
      );
    } else {
      await pool.query('DELETE FROM device_tokens WHERE device_token = $1', [deviceToken]);
    }

    // Upsert saved item subscriptions
    for (const itemId of items) {
      await pool.query(
        `INSERT INTO device_saved_items (device_token, schedule_item_id)
         VALUES ($1, $2)
         ON CONFLICT (device_token, schedule_item_id) DO NOTHING`,
        [deviceToken, itemId]
      );
    }

    // Clean up stale item subscriptions
    if (items.length > 0) {
      await pool.query(
        `DELETE FROM device_saved_items WHERE device_token = $1 AND schedule_item_id != ALL($2)`,
        [deviceToken, items]
      );
    } else {
      await pool.query('DELETE FROM device_saved_items WHERE device_token = $1', [deviceToken]);
    }

    res.json({ registeredEvents: events.length, registeredItems: items.length });
  } catch (err) {
    console.error('[Devices] Registration error:', err.message);
    res.status(500).json({ error: 'Registration failed' });
  }
});

module.exports = router;
