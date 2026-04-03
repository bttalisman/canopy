const path = require('path');
const express = require('express');
const cors = require('cors');
const { pool } = require('./db/pool');
const { migrate } = require('./db/migrate');
const eventsRouter = require('./routes/events');
const adminRouter = require('./routes/admin');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Admin dashboard
app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

// Public API routes
app.use('/api/events', eventsRouter);

// Admin routes (protected by API key)
app.use('/api/admin', adminRouter);

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
