const express = require('express');
const cors = require('cors');
const { pool } = require('./db/pool');
const eventsRouter = require('./routes/events');
const adminRouter = require('./routes/admin');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

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

app.listen(PORT, () => {
  console.log(`Canopy API running on port ${PORT}`);
});
