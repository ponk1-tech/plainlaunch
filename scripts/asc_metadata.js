#!/usr/bin/env node
// Pushes App Store metadata (name/subtitle/description/keywords/promotional text/what's new/
// privacy policy URL/age rating) from AppStore/metadata.json to App Store Connect via the API.
//
// Locale mapping: metadata.json's "ja" -> ASC locale "ja", "en-US" -> ASC locale "en-US".
//
// Safe to re-run: every write is "find existing localization for this locale, PATCH it; else
// POST a new one" — never duplicates.
'use strict';

const { loadMetadata, findAppOrExit, api } = require('./asc_common');

// Both appInfoLocalizations and appStoreVersionLocalizations reject GET_COLLECTION on their
// top-level, filtered list endpoint (confirmed live: 403 FORBIDDEN_ERROR, "Allowed operations
// are: CREATE, DELETE, GET_INSTANCE, UPDATE") — only their *parent's* nested relationship list
// (e.g. `/appInfos/{id}/appInfoLocalizations`) is readable. So: list unfiltered from the parent,
// match the locale client-side, then PATCH by id or POST a new one.
async function findOrCreate(basePath, createPath, locale, createBody, updateAttributes) {
  const list = await api.get(basePath);
  api.assertOk(list, `listing ${basePath}`);
  const existing = list.body.data.find((item) => item.attributes.locale === locale);
  if (existing) {
    if (Object.keys(updateAttributes).length > 0) {
      const patched = await api.patch(`${createPath}/${existing.id}`, {
        data: { type: existing.type, id: existing.id, attributes: updateAttributes },
      });
      api.assertOk(patched, `updating ${createPath}/${existing.id}`);
      return patched.body.data;
    }
    return existing;
  }
  const created = await api.post(createPath, createBody);
  api.assertOk(created, `creating in ${createPath}`);
  return created.body.data;
}

async function main() {
  const meta = loadMetadata();
  const app = await findAppOrExit(meta.bundleId);
  console.log(`App: ${app.id} (${app.attributes.bundleId})`);

  // --- App Info (name/subtitle/privacy policy URL), one appInfoLocalizations per locale ---
  const appInfos = await api.get(`/apps/${app.id}/appInfos`);
  api.assertOk(appInfos, 'listing appInfos');
  const appInfo = appInfos.body.data.find((i) => i.attributes.appStoreState !== 'READY_FOR_SALE') || appInfos.body.data[0];
  if (!appInfo) {
    console.error('No appInfo found for this app yet — open the app once in App Store Connect and retry.');
    process.exit(1);
  }
  console.log(`appInfo: ${appInfo.id} (state=${appInfo.attributes.appStoreState})`);

  for (const [locale, content] of Object.entries(meta.locales)) {
    console.log(`-- appInfoLocalizations [${locale}]`);
    await findOrCreate(
      `/appInfos/${appInfo.id}/appInfoLocalizations`,
      '/appInfoLocalizations',
      locale,
      {
        data: {
          type: 'appInfoLocalizations',
          attributes: { locale, name: content.name, subtitle: content.subtitle, privacyPolicyUrl: meta.privacyPolicyUrl },
          relationships: { appInfo: { data: { type: 'appInfos', id: appInfo.id } } },
        },
      },
      { name: content.name, subtitle: content.subtitle, privacyPolicyUrl: meta.privacyPolicyUrl }
    );
  }

  // --- Age rating: PlainLaunch has zero objectionable content of any kind, so every category is
  // "none". Field list confirmed live (2026-09) against this account's existing ageRatingDeclaration
  // schema — enum categories take "NONE", boolean categories take false, kidsAgeBand is null.
  const ageRatingRel = await api.get(`/appInfos/${appInfo.id}/ageRatingDeclaration`);
  if (ageRatingRel.status === 200 && ageRatingRel.body.data) {
    console.log('-- ageRatingDeclaration');
    const enumNoneFields = [
      'alcoholTobaccoOrDrugUseOrReferences', 'contests', 'gamblingSimulated', 'gunsOrOtherWeapons',
      'medicalOrTreatmentInformation', 'profanityOrCrudeHumor', 'sexualContentGraphicAndNudity',
      'sexualContentOrNudity', 'horrorOrFearThemes', 'matureOrSuggestiveThemes',
      'violenceCartoonOrFantasy', 'violenceRealisticProlongedGraphicOrSadistic', 'violenceRealistic',
    ];
    const booleanFalseFields = [
      'advertising', 'gambling', 'healthOrWellnessTopics', 'lootBox', 'messagingAndChat',
      'parentalControls', 'ageAssurance', 'socialMedia', 'socialMediaAgeRestricted',
      'unrestrictedWebAccess', 'userGeneratedContent',
    ];
    const attrs = { kidsAgeBand: null };
    for (const f of enumNoneFields) attrs[f] = 'NONE';
    for (const f of booleanFalseFields) attrs[f] = false;
    const patched = await api.patch(`/ageRatingDeclarations/${ageRatingRel.body.data.id}`, {
      data: { type: 'ageRatingDeclarations', id: ageRatingRel.body.data.id, attributes: attrs },
    });
    if (patched.status >= 200 && patched.status < 300) {
      console.log('   ok');
    } else {
      console.warn('   Age rating PATCH failed (non-fatal) — set it manually in App Store Connect:');
      console.warn('  ', JSON.stringify(patched.body));
    }
  }

  // --- App Store version + per-locale release notes/description/keywords ---
  const versions = await api.get(`/apps/${app.id}/appStoreVersions?filter[versionString]=1.0.0&filter[platform]=IOS`);
  api.assertOk(versions, 'listing appStoreVersions');
  let version = versions.body.data[0];
  if (!version) {
    console.log('-- creating appStoreVersion 1.0.0');
    const created = await api.post('/appStoreVersions', {
      data: {
        type: 'appStoreVersions',
        attributes: {
          platform: 'IOS',
          versionString: '1.0.0',
          releaseType: 'MANUAL', // hold for manual release after approval, not auto-release
          usesIdfa: false, // no ads, no IDFA use anywhere in the app
          copyright: `${new Date().getFullYear()} Ponk1 Tech`,
        },
        relationships: { app: { data: { type: 'apps', id: app.id } } },
      },
    });
    api.assertOk(created, 'creating appStoreVersion');
    version = created.body.data;
  }
  console.log(`appStoreVersion: ${version.id}`);

  for (const [locale, content] of Object.entries(meta.locales)) {
    console.log(`-- appStoreVersionLocalizations [${locale}]`);
    const attrs = {
      description: content.description,
      keywords: content.keywords,
      promotionalText: content.promotionalText,
      whatsNew: meta.whatsNew[locale === 'en-US' ? 'en' : locale] || meta.whatsNew.en,
      supportUrl: meta.supportUrl,
      marketingUrl: meta.marketingUrl,
    };
    await findOrCreate(
      `/appStoreVersions/${version.id}/appStoreVersionLocalizations`,
      '/appStoreVersionLocalizations',
      locale,
      {
        data: {
          type: 'appStoreVersionLocalizations',
          attributes: { locale, ...attrs },
          relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } },
        },
      },
      attrs
    );
  }

  console.log('Metadata push complete.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
