const { pool } = require('./pool');

async function seed() {
  try {
    // Bumbershoot
    const { rows: [bumbershoot] } = await pool.query(`
      INSERT INTO events (name, slug, description, start_date, end_date, location, neighborhood, logo_system_image, ticketing_url, latitude, longitude, category)
      VALUES (
        'Bumbershoot', 'bumbershoot-2026',
        'Seattle''s premier music and arts festival at Seattle Center. Three days of live music, comedy, film, visual arts, and more.',
        '2026-08-29', '2026-08-31',
        'Seattle Center', 'Lower Queen Anne',
        'music.note.list', 'https://www.bumbershoot.com/tickets',
        47.6215, -122.3510, 'festival'
      )
      ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
      RETURNING id
    `);

    const { rows: [mainStage] } = await pool.query(`
      INSERT INTO stages (event_id, name, map_x, map_y)
      VALUES ($1, 'Main Stage', 0.50, 0.25) RETURNING id
    `, [bumbershoot.id]);

    const { rows: [fisher] } = await pool.query(`
      INSERT INTO stages (event_id, name, map_x, map_y)
      VALUES ($1, 'Fisher Pavilion', 0.28, 0.48) RETURNING id
    `, [bumbershoot.id]);

    const { rows: [mural] } = await pool.query(`
      INSERT INTO stages (event_id, name, map_x, map_y)
      VALUES ($1, 'Mural Amphitheatre', 0.72, 0.38) RETURNING id
    `, [bumbershoot.id]);

    // Schedule items
    const scheduleItems = [
      [bumbershoot.id, mainStage.id, 'The Head and the Heart', 'Indie folk headliner from Seattle', '2026-08-29 20:00', '2026-08-29 21:30', 'Music'],
      [bumbershoot.id, mural.id, 'Local Natives', 'Indie rock from Los Angeles', '2026-08-29 17:00', '2026-08-29 18:30', 'Music'],
      [bumbershoot.id, fisher.id, 'Comedy Showcase', 'Stand-up featuring PNW comedians', '2026-08-29 14:00', '2026-08-29 15:30', 'Comedy'],
      [bumbershoot.id, fisher.id, 'Indie Film Screening', 'Curated short films from local filmmakers', '2026-08-30 11:00', '2026-08-30 13:00', 'Film'],
      [bumbershoot.id, mainStage.id, 'Brandi Carlile', 'Grammy-winning singer-songwriter', '2026-08-30 20:00', '2026-08-30 21:30', 'Music'],
      [bumbershoot.id, mural.id, 'Art Walk', 'Guided tour of festival art installations', '2026-08-31 10:00', '2026-08-31 12:00', 'Art'],
    ];

    for (const item of scheduleItems) {
      await pool.query(`
        INSERT INTO schedule_items (event_id, stage_id, title, description, start_time, end_time, category)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
      `, item);
    }

    // Bite of Seattle
    const { rows: [bite] } = await pool.query(`
      INSERT INTO events (name, slug, description, start_date, end_date, location, neighborhood, logo_system_image, ticketing_url, latitude, longitude, category)
      VALUES (
        'Bite of Seattle', 'bite-of-seattle-2026',
        'The Pacific Northwest''s largest food festival featuring 60+ restaurants, live cooking demos, and entertainment.',
        '2026-07-17', '2026-07-19',
        'Seattle Center', 'Lower Queen Anne',
        'fork.knife', 'https://www.biteofseattle.com',
        47.6215, -122.3510, 'fair'
      )
      ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
      RETURNING id
    `);

    const { rows: [biteDemo] } = await pool.query(`
      INSERT INTO stages (event_id, name, map_x, map_y)
      VALUES ($1, 'Main Demo Stage', 0.50, 0.30) RETURNING id
    `, [bite.id]);

    const biteSchedule = [
      [bite.id, biteDemo.id, 'Tom Douglas Cook-Off', 'Celebrity chef showdown', '2026-07-17 12:00', '2026-07-17 13:30', 'Cooking'],
      [bite.id, biteDemo.id, 'PNW Wine Tasting', 'Sample wines from Washington vineyards', '2026-07-17 15:00', '2026-07-17 17:00', 'Tasting'],
      [bite.id, biteDemo.id, 'Kids Cooking Class', 'Hands-on cooking for ages 6-12', '2026-07-19 11:00', '2026-07-19 12:00', 'Family'],
    ];

    for (const item of biteSchedule) {
      await pool.query(`
        INSERT INTO schedule_items (event_id, stage_id, title, description, start_time, end_time, category)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
      `, item);
    }

    console.log('Seed data inserted successfully.');
  } catch (err) {
    console.error('Seed failed:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

seed();
