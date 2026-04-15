const { Router } = require('express');
const { pool } = require('../db/pool');

const router = Router();

// GET /api/events — list all active events with their stages, schedule items, and map pins
router.get('/', async (req, res) => {
  try {
    const city = req.query.city || 'seattle';
    const { rows: events } = await pool.query(`
      SELECT * FROM events
      WHERE is_active = true
        AND (status = 'active' OR status IS NULL)
        AND (city = $1 OR city IS NULL)
      ORDER BY start_date ASC
    `, [city]);

    if (events.length === 0) {
      return res.json([]);
    }

    const eventIds = events.map(e => e.id);

    const [stagesResult, scheduleResult, pinsResult] = await Promise.all([
      pool.query(`SELECT * FROM stages WHERE event_id = ANY($1) ORDER BY name`, [eventIds]),
      pool.query(`SELECT * FROM schedule_items WHERE event_id = ANY($1) ORDER BY start_time`, [eventIds]),
      pool.query(`SELECT * FROM map_pins WHERE event_id = ANY($1) ORDER BY label`, [eventIds]),
    ]);

    const stagesByEvent = groupBy(stagesResult.rows, 'event_id');
    const scheduleByEvent = groupBy(scheduleResult.rows, 'event_id');
    const pinsByEvent = groupBy(pinsResult.rows, 'event_id');

    const result = events.map(event => ({
      id: event.id,
      name: event.name,
      slug: event.slug,
      description: event.description,
      startDate: event.start_date,
      endDate: event.end_date,
      location: event.location,
      neighborhood: event.neighborhood,
      logoSystemImage: event.logo_system_image,
      imageURL: event.image_url,
      mapImageURL: event.map_image_url || null,
      mapCalibration: event.map_calibration || null,
      mapPinSize: event.map_pin_size || null,
      ticketingURL: event.ticketing_url,
      latitude: event.latitude,
      longitude: event.longitude,
      category: event.category,
      permitId: event.permit_id,
      isAccessible: event.is_accessible,
      isFree: event.is_free,
      isCityOfficial: event.is_city_official,
      city: event.city,
      stages: (stagesByEvent[event.id] || []).map(s => ({
        id: s.id,
        name: s.name,
        mapX: s.map_x,
        mapY: s.map_y,
      })),
      scheduleItems: (scheduleByEvent[event.id] || []).map(si => ({
        id: si.id,
        stageId: si.stage_id,
        title: si.title,
        description: si.description,
        startTime: si.start_time,
        endTime: si.end_time,
        category: si.category,
        isCancelled: si.is_cancelled,
        performerName: si.performer_name || null,
        performerBio: si.performer_bio || null,
        performerImageURL: si.performer_image_url || null,
        performerLinks: si.performer_links || null,
      })),
      mapPins: (pinsByEvent[event.id] || []).map(p => ({
        id: p.id,
        label: p.label,
        pinType: p.pin_type,
        x: p.x,
        y: p.y,
        latitude: p.latitude,
        longitude: p.longitude,
        description: p.description,
      })),
    }));

    res.json(result);
  } catch (err) {
    console.error('Error fetching events:', err);
    res.status(500).json({ error: 'Failed to fetch events' });
  }
});

// GET /api/events/venue-boundaries — public venue boundary data for iOS
router.get('/venue-boundaries', async (req, res) => {
  try {
    const city = req.query.city || 'seattle';
    const { rows } = await pool.query(
      'SELECT id, venue_name, coordinates, city FROM venue_boundaries WHERE city = $1 ORDER BY venue_name ASC',
      [city]
    );
    res.json(rows.map(r => ({
      id: r.id,
      venueName: r.venue_name,
      coordinates: r.coordinates,
      city: r.city,
    })));
  } catch (err) {
    console.error('Error fetching venue boundaries:', err);
    res.status(500).json({ error: 'Failed to fetch venue boundaries' });
  }
});

// GET /api/events/:slug — single event with full details
router.get('/:slug', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT * FROM events
       WHERE slug = $1 AND is_active = true
         AND (status = 'active' OR status IS NULL)`,
      [req.params.slug]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Event not found' });
    }

    const event = rows[0];

    const [stagesResult, scheduleResult, pinsResult] = await Promise.all([
      pool.query('SELECT * FROM stages WHERE event_id = $1 ORDER BY name', [event.id]),
      pool.query('SELECT * FROM schedule_items WHERE event_id = $1 ORDER BY start_time', [event.id]),
      pool.query('SELECT * FROM map_pins WHERE event_id = $1 ORDER BY label', [event.id]),
    ]);

    res.json({
      id: event.id,
      name: event.name,
      slug: event.slug,
      description: event.description,
      startDate: event.start_date,
      endDate: event.end_date,
      location: event.location,
      neighborhood: event.neighborhood,
      logoSystemImage: event.logo_system_image,
      imageURL: event.image_url,
      mapImageURL: event.map_image_url || null,
      mapCalibration: event.map_calibration || null,
      mapPinSize: event.map_pin_size || null,
      ticketingURL: event.ticketing_url,
      latitude: event.latitude,
      longitude: event.longitude,
      category: event.category,
      permitId: event.permit_id,
      isAccessible: event.is_accessible,
      isFree: event.is_free,
      isCityOfficial: event.is_city_official,
      city: event.city,
      stages: stagesResult.rows.map(s => ({
        id: s.id,
        name: s.name,
        mapX: s.map_x,
        mapY: s.map_y,
      })),
      scheduleItems: scheduleResult.rows.map(si => ({
        id: si.id,
        stageId: si.stage_id,
        title: si.title,
        description: si.description,
        startTime: si.start_time,
        endTime: si.end_time,
        category: si.category,
        isCancelled: si.is_cancelled,
        performerName: si.performer_name || null,
        performerBio: si.performer_bio || null,
        performerImageURL: si.performer_image_url || null,
        performerLinks: si.performer_links || null,
      })),
      mapPins: pinsResult.rows.map(p => ({
        id: p.id,
        label: p.label,
        pinType: p.pin_type,
        x: p.x,
        y: p.y,
        latitude: p.latitude,
        longitude: p.longitude,
        description: p.description,
      })),
    });
  } catch (err) {
    console.error('Error fetching event:', err);
    res.status(500).json({ error: 'Failed to fetch event' });
  }
});

// GET /api/events/ticketmaster/search — proxy Ticketmaster API to keep key server-side
router.get('/ticketmaster/search', async (req, res) => {
  try {
    const apiKey = process.env.TICKETMASTER_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'Ticketmaster API key not configured' });
    }

    // Use lat/long + radius for metro-area search instead of city name
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
      sort: req.query.sort || 'date,asc',
    });

    if (metro) {
      params.set('latlong', metro.latlong);
      params.set('radius', metro.radius);
      params.set('unit', 'miles');
    } else {
      params.set('city', cityName);
      params.set('stateCode', req.query.stateCode || 'WA');
    }

    if (req.query.startDateTime) params.set('startDateTime', req.query.startDateTime);
    if (req.query.endDateTime) params.set('endDateTime', req.query.endDateTime);
    if (req.query.classificationName) params.set('classificationName', req.query.classificationName);
    if (req.query.keyword) params.set('keyword', req.query.keyword);

    const response = await fetch(`https://app.ticketmaster.com/discovery/v2/events.json?${params}`);

    if (!response.ok) {
      return res.status(response.status).json({ error: `Ticketmaster API error: ${response.status}` });
    }

    const data = await response.json();
    res.json(data);
  } catch (err) {
    console.error('Error proxying Ticketmaster:', err);
    res.status(500).json({ error: 'Failed to fetch from Ticketmaster' });
  }
});

function groupBy(arr, key) {
  return arr.reduce((acc, item) => {
    const k = item[key];
    if (!acc[k]) acc[k] = [];
    acc[k].push(item);
    return acc;
  }, {});
}

module.exports = router;
