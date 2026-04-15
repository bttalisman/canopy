const { Router } = require('express');
const { pool } = require('../db/pool');

const router = Router();

// GET /api/events — list all active events with their stages, schedule items, and map pins
router.get('/', async (req, res) => {
  try {
    const city = req.query.city || 'seattle';
    const { rows: events } = await pool.query(`
      SELECT e.*,
        v.id AS venue__id, v.name AS venue__name, v.address AS venue__address,
        v.latitude AS venue__latitude, v.longitude AS venue__longitude,
        v.boundary_coordinates AS venue__boundary_coordinates,
        v.website AS venue__website, v.capacity AS venue__capacity,
        v.is_accessible AS venue__is_accessible
      FROM events e
      LEFT JOIN venues v ON e.venue_id = v.id
      WHERE e.is_active = true
        AND (e.status = 'active' OR e.status IS NULL)
        AND (e.city = $1 OR e.city IS NULL)
      ORDER BY e.start_date ASC
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
      venue: event.venue__id ? {
        id: event.venue__id,
        name: event.venue__name,
        address: event.venue__address,
        latitude: event.venue__latitude,
        longitude: event.venue__longitude,
        boundaryCoordinates: event.venue__boundary_coordinates || [],
        website: event.venue__website,
        capacity: event.venue__capacity,
        isAccessible: event.venue__is_accessible,
      } : null,
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
// Now queries from venues table (with fallback to legacy venue_boundaries)
router.get('/venue-boundaries', async (req, res) => {
  try {
    const city = req.query.city || 'seattle';

    // Query venues table for boundaries
    const { rows: venueRows } = await pool.query(
      `SELECT id, name AS venue_name, boundary_coordinates AS coordinates, city, latitude, longitude
       FROM venues
       WHERE city = $1
       ORDER BY name ASC`,
      [city]
    );

    // Also query legacy venue_boundaries for any that aren't in venues yet
    const { rows: legacyRows } = await pool.query(
      'SELECT id, venue_name, coordinates, city FROM venue_boundaries WHERE city = $1 ORDER BY venue_name ASC',
      [city]
    );

    // Merge: venues first, then legacy entries whose name doesn't match a venue
    const venueNames = new Set(venueRows.map(r => r.venue_name.toLowerCase()));
    const combined = [
      ...venueRows,
      ...legacyRows.filter(r => !venueNames.has(r.venue_name.toLowerCase())),
    ];

    res.json(combined.map(r => ({
      id: r.id,
      venueName: r.venue_name,
      coordinates: r.coordinates || [],
      city: r.city,
      latitude: r.latitude || null,
      longitude: r.longitude || null,
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
      `SELECT e.*,
        v.id AS venue__id, v.name AS venue__name, v.address AS venue__address,
        v.latitude AS venue__latitude, v.longitude AS venue__longitude,
        v.boundary_coordinates AS venue__boundary_coordinates,
        v.website AS venue__website, v.capacity AS venue__capacity,
        v.is_accessible AS venue__is_accessible
      FROM events e
      LEFT JOIN venues v ON e.venue_id = v.id
      WHERE e.slug = $1 AND e.is_active = true
        AND (e.status = 'active' OR e.status IS NULL)`,
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
      venue: event.venue__id ? {
        id: event.venue__id,
        name: event.venue__name,
        address: event.venue__address,
        latitude: event.venue__latitude,
        longitude: event.venue__longitude,
        boundaryCoordinates: event.venue__boundary_coordinates || [],
        website: event.venue__website,
        capacity: event.venue__capacity,
        isAccessible: event.venue__is_accessible,
      } : null,
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
