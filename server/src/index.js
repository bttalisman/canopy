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

// One-time: seed tacoma schedule data
app.post('/api/seed-tacoma-schedule', async (req, res) => {
  try {
    // Get tacoma events
    const { rows: events } = await pool.query("SELECT id, slug, start_date FROM events WHERE city = 'tacoma'");
    const bySlug = {};
    for (const e of events) bySlug[e.slug] = e;

    let stagesCreated = 0, itemsCreated = 0;

    // MOSAIC
    const mosaic = bySlug['mosaic-tacoma-2026'];
    if (mosaic) {
      const { rows: [s1] } = await pool.query("INSERT INTO stages (event_id, name) VALUES ($1, 'Main Stage') ON CONFLICT DO NOTHING RETURNING id", [mosaic.id]);
      const { rows: [s2] } = await pool.query("INSERT INTO stages (event_id, name) VALUES ($1, 'Cultural Stage') ON CONFLICT DO NOTHING RETURNING id", [mosaic.id]);
      stagesCreated += 2;
      const ms = s1?.id, cs = s2?.id;
      if (ms && cs) {
        const items = [
          [ms, 'Opening Ceremony & Parade of Cultures', '2026-07-25T12:00:00-07:00', '2026-07-25T12:45:00-07:00', 'General'],
          [ms, 'Polynesian Dance Ensemble', '2026-07-25T13:00:00-07:00', '2026-07-25T13:45:00-07:00', 'Performance'],
          [ms, 'Mariachi Sol de Tacoma', '2026-07-25T14:00:00-07:00', '2026-07-25T14:45:00-07:00', 'Music'],
          [ms, 'West African Drum Circle', '2026-07-25T15:00:00-07:00', '2026-07-25T15:45:00-07:00', 'Music'],
          [ms, 'K-Pop Dance Showcase', '2026-07-25T16:00:00-07:00', '2026-07-25T16:45:00-07:00', 'Performance'],
          [ms, 'Closing Performance: Tacoma Community Choir', '2026-07-25T17:00:00-07:00', '2026-07-25T18:00:00-07:00', 'Music'],
          [cs, 'Japanese Taiko Drumming', '2026-07-25T12:30:00-07:00', '2026-07-25T13:15:00-07:00', 'Music'],
          [cs, 'Indian Classical Dance', '2026-07-25T13:30:00-07:00', '2026-07-25T14:15:00-07:00', 'Performance'],
          [cs, 'Chinese Lion Dance', '2026-07-25T14:30:00-07:00', '2026-07-25T15:15:00-07:00', 'Performance'],
          [cs, 'Ethiopian Coffee Ceremony Demo', '2026-07-25T15:30:00-07:00', '2026-07-25T16:15:00-07:00', 'Workshop'],
          [cs, 'Filipino Folk Dance', '2026-07-26T12:00:00-07:00', '2026-07-26T12:45:00-07:00', 'Performance'],
          [cs, 'Capoeira Demonstration', '2026-07-26T13:00:00-07:00', '2026-07-26T13:45:00-07:00', 'Performance'],
        ];
        for (const [sid, title, st, et, cat] of items) {
          await pool.query("INSERT INTO schedule_items (event_id, stage_id, title, start_time, end_time, category) VALUES ($1,$2,$3,$4,$5,$6)", [mosaic.id, sid, title, st, et, cat]);
          itemsCreated++;
        }
      }
    }

    // Glass Fest
    const glass = bySlug['glass-fest-nw-2026'];
    if (glass) {
      const { rows: [s1] } = await pool.query("INSERT INTO stages (event_id, name) VALUES ($1, 'Hot Shop') ON CONFLICT DO NOTHING RETURNING id", [glass.id]);
      const { rows: [s2] } = await pool.query("INSERT INTO stages (event_id, name) VALUES ($1, 'Museum Plaza') ON CONFLICT DO NOTHING RETURNING id", [glass.id]);
      stagesCreated += 2;
      const hs = s1?.id, mp = s2?.id;
      if (hs && mp) {
        const items = [
          [hs, 'Live Glassblowing: Vessels', '2026-08-08T10:00:00-07:00', '2026-08-08T11:00:00-07:00', 'Demo'],
          [hs, 'Live Glassblowing: Sculptures', '2026-08-08T11:30:00-07:00', '2026-08-08T12:30:00-07:00', 'Demo'],
          [hs, 'Neon Bending Workshop', '2026-08-08T13:00:00-07:00', '2026-08-08T14:00:00-07:00', 'Workshop'],
          [hs, 'Guest Artist Demo: Flamework Jewelry', '2026-08-08T14:30:00-07:00', '2026-08-08T15:30:00-07:00', 'Demo'],
          [mp, 'Kids Glass Fusing Activity', '2026-08-08T10:00:00-07:00', '2026-08-08T16:00:00-07:00', 'Workshop'],
          [mp, 'Live Music: Pacific Sound Collective', '2026-08-08T12:00:00-07:00', '2026-08-08T13:30:00-07:00', 'Music'],
          [mp, 'Artist Panel: Glass Art in the PNW', '2026-08-08T14:00:00-07:00', '2026-08-08T15:00:00-07:00', 'Talk'],
        ];
        for (const [sid, title, st, et, cat] of items) {
          await pool.query("INSERT INTO schedule_items (event_id, stage_id, title, start_time, end_time, category) VALUES ($1,$2,$3,$4,$5,$6)", [glass.id, sid, title, st, et, cat]);
          itemsCreated++;
        }
      }
    }

    // Taste of Tacoma
    const taste = bySlug['taste-of-tacoma-2026'];
    if (taste) {
      const { rows: [s1] } = await pool.query("INSERT INTO stages (event_id, name) VALUES ($1, 'Main Stage') ON CONFLICT DO NOTHING RETURNING id", [taste.id]);
      const { rows: [s2] } = await pool.query("INSERT INTO stages (event_id, name) VALUES ($1, 'Craft Beer Garden') ON CONFLICT DO NOTHING RETURNING id", [taste.id]);
      stagesCreated += 2;
      const ms = s1?.id, bg = s2?.id;
      if (ms && bg) {
        const items = [
          [ms, 'Tacoma School of Rock', '2026-06-26T12:00:00-07:00', '2026-06-26T13:00:00-07:00', 'Music'],
          [ms, 'The Beatniks', '2026-06-26T14:00:00-07:00', '2026-06-26T15:30:00-07:00', 'Music'],
          [ms, 'Star Anna', '2026-06-26T16:00:00-07:00', '2026-06-26T17:30:00-07:00', 'Music'],
          [ms, 'La Fonda', '2026-06-27T13:00:00-07:00', '2026-06-27T14:30:00-07:00', 'Music'],
          [ms, 'Brothers From Another', '2026-06-27T15:00:00-07:00', '2026-06-27T16:30:00-07:00', 'Music'],
          [ms, 'Headliner TBA', '2026-06-27T17:30:00-07:00', '2026-06-27T19:30:00-07:00', 'Music'],
          [bg, 'Craft Beer Tasting: Local Breweries', '2026-06-26T12:00:00-07:00', '2026-06-26T20:00:00-07:00', 'Food & Drink'],
          [bg, 'Cider & Mead Showcase', '2026-06-27T12:00:00-07:00', '2026-06-27T20:00:00-07:00', 'Food & Drink'],
          [bg, 'Chef Cook-Off Competition', '2026-06-28T13:00:00-07:00', '2026-06-28T15:00:00-07:00', 'Food & Drink'],
        ];
        for (const [sid, title, st, et, cat] of items) {
          await pool.query("INSERT INTO schedule_items (event_id, stage_id, title, start_time, end_time, category) VALUES ($1,$2,$3,$4,$5,$6)", [taste.id, sid, title, st, et, cat]);
          itemsCreated++;
        }
      }
    }

    // Tacoma Freedom Fair
    const freedom = bySlug['tacoma-freedom-fair-2026'];
    if (freedom) {
      const { rows: [s1] } = await pool.query("INSERT INTO stages (event_id, name) VALUES ($1, 'Waterfront Stage') ON CONFLICT DO NOTHING RETURNING id", [freedom.id]);
      stagesCreated++;
      if (s1?.id) {
        const items = [
          [s1.id, 'Community Band', '2026-07-04T12:00:00-07:00', '2026-07-04T13:00:00-07:00', 'Music'],
          [s1.id, 'Pacific Islanders Dance Troupe', '2026-07-04T13:30:00-07:00', '2026-07-04T14:15:00-07:00', 'Performance'],
          [s1.id, 'Hot Dog Eating Contest', '2026-07-04T15:00:00-07:00', '2026-07-04T15:45:00-07:00', 'Competition'],
          [s1.id, 'Tacoma Symphony Orchestra Pops', '2026-07-04T18:00:00-07:00', '2026-07-04T20:00:00-07:00', 'Music'],
          [s1.id, 'Fireworks over Commencement Bay', '2026-07-04T22:00:00-07:00', '2026-07-04T22:30:00-07:00', 'General'],
        ];
        for (const [sid, title, st, et, cat] of items) {
          await pool.query("INSERT INTO schedule_items (event_id, stage_id, title, start_time, end_time, category) VALUES ($1,$2,$3,$4,$5,$6)", [freedom.id, sid, title, st, et, cat]);
          itemsCreated++;
        }
      }
    }

    res.json({ stagesCreated, itemsCreated });
  } catch (err) {
    res.status(500).json({ error: err.message });
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

// One-time: mark events as accessible
app.post('/api/fix-accessible', async (req, res) => {
  const { rowCount } = await pool.query(
    "UPDATE events SET is_accessible = true WHERE city = 'seattle' AND (is_accessible IS NULL OR is_accessible = false)"
  );
  res.json({ updated: rowCount });
});

// One-time: mark free events
app.post('/api/fix-free', async (req, res) => {
  const freeSlugs = [
    'uw-cherry-blossom-2026', 'first-thursday-art-walk-2026',
    'u-district-street-fair-2026', 'northwest-folklife-2026',
    'juneteenth-seattle-2026', 'fremont-solstice-2026',
    'capitol-hill-pride-2026', 'seattle-pride-2026',
    'fourth-july-2026', 'kexp-mural-2026',
    'ballard-seafood-2026', 'west-seattle-summerfest-2026',
    'bite-of-seattle-2026', 'dragon-fest-2026',
    'seafair-2026', 'dia-de-los-muertos-2026',
    'winterfest-2026',
  ];
  const ticketedSlugs = [
    'uw-baseball-2026', 'siff-2026',
    'scms-summer-2026', 'timber-outdoor-2026',
    'chbp-2026', 'eccc-2026', 'bumbershoot-2026',
    'pax-west-2026', 'uw-football-2026',
    'fremont-oktoberfest-2026', 'earshot-jazz-2026',
  ];
  const r1 = await pool.query(
    "UPDATE events SET is_free = true WHERE slug = ANY($1)", [freeSlugs]
  );
  const r2 = await pool.query(
    "UPDATE events SET is_free = false WHERE slug = ANY($1)", [ticketedSlugs]
  );
  res.json({ markedFree: r1.rowCount, markedTicketed: r2.rowCount });
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
