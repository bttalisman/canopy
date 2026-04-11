const path = require('path');
const express = require('express');
const cors = require('cors');
const { pool } = require('./db/pool');
const { migrate } = require('./db/migrate');
const eventsRouter = require('./routes/events');
const devicesRouter = require('./routes/devices');
const adminRouter = require('./routes/admin');
const streetClosuresRouter = require('./routes/streetClosures');
const { clerk } = require('./middleware/auth');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Clerk session middleware — populates req.auth on every request.
// Per-route guards in middleware/auth.js enforce signed-in / org-owner / superadmin.
app.use(clerk);

// Static files (maps, images)
app.use('/maps', express.static(path.join(__dirname, 'public', 'maps')));
app.use('/images', express.static(path.join(__dirname, 'public', 'images')));

// Support page
app.get('/support', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'support.html'));
});

// Privacy policy
app.get('/privacy', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'privacy.html'));
});

// City pitch page
app.get('/city', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'city.html'));
});

// Admin dashboard
app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

// Redirect bare root to /admin so Clerk's default redirects work.
app.get('/', (req, res) => {
  res.redirect('/admin');
});

// Public API routes
app.use('/api/events', eventsRouter);
app.use('/api/devices', devicesRouter);
app.use('/api/street-closures', streetClosuresRouter);

// Admin routes (protected by API key)
app.use('/api/admin', adminRouter);

// Contact form submission
app.post('/api/contact', async (req, res) => {
  const { name, email, organization, message } = req.body;
  if (!name || !email) {
    return res.status(400).json({ error: 'Name and email are required.' });
  }
  try {
    await pool.query(
      'INSERT INTO contact_submissions (name, email, organization, message) VALUES ($1, $2, $3, $4)',
      [name, email, organization || '', message || '']
    );
    res.json({ success: true });
  } catch (err) {
    console.error('Contact form error:', err.message);
    res.status(500).json({ error: 'Failed to submit. Please try again.' });
  }
});

// One-time: seed tacoma events
app.post('/api/seed-tacoma', async (req, res) => {
  const events = [
    { name: "MOSAIC: Tacoma's Arts & Culture Festival", slug: "mosaic-tacoma-2026", description: "A celebration transforming Wright Park into an international cultural experience. Now in its 37th year, MOSAIC features traditional performances on two stages, food trucks offering global cuisines, and a vendor village with multicultural artists and local businesses.", start_date: "2026-07-25T12:00:00-07:00", end_date: "2026-07-26T19:00:00-07:00", location: "Wright Park", neighborhood: "Central", category: "festival", latitude: 47.2533, longitude: -122.4438, is_free: true, is_accessible: true },
    { name: "Glass Fest Northwest", slug: "glass-fest-nw-2026", description: "Live glassmaking demonstrations, artist booths, food vendors, music, and hands-on activities at the Museum of Glass. Free admission for the day.", start_date: "2026-08-08T10:00:00-07:00", end_date: "2026-08-08T17:00:00-07:00", location: "Museum of Glass", neighborhood: "Downtown", category: "fair", latitude: 47.2452, longitude: -122.4293, is_free: true, is_accessible: true },
    { name: "In the Spirit Arts Market & Northwest Native Festival", slug: "in-the-spirit-2026", description: "A beloved summer tradition celebrating the diverse Native cultures of the Pacific Northwest.", start_date: "2026-08-08T10:00:00-07:00", end_date: "2026-08-09T17:00:00-07:00", location: "Washington State History Museum", neighborhood: "Downtown", category: "festival", latitude: 47.2459, longitude: -122.4318, is_free: true, is_accessible: true },
    { name: "Tacoma Night Market", slug: "tacoma-night-market-2026", description: "An outdoor night market featuring local vendors, street food, live music, and community gathering in the Stadium District.", start_date: "2026-06-13T17:00:00-07:00", end_date: "2026-06-13T22:00:00-07:00", location: "Stadium District", neighborhood: "Stadium District", category: "community", latitude: 47.2555, longitude: -122.4420, is_free: true, is_accessible: true },
    { name: "Point Defiance Flower & Garden Festival", slug: "pt-defiance-garden-2026", description: "Annual flower and garden show at Point Defiance Park featuring garden displays, plant sales, workshops, and family activities.", start_date: "2026-06-06T09:00:00-07:00", end_date: "2026-06-07T17:00:00-07:00", location: "Point Defiance Park", neighborhood: "North End", category: "fair", latitude: 47.3050, longitude: -122.5130, is_free: true, is_accessible: true },
    { name: "Sawasdee Thailand Festival", slug: "sawasdee-thailand-2026", description: "A vibrant celebration of Thai culture featuring traditional dance performances, authentic Thai cuisine, temple ceremonies, and cultural demonstrations.", start_date: "2026-06-06T10:00:00-07:00", end_date: "2026-06-06T18:00:00-07:00", location: "Wat Dhammacakka Temple", neighborhood: "South End", category: "festival", latitude: 47.2180, longitude: -122.4650, is_free: true, is_accessible: true },
    { name: "Taste of Tacoma", slug: "taste-of-tacoma-2026", description: "Tacoma's premier food festival featuring dozens of local restaurants, live entertainment, craft beverages, and family activities.", start_date: "2026-06-26T11:00:00-07:00", end_date: "2026-06-28T20:00:00-07:00", location: "Point Defiance Park", neighborhood: "North End", category: "fair", latitude: 47.3050, longitude: -122.5130, is_free: false, is_accessible: true },
    { name: "Tacoma Freedom Fair", slug: "tacoma-freedom-fair-2026", description: "Fourth of July celebration with live music, food vendors, family activities, and fireworks over Commencement Bay.", start_date: "2026-07-04T12:00:00-07:00", end_date: "2026-07-04T23:00:00-07:00", location: "Ruston Way Waterfront", neighborhood: "Ruston", category: "festival", latitude: 47.2920, longitude: -122.4600, is_free: true, is_accessible: true },
    { name: "Hilltop Street Fair", slug: "hilltop-street-fair-2026", description: "Annual neighborhood street fair celebrating the diverse Hilltop community with local vendors, food, live music, and art.", start_date: "2026-08-15T11:00:00-07:00", end_date: "2026-08-15T19:00:00-07:00", location: "Martin Luther King Jr. Way", neighborhood: "Hilltop", category: "community", latitude: 47.2460, longitude: -122.4470, is_free: true, is_accessible: true },
    { name: "Proctor District Farmers Market", slug: "proctor-farmers-market-2026", description: "Weekly farmers market featuring fresh produce, artisan goods, baked goods, and local crafts. Every Saturday through October.", start_date: "2026-05-02T09:00:00-07:00", end_date: "2026-10-31T14:00:00-07:00", location: "Proctor District", neighborhood: "Proctor District", category: "community", latitude: 47.2700, longitude: -122.4900, is_free: true, is_accessible: true },
  ];
  let count = 0;
  for (const e of events) {
    try {
      await pool.query(`
        INSERT INTO events (name, slug, description, start_date, end_date, location, neighborhood, category, latitude, longitude, city, status, is_active, is_free, is_accessible)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'tacoma','active',true,$11,$12)
        ON CONFLICT (slug) DO NOTHING
      `, [e.name, e.slug, e.description, e.start_date, e.end_date, e.location, e.neighborhood, e.category, e.latitude, e.longitude, e.is_free, e.is_accessible]);
      count++;
    } catch (err) { console.error(e.slug, err.message); }
  }
  res.json({ created: count });
});

// Health check
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

// Run migrations then start server
migrate(pool)
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Canopy API running on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error('Failed to start:', err.message);
    process.exit(1);
  });
