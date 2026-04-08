const express = require('express');
const router = express.Router();

// Simple in-memory cache: { key -> { expires, data } }
const cache = new Map();
const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour

// Optional Socrata dataset id (e.g. "7vjk-q4xg" for Seattle Street Use Permits).
// Set this in Railway env once you've confirmed the right dataset.
const SOCRATA_DOMAIN = process.env.SOCRATA_DOMAIN || 'data.seattle.gov';
const SOCRATA_DATASET = process.env.SOCRATA_DATASET || ''; // empty = mock mode

// Generate fake closures around a coordinate so the UI can be demoed
// before the real data source is wired up.
function mockClosures(centerLat, centerLon, startDate, endDate) {
  const offsets = [
    [0.0010, -0.0008, 0.0008, 0.0008],
    [-0.0006, 0.0012, -0.0014, -0.0002],
    [0.0004, 0.0018, 0.0014, 0.0028],
  ];
  return offsets.map((o, i) => ({
    id: `mock-${i}`,
    description: ['Street fair load-in (Pine St)', 'Vendor staging (Olive Way)', 'Stage setup (5th Ave)'][i],
    coordinates: [
      [centerLat + o[0], centerLon + o[1]],
      [centerLat + o[2], centerLon + o[3]],
    ],
    startDate,
    endDate,
    source: 'mock',
  }));
}

// Normalize one Socrata row → our shape. Socrata payloads vary by dataset,
// so this is intentionally permissive.
function normalize(row) {
  // Try to extract a polyline / polygon from common geometry fields.
  let coords = null;
  const geom = row.shape || row.the_geom || row.location;
  if (geom && geom.type === 'LineString' && Array.isArray(geom.coordinates)) {
    coords = geom.coordinates.map(([lng, lat]) => [lat, lng]);
  } else if (geom && geom.type === 'Polygon' && Array.isArray(geom.coordinates)) {
    coords = geom.coordinates[0].map(([lng, lat]) => [lat, lng]);
  } else if (row.latitude && row.longitude) {
    // Single-point permit — render as a tiny segment so it still shows.
    const lat = parseFloat(row.latitude);
    const lng = parseFloat(row.longitude);
    coords = [[lat, lng], [lat + 0.00005, lng + 0.00005]];
  }

  if (!coords || coords.length < 2) return null;

  return {
    id: row.permit_number || row.id || row.objectid || String(Math.random()),
    description: row.permit_type || row.permit_description || row.description || 'Street use permit',
    coordinates: coords,
    startDate: row.permit_start_date || row.start_date || null,
    endDate: row.permit_end_date || row.end_date || null,
    source: 'socrata',
  };
}

// GET /api/street-closures?startDate=...&endDate=...&lat=...&lng=...&radius=...
router.get('/', async (req, res) => {
  try {
    const { startDate, endDate, lat, lng } = req.query;
    const radius = parseFloat(req.query.radius || '0.02'); // ~2km in degrees

    const cacheKey = `${SOCRATA_DATASET}|${startDate}|${endDate}|${lat}|${lng}|${radius}`;
    const hit = cache.get(cacheKey);
    if (hit && hit.expires > Date.now()) {
      return res.json(hit.data);
    }

    // Mock mode (no Socrata dataset configured) — return placeholder closures
    // around the requested point so the iOS map can demo the overlay.
    if (!SOCRATA_DATASET) {
      const centerLat = parseFloat(lat || '47.6062');
      const centerLon = parseFloat(lng || '-122.3321');
      const data = mockClosures(centerLat, centerLon, startDate, endDate);
      cache.set(cacheKey, { expires: Date.now() + CACHE_TTL_MS, data });
      return res.json(data);
    }

    // Real fetch from Socrata. Using $where for date overlap and a basic
    // bounding-box filter on latitude/longitude when present.
    const params = new URLSearchParams();
    params.set('$limit', '500');
    const where = [];
    if (startDate && endDate) {
      where.push(`permit_end_date >= '${startDate}'`);
      where.push(`permit_start_date <= '${endDate}'`);
    }
    if (lat && lng) {
      const la = parseFloat(lat);
      const lo = parseFloat(lng);
      where.push(`latitude BETWEEN ${la - radius} AND ${la + radius}`);
      where.push(`longitude BETWEEN ${lo - radius} AND ${lo + radius}`);
    }
    if (where.length) params.set('$where', where.join(' AND '));

    const url = `https://${SOCRATA_DOMAIN}/resource/${SOCRATA_DATASET}.json?${params}`;
    const headers = {};
    if (process.env.SOCRATA_APP_TOKEN) {
      headers['X-App-Token'] = process.env.SOCRATA_APP_TOKEN;
    }
    const response = await fetch(url, { headers });
    if (!response.ok) {
      throw new Error(`Socrata returned ${response.status}`);
    }
    const rows = await response.json();
    const normalized = rows.map(normalize).filter(Boolean);

    cache.set(cacheKey, { expires: Date.now() + CACHE_TTL_MS, data: normalized });
    res.json(normalized);
  } catch (err) {
    console.error('street-closures error:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
