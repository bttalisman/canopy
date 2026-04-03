const express = require('express');
const router = express.Router();
const { pool } = require('../db/pool');

// POST /api/devices/register
// Public endpoint — devices self-register their push token and event subscriptions
router.post('/register', async (req, res) => {
  try {
    const { deviceToken, eventIds } = req.body;

    if (!deviceToken || typeof deviceToken !== 'string') {
      return res.status(400).json({ error: 'deviceToken is required' });
    }

    if (!Array.isArray(eventIds)) {
      return res.status(400).json({ error: 'eventIds must be an array' });
    }

    // Upsert a row for each event the device is subscribed to
    for (const eventId of eventIds) {
      await pool.query(
        `INSERT INTO device_tokens (device_token, event_id)
         VALUES ($1, $2)
         ON CONFLICT (device_token, event_id)
         DO UPDATE SET updated_at = NOW()`,
        [deviceToken, eventId]
      );
    }

    // Remove stale subscriptions: if the device no longer has saved items for an event, unsubscribe
    if (eventIds.length > 0) {
      await pool.query(
        `DELETE FROM device_tokens
         WHERE device_token = $1 AND event_id != ALL($2)`,
        [deviceToken, eventIds]
      );
    } else {
      // No events — remove all subscriptions for this device
      await pool.query(
        'DELETE FROM device_tokens WHERE device_token = $1',
        [deviceToken]
      );
    }

    res.json({ registered: eventIds.length });
  } catch (err) {
    console.error('[Devices] Registration error:', err.message);
    res.status(500).json({ error: 'Registration failed' });
  }
});

module.exports = router;
