'use strict';

const fs = require('fs');
const path = require('path');
const api = require('./asc_api');

const METADATA_PATH = path.join(__dirname, '..', 'AppStore', 'metadata.json');

function loadMetadata() {
  return JSON.parse(fs.readFileSync(METADATA_PATH, 'utf8'));
}

/** Looks up the app by bundle ID. Exits with setup instructions if it doesn't exist yet — the
 * App Store Connect API does not support creating a new app record (POST /v1/apps returns
 * 403 FORBIDDEN_ERROR, confirmed live against this account), so that one step has to happen in
 * the App Store Connect web UI first. See README "First app record (one-time, manual)". */
async function findAppOrExit(bundleId) {
  const result = await api.get(`/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`);
  api.assertOk(result, 'looking up app by bundle ID');
  const app = result.body.data[0];
  if (!app) {
    console.error(`No App Store Connect app record found for bundle ID ${bundleId}.`);
    console.error('Create it once at https://appstoreconnect.apple.com/apps (Apps > + > New App), then re-run.');
    console.error('See README "First app record (one-time, manual)" for the exact values to enter.');
    process.exit(1);
  }
  return app;
}

module.exports = { loadMetadata, findAppOrExit, api };
