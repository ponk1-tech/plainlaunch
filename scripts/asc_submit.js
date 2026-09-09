#!/usr/bin/env node
// Attaches the latest valid build to the 1.0.0 App Store version and creates an App Store review
// submission via the API. Run `make metadata` and `make testflight` first so the version has its
// localizations and the build has finished processing.
'use strict';

const { loadMetadata, findAppOrExit, api } = require('./asc_common');

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

  const builds = await api.get(`/apps/${app.id}/builds?filter[processingState]=VALID&sort=-uploadedDate&limit=1`);
  api.assertOk(builds, 'listing valid builds');
  const build = builds.body.data[0];
  if (!build) {
    console.error('No processed (VALID) build found — run `make upload` and `make testflight` first.');
    process.exit(1);
  }

  console.log(`Attaching build ${build.attributes.version} to appStoreVersion ${version.id}...`);
  const attach = await api.patch(`/appStoreVersions/${version.id}`, {
    data: {
      type: 'appStoreVersions',
      id: version.id,
      relationships: { build: { data: { type: 'builds', id: build.id } } },
    },
  });
  api.assertOk(attach, 'attaching build to appStoreVersion');

  console.log('Creating App Store review submission...');
  const submission = await api.post('/appStoreVersionSubmissions', {
    data: {
      type: 'appStoreVersionSubmissions',
      relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } },
    },
  });

  if (submission.status >= 200 && submission.status < 300) {
    console.log('Submitted for App Review.');
    console.log(JSON.stringify(submission.body.data, null, 2));
  } else {
    console.error('Submission failed. This usually means something required is still missing');
    console.error('(screenshots, app privacy declaration published, export compliance, age rating,');
    console.error('review contact info) — check App Store Connect > App Store tab for what is flagged red.');
    console.error(JSON.stringify(submission.body, null, 2));
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
