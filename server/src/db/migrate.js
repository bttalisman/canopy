const { pool: defaultPool } = require('./pool');

const schema = `
  CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    description TEXT DEFAULT '',
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    location TEXT NOT NULL,
    neighborhood TEXT DEFAULT '',
    logo_system_image TEXT DEFAULT 'party.popper',
    image_url TEXT,
    ticketing_url TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    category TEXT DEFAULT 'community',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
  );

  CREATE TABLE IF NOT EXISTS stages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    map_x DOUBLE PRECISION DEFAULT 0,
    map_y DOUBLE PRECISION DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
  );

  CREATE TABLE IF NOT EXISTS schedule_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    stage_id UUID REFERENCES stages(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    category TEXT DEFAULT 'General',
    is_cancelled BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
  );

  CREATE TABLE IF NOT EXISTS map_pins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    pin_type TEXT DEFAULT 'custom',
    x DOUBLE PRECISION NOT NULL,
    y DOUBLE PRECISION NOT NULL,
    description TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW()
  );

  CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_token TEXT NOT NULL,
    event_id UUID NOT NULL,
    platform TEXT DEFAULT 'ios',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(device_token, event_id)
  );

  -- Drop FK constraint on device_tokens so Ticketmaster events with local UUIDs work
  ALTER TABLE device_tokens DROP CONSTRAINT IF EXISTS device_tokens_event_id_fkey;

  CREATE TABLE IF NOT EXISTS push_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    sent_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
  );

  CREATE INDEX IF NOT EXISTS idx_stages_event ON stages(event_id);
  CREATE INDEX IF NOT EXISTS idx_schedule_items_event ON schedule_items(event_id);
  CREATE INDEX IF NOT EXISTS idx_schedule_items_stage ON schedule_items(stage_id);
  CREATE INDEX IF NOT EXISTS idx_map_pins_event ON map_pins(event_id);
  CREATE INDEX IF NOT EXISTS idx_events_active ON events(is_active, start_date);
  CREATE TABLE IF NOT EXISTS device_saved_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_token TEXT NOT NULL,
    schedule_item_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(device_token, schedule_item_id)
  );

  ALTER TABLE events ADD COLUMN IF NOT EXISTS map_image_url TEXT;
  ALTER TABLE events ADD COLUMN IF NOT EXISTS map_pin_size DOUBLE PRECISION;
  ALTER TABLE events ADD COLUMN IF NOT EXISTS map_calibration TEXT;

  ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
  ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

  -- Multi-tenant ownership: each event belongs to a Clerk organization.
  -- Existing rows have NULL until backfilled (treated as superadmin-only).
  ALTER TABLE events ADD COLUMN IF NOT EXISTS owner_org_id TEXT;
  ALTER TABLE events ADD COLUMN IF NOT EXISTS created_by_user_id TEXT;
  ALTER TABLE events ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';
  CREATE INDEX IF NOT EXISTS idx_events_owner_org ON events(owner_org_id);
  CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);

  ALTER TABLE events ADD COLUMN IF NOT EXISTS permit_id TEXT;
  ALTER TABLE events ADD COLUMN IF NOT EXISTS is_accessible BOOLEAN;
  ALTER TABLE events ADD COLUMN IF NOT EXISTS is_free BOOLEAN;
  ALTER TABLE events ADD COLUMN IF NOT EXISTS is_city_official BOOLEAN;

  ALTER TABLE schedule_items ADD COLUMN IF NOT EXISTS performer_name TEXT;
  ALTER TABLE schedule_items ADD COLUMN IF NOT EXISTS performer_bio TEXT;
  ALTER TABLE schedule_items ADD COLUMN IF NOT EXISTS performer_image_url TEXT;
  ALTER TABLE schedule_items ADD COLUMN IF NOT EXISTS performer_links TEXT;

  CREATE INDEX IF NOT EXISTS idx_device_tokens_event ON device_tokens(event_id);
  CREATE INDEX IF NOT EXISTS idx_device_saved_items_item ON device_saved_items(schedule_item_id);
  CREATE INDEX IF NOT EXISTS idx_push_notifications_event ON push_notifications(event_id);

  ALTER TABLE events ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'seattle';
  CREATE INDEX IF NOT EXISTS idx_events_city ON events(city);

  CREATE TABLE IF NOT EXISTS contact_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    organization TEXT DEFAULT '',
    message TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW()
  );

  CREATE TABLE IF NOT EXISTS venue_boundaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_name TEXT UNIQUE NOT NULL,
    coordinates JSONB NOT NULL DEFAULT '[]',
    city TEXT DEFAULT 'seattle',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
  );

  CREATE INDEX IF NOT EXISTS idx_venue_boundaries_city ON venue_boundaries(city);
  CREATE INDEX IF NOT EXISTS idx_venue_boundaries_venue_name ON venue_boundaries(venue_name);

  CREATE TABLE IF NOT EXISTS venues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT DEFAULT '',
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    city TEXT DEFAULT 'seattle',
    boundary_coordinates JSONB DEFAULT '[]',
    website TEXT DEFAULT '',
    capacity TEXT DEFAULT '',
    is_accessible BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
  );
  ALTER TABLE venues ADD COLUMN IF NOT EXISTS aliases JSONB DEFAULT '[]';
  CREATE INDEX IF NOT EXISTS idx_venues_city ON venues(city);
  CREATE UNIQUE INDEX IF NOT EXISTS idx_venues_name_city ON venues(name, city);
  ALTER TABLE events ADD COLUMN IF NOT EXISTS venue_id UUID REFERENCES venues(id) ON DELETE SET NULL;
  CREATE INDEX IF NOT EXISTS idx_events_venue ON events(venue_id);
`;

async function migrate(pool) {
  const db = pool || defaultPool;
  try {
    await db.query(schema);
    console.log('Database migration complete.');
  } catch (err) {
    console.error('Migration failed:', err.message);
    throw err;
  }
}

// Allow running directly: node src/db/migrate.js
if (require.main === module) {
  migrate().then(() => defaultPool.end());
}

module.exports = { migrate };
