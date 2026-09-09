#!/usr/bin/env node
// Shared App Store Connect API client used by the scripts/asc_*.js release scripts.
//
// Auth: reads ASC_KEY_ID / ASC_ISSUER_ID / ASC_PRIVATE_KEY_PATH from the environment (see
// README "App Store Connect API setup"). The private key file itself is never read into a JS
// string that gets logged or persisted anywhere other than the signature it produces.
'use strict';

const crypto = require('crypto');
const fs = require('fs');
const https = require('https');

const BASE_URL = 'api.appstoreconnect.apple.com';

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`Missing required environment variable: ${name}`);
    console.error('See README "App Store Connect API setup" for how to obtain and set it.');
    process.exit(1);
  }
  return value;
}

function b64url(buf) {
  return Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function derToRawEcdsaSignature(der) {
  let offset = 2;
  if (der[0] !== 0x30) throw new Error('Invalid DER signature');
  if (der[offset] !== 0x02) throw new Error('Invalid DER (r)');
  const rLen = der[offset + 1];
  const rStart = offset + 2;
  const r = der.slice(rStart, rStart + rLen);
  offset = rStart + rLen;
  if (der[offset] !== 0x02) throw new Error('Invalid DER (s)');
  const sLen = der[offset + 1];
  const sStart = offset + 2;
  const s = der.slice(sStart, sStart + sLen);

  function toFixed32(buf) {
    let out = buf;
    if (out.length > 0 && out[0] === 0x00 && out.length > 32) out = out.slice(1);
    if (out.length > 32) out = out.slice(out.length - 32);
    if (out.length < 32) out = Buffer.concat([Buffer.alloc(32 - out.length, 0), out]);
    return out;
  }
  return Buffer.concat([toFixed32(r), toFixed32(s)]);
}

/** Generates a fresh, short-lived (15 min) ES256 JWT. Never cached to disk. */
function generateToken() {
  const keyId = requireEnv('ASC_KEY_ID');
  const issuerId = requireEnv('ASC_ISSUER_ID');
  const keyPath = requireEnv('ASC_PRIVATE_KEY_PATH');
  const privateKey = fs.readFileSync(keyPath, 'utf8');

  const header = { alg: 'ES256', kid: keyId, typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const payload = { iss: issuerId, iat: now, exp: now + 60 * 15, aud: 'appstoreconnect-v1' };

  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const sign = crypto.createSign('SHA256');
  sign.update(signingInput);
  sign.end();
  const der = sign.sign({ key: privateKey, dsaEncoding: 'der' });
  const raw = derToRawEcdsaSignature(der);
  return `${signingInput}.${b64url(raw)}`;
}

/** Minimal JSON:API request helper. Returns { status, body } — never throws on non-2xx. */
function request(method, path, body) {
  return new Promise((resolve, reject) => {
    const token = generateToken();
    const payload = body ? JSON.stringify(body) : undefined;
    const req = https.request(
      {
        hostname: BASE_URL,
        path: path.startsWith('/v1') ? path : `/v1${path}`,
        method,
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
          ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          let parsed = null;
          if (data) {
            try {
              parsed = JSON.parse(data);
            } catch (e) {
              parsed = { raw: data };
            }
          }
          resolve({ status: res.statusCode, body: parsed });
        });
      }
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function get(path) {
  return request('GET', path);
}
async function post(path, body) {
  return request('POST', path, body);
}
async function patch(path, body) {
  return request('PATCH', path, body);
}
async function del(path) {
  return request('DELETE', path);
}

function assertOk(result, context) {
  if (result.status >= 200 && result.status < 300) return result;
  console.error(`ASC API error during ${context}: HTTP ${result.status}`);
  console.error(JSON.stringify(result.body, null, 2));
  process.exit(1);
}

module.exports = { get, post, patch, del, assertOk, generateToken };
