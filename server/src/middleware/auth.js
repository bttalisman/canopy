const { clerkMiddleware, getAuth, requireAuth } = require('@clerk/express');
const { pool } = require('../db/pool');

// Comma-separated list of Clerk userIds with full god-mode access.
// You can find your userId in the Clerk dashboard under "Users".
const SUPERADMIN_USER_IDS = (process.env.SUPERADMIN_USER_IDS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

// Mount Clerk's middleware globally so getAuth(req) works on every route.
// Requests without a valid session token still pass through (auth check
// happens per-route via requireSignedIn / requireSuperadmin).
const clerk = clerkMiddleware();

// Block unauthenticated requests entirely.
const requireSignedIn = requireAuth();

// Helper: is this user a superadmin?
function isSuperadmin(req) {
  const auth = getAuth(req);
  return auth?.userId && SUPERADMIN_USER_IDS.includes(auth.userId);
}

// Require the request to come from a superadmin.
function requireSuperadmin(req, res, next) {
  if (!isSuperadmin(req)) {
    return res.status(403).json({ error: 'Superadmin only' });
  }
  next();
}

// Require the user to either own the event (via their org) or be a superadmin.
// Looks up :id or :eventId from the URL.
async function requireEventAccess(req, res, next) {
  try {
    if (isSuperadmin(req)) return next();

    const auth = getAuth(req);
    if (!auth?.orgId) {
      return res.status(403).json({ error: 'No organization selected' });
    }

    const eventId = req.params.id || req.params.eventId;
    if (!eventId) {
      return res.status(400).json({ error: 'Missing event id in URL' });
    }

    const { rows } = await pool.query(
      'SELECT owner_org_id FROM events WHERE id = $1',
      [eventId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Event not found' });
    }
    if (rows[0].owner_org_id !== auth.orgId) {
      return res.status(403).json({ error: 'Not your event' });
    }
    next();
  } catch (err) {
    console.error('requireEventAccess error:', err);
    res.status(500).json({ error: err.message });
  }
}

// For routes that act on a child of an event (pin, schedule item, stage)
// — pass the SQL to look up the parent event_id from the child's :id.
function requireChildEventAccess(parentLookupSql) {
  return async (req, res, next) => {
    try {
      if (isSuperadmin(req)) return next();

      const auth = getAuth(req);
      if (!auth?.orgId) {
        return res.status(403).json({ error: 'No organization selected' });
      }

      const { rows } = await pool.query(parentLookupSql, [req.params.id]);
      if (rows.length === 0) {
        return res.status(404).json({ error: 'Resource not found' });
      }
      const eventId = rows[0].event_id;
      const { rows: events } = await pool.query(
        'SELECT owner_org_id FROM events WHERE id = $1',
        [eventId]
      );
      if (events.length === 0 || events[0].owner_org_id !== auth.orgId) {
        return res.status(403).json({ error: 'Not your event' });
      }
      next();
    } catch (err) {
      console.error('requireChildEventAccess error:', err);
      res.status(500).json({ error: err.message });
    }
  };
}

module.exports = {
  clerk,
  requireSignedIn,
  requireSuperadmin,
  requireEventAccess,
  requireChildEventAccess,
  isSuperadmin,
  getAuth,
};
