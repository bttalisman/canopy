const apn = require('@parse/node-apn');
const { pool } = require('../db/pool');

let provider = null;

function getProvider() {
  if (provider) return provider;

  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;
  const bundleId = process.env.APNS_BUNDLE_ID || 'btt.canopy';
  const isProduction = process.env.APNS_PRODUCTION === 'true';

  if (!keyId || !teamId) {
    return null;
  }

  // Support base64-encoded key contents (for Railway/cloud) or file path (for local dev)
  const keyContents = process.env.APNS_KEY_CONTENTS;
  const keyPath = process.env.APNS_KEY_PATH;

  if (!keyContents && !keyPath) {
    return null;
  }

  const options = {
    token: {
      key: keyContents ? Buffer.from(keyContents, 'base64') : keyPath,
      keyId,
      teamId,
    },
    production: isProduction,
  };

  provider = new apn.Provider(options);
  console.log(`[APNs] Provider initialized (${isProduction ? 'production' : 'sandbox'})`);
  return provider;
}

async function sendPushToEvent(eventId, title, body) {
  const apnProvider = getProvider();
  if (!apnProvider) {
    console.log('[APNs] Provider not configured, skipping push');
    return { sent: 0, failed: 0, error: 'APNs not configured' };
  }

  // Get all device tokens for this event
  const result = await pool.query(
    'SELECT device_token FROM device_tokens WHERE event_id = $1',
    [eventId]
  );

  const tokens = result.rows.map(r => r.device_token);
  if (tokens.length === 0) {
    return { sent: 0, failed: 0 };
  }

  // Build the notification
  const notification = new apn.Notification();
  notification.alert = { title, body };
  notification.sound = 'default';
  notification.topic = process.env.APNS_BUNDLE_ID || 'btt.canopy';

  // Send to all tokens
  const response = await apnProvider.send(notification, tokens);

  // Clean up invalid tokens
  const badTokens = response.failed
    .filter(f => f.response && (f.response.reason === 'Unregistered' || f.response.reason === 'BadDeviceToken'))
    .map(f => f.device);

  if (badTokens.length > 0) {
    await pool.query(
      'DELETE FROM device_tokens WHERE device_token = ANY($1)',
      [badTokens]
    );
    console.log(`[APNs] Removed ${badTokens.length} invalid tokens`);
  }

  const sent = response.sent.length;
  const failed = response.failed.length;
  console.log(`[APNs] Sent to ${sent}, failed: ${failed}`);

  return { sent, failed };
}

module.exports = { sendPushToEvent };
