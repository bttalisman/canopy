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
