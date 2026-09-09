#!/usr/bin/env node
// Uploads AppStore/screenshots/{ja,en}/tab*.png to the 1.0.0 App Store version's screenshot
// sets via the App Store Connect API (appScreenshotSets / appScreenshots: reserve -> upload to
// the returned S3 URL -> commit, the same three-step flow used for build assets).
//
// The 6.9" display type's exact enum string is not consistently documented as of this writing
// (Apple added 6.9" support after the last doc refresh some developers have seen — see
// developer.apple.com/forums/thread/763908). This script tries a short list of candidates and
// uses whichever the API accepts.
'use strict';

const fs = require('fs');
const path = require('path');
const https = require('https');
const crypto = require('crypto');
const { loadMetadata, findAppOrExit, api } = require('./asc_common');

const CANDIDATE_DISPLAY_TYPES = ['APP_IPHONE_69', 'APP_IPHONE_67', 'APP_IPHONE_65'];
const LOCALE_MAP = { ja: 'ja', en: 'en-US' };
const SCREENSHOT_DIR = path.join(__dirname, '..', 'AppStore', 'screenshots');

function md5(buf) {
  return crypto.createHash('md5').update(buf).digest('hex');
}

function uploadToS3(url, headers, buffer) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = https.request(
      { hostname: u.hostname, path: u.pathname + u.search, method: 'PUT', headers: { ...headersToObject(headers), 'Content-Length': buffer.length } },
      (res) => {
        res.on('data', () => {});
        res.on('end', () => resolve(res.statusCode));
      }
    );
    req.on('error', reject);
    req.write(buffer);
    req.end();
  });
}

function headersToObject(headerArray) {
  const out = {};
  for (const h of headerArray || []) out[h.name] = h.value;
  return out;
}

async function findScreenshotSet(localizationId) {
  const sets = await api.get(`/appStoreVersionLocalizations/${localizationId}/appScreenshotSets`);
  api.assertOk(sets, 'listing appScreenshotSets');
  const existing = sets.body.data.find((s) => CANDIDATE_DISPLAY_TYPES.includes(s.attributes.screenshotDisplayType));
  if (existing) return existing;

  for (const displayType of CANDIDATE_DISPLAY_TYPES) {
    const created = await api.post('/appScreenshotSets', {
      data: {
        type: 'appScreenshotSets',
        attributes: { screenshotDisplayType: displayType },
        relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: localizationId } } },
      },
    });
    if (created.status >= 200 && created.status < 300) {
      console.log(`  screenshotDisplayType accepted: ${displayType}`);
      return created.body.data;
    }
    console.log(`  ${displayType} rejected (${created.status}), trying next candidate...`);
  }
  throw new Error('No candidate screenshotDisplayType was accepted — check https://developer.apple.com/documentation/appstoreconnectapi/screenshotdisplaytype for the current value and add it to CANDIDATE_DISPLAY_TYPES.');
}

async function uploadOne(setId, filePath) {
  const buffer = fs.readFileSync(filePath);
  const fileName = path.basename(filePath);
  const reserved = await api.post('/appScreenshots', {
    data: {
      type: 'appScreenshots',
      attributes: { fileName, fileSize: buffer.length },
      relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: setId } } },
    },
  });
  api.assertOk(reserved, `reserving screenshot ${fileName}`);
  const screenshot = reserved.body.data;

  const uploadOp = screenshot.attributes.uploadOperations[0];
  await uploadToS3(uploadOp.url, uploadOp.requestHeaders, buffer);

  const committed = await api.patch(`/appScreenshots/${screenshot.id}`, {
    data: { type: 'appScreenshots', id: screenshot.id, attributes: { sourceFileChecksum: md5(buffer), uploaded: true } },
  });
  api.assertOk(committed, `committing screenshot ${fileName}`);
  console.log(`  uploaded ${fileName}`);
}

async function main() {
  const meta = loadMetadata();
  const app = await findAppOrExit(meta.bundleId);
  const versions = await api.get(`/apps/${app.id}/appStoreVersions?filter[versionString]=1.0.0&filter[platform]=IOS`);
  api.assertOk(versions, 'listing appStoreVersions');
  const version = versions.body.data[0];
  if (!version) {
    console.error('No 1.0.0 appStoreVersion found — run `make metadata` first.');
    process.exit(1);
  }

  for (const [dir, ascLocale] of Object.entries(LOCALE_MAP)) {
    const files = fs
      .readdirSync(path.join(SCREENSHOT_DIR, dir))
      .filter((f) => f.endsWith('.png'))
      .sort();
    if (files.length === 0) {
      console.log(`No screenshots in AppStore/screenshots/${dir} — run 'make screenshots' first. Skipping ${ascLocale}.`);
      continue;
    }

    const locs = await api.get(`/appStoreVersions/${version.id}/appStoreVersionLocalizations?filter[locale]=${ascLocale}`);
    api.assertOk(locs, `finding ${ascLocale} localization`);
    const loc = locs.body.data[0];
    if (!loc) {
      console.log(`No ${ascLocale} localization found — run 'make metadata' first. Skipping.`);
      continue;
    }

    console.log(`-- ${ascLocale}: ${files.length} screenshot(s)`);
    const set = await findScreenshotSet(loc.id);
    for (const f of files) {
      await uploadOne(set.id, path.join(SCREENSHOT_DIR, dir, f));
    }
  }

  console.log('Screenshot upload complete.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
