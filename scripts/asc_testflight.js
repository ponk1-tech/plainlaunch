#!/usr/bin/env node
// Polls the most recently uploaded build until App Store Connect finishes processing it, then
// adds it to the internal TestFlight group ("App Store Connect Users", auto-created for every
// app) so it's immediately installable by internal testers. Does not touch external testing /
// Beta App Review — internal TestFlight is enough for this project's first pass (see README).
'use strict';

const { loadMetadata, findAppOrExit, api } = require('./asc_common');

const POLL_INTERVAL_MS = 30_000;
const POLL_TIMEOUT_MS = 30 * 60_000;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const meta = loadMetadata();
  const app = await findAppOrExit(meta.bundleId);

  console.log('Waiting for the most recent build to finish processing...');
  const deadline = Date.now() + POLL_TIMEOUT_MS;
  let build = null;
  while (Date.now() < deadline) {
    const result = await api.get(`/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=1`);
    api.assertOk(result, 'listing builds');
    build = result.body.data[0];
    if (!build) {
      console.log('  no build found yet, waiting...');
    } else {
      const state = build.attributes.processingState;
      console.log(`  build ${build.attributes.version}: ${state}`);
      if (state === 'VALID') break;
      if (state === 'INVALID' || state === 'FAILED') {
        console.error('Build failed processing. Check App Store Connect > TestFlight for the reason.');
        process.exit(1);
      }
    }
    await sleep(POLL_INTERVAL_MS);
  }
  if (!build || build.attributes.processingState !== 'VALID') {
    console.error('Timed out waiting for build processing.');
    process.exit(1);
  }
  console.log(`Build ${build.id} (version ${build.attributes.version}) is VALID.`);

  const groups = await api.get(`/apps/${app.id}/betaGroups?filter[isInternalGroup]=true`);
  api.assertOk(groups, 'listing internal beta groups');
  const internalGroup = groups.body.data[0];
  if (!internalGroup) {
    console.error('No internal beta group found. Add at least one internal tester in App Store Connect > TestFlight > Internal Testing first.');
    process.exit(1);
  }

  const attach = await api.post(`/betaGroups/${internalGroup.id}/relationships/builds`, {
    data: [{ type: 'builds', id: build.id }],
  });
  if (attach.status >= 200 && attach.status < 300) {
    console.log(`Build attached to internal group "${internalGroup.attributes.name}". Internal testers can install it now.`);
  } else {
    console.error('Failed to attach build to internal group:', JSON.stringify(attach.body));
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
