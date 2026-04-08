const express = require('express');
const router = express.Router();

// Simple in-memory cache: { key -> { expires, data } }
const cache = new Map();
const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour

// Seattle SDOT publishes street use permits as an ArcGIS Feature Service,
// not as a Socrata dataset. Default to the dissolved Use Impacts polyline
// layer; override via env var if a different source is wanted.
const ARCGIS_LAYER_URL = process.env.ARCGIS_LAYER_URL
  || 'https://services.arcgis.com/ZOyb2t4B0UYuYNYH/arcgis/rest/services/SU_Permit_Data_Model_Relationships/FeatureServer/1';
const USE_MOCK = process.env.STREET_CLOSURES_MOCK === '1';

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

// Normalize one ArcGIS GeoJSON feature → our shape.
function normalizeArcgis(feature) {
  const geom = feature.geometry;
  if (!geom) return null;

  let coords = null;
  if (geom.type === 'LineString') {
    coords = geom.coordinates.map(([lng, lat]) => [lat, lng]);
  } else if (geom.type === 'MultiLineString') {
    // Flatten — render the longest sub-line for simplicity.
    const longest = geom.coordinates.reduce((a, b) => (a.length > b.length ? a : b), []);
    coords = longest.map(([lng, lat]) => [lat, lng]);
  } else if (geom.type === 'Polygon') {
    coords = geom.coordinates[0].map(([lng, lat]) => [lat, lng]);
  }
  if (!coords || coords.length < 2) return null;

  const props = feature.properties || {};
  const desc = [props.PROJECT_DESCRIPTION, props.PERMIT_TYPE_ALIAS]
    .filter(Boolean)
    .join(' — ') || 'SDOT street use permit';

  return {
    id: props.PERMIT_NUMBER || String(feature.id || Math.random()),
    description: desc,
    coordinates: coords,
    startDate: props.FIRST_ISSUED_DATE ? new Date(props.FIRST_ISSUED_DATE).toISOString() : null,
    endDate: props.NEXT_EXPIRATION_DATE ? new Date(props.NEXT_EXPIRATION_DATE).toISOString() : null,
    source: 'arcgis',
  };
}

// GET /api/street-closures?startDate=...&endDate=...&lat=...&lng=...&radius=...
router.get('/', async (req, res) => {
  try {
    const { startDate, endDate, lat, lng } = req.query;
    const radius = parseFloat(req.query.radius || '0.02'); // ~2km in degrees

    const cacheKey = `${ARCGIS_LAYER_URL}|${startDate}|${endDate}|${lat}|${lng}|${radius}`;
    const hit = cache.get(cacheKey);
    if (hit && hit.expires > Date.now()) {
      return res.json(hit.data);
    }

    // Mock mode (forced via env var) — return placeholder closures around
    // the requested point. Useful for offline demos.
    if (USE_MOCK) {
      const centerLat = parseFloat(lat || '47.6062');
      const centerLon = parseFloat(lng || '-122.3321');
      const data = mockClosures(centerLat, centerLon, startDate, endDate);
      cache.set(cacheKey, { expires: Date.now() + CACHE_TTL_MS, data });
      return res.json(data);
    }

    // Real fetch from Seattle SDOT ArcGIS Feature Service.
    // Bounding box filter via geometryType=esriGeometryEnvelope.
    // Date filter: permit must be currently within its issued/expiration window.
    const la = parseFloat(lat || '47.6062');
    const lo = parseFloat(lng || '-122.3321');
    const minX = lo - radius, minY = la - radius, maxX = lo + radius, maxY = la + radius;

    const where = [];
    if (endDate) {
      // Permit hasn't expired before the event starts.
      const startMs = Date.parse(startDate || endDate);
      where.push(`NEXT_EXPIRATION_DATE >= ${startMs}`);
    }
    if (startDate) {
      // Permit was issued before the event ends.
      const endMs = Date.parse(endDate || startDate);
      where.push(`FIRST_ISSUED_DATE <= ${endMs}`);
    }
    if (where.length === 0) where.push('1=1');

    const params = new URLSearchParams({
      where: where.join(' AND '),
      geometry: `${minX},${minY},${maxX},${maxY}`,
      geometryType: 'esriGeometryEnvelope',
      inSR: '4326',
      outSR: '4326',
      spatialRel: 'esriSpatialRelIntersects',
      outFields: 'PERMIT_NUMBER,PERMIT_TYPE_ALIAS,PROJECT_DESCRIPTION,FIRST_ISSUED_DATE,NEXT_EXPIRATION_DATE',
      f: 'geojson',
      resultRecordCount: '200',
    });

    const url = `${ARCGIS_LAYER_URL}/query?${params}`;
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`ArcGIS returned ${response.status}`);
    }
    const json = await response.json();
    const normalized = (json.features || []).map(normalizeArcgis).filter(Boolean);

    cache.set(cacheKey, { expires: Date.now() + CACHE_TTL_MS, data: normalized });
    res.json(normalized);
  } catch (err) {
    console.error('street-closures error:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
