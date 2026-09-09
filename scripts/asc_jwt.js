#!/usr/bin/env node
// Generates a short-lived ES256 JWT for the App Store Connect API.
// Reads ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_PATH from env.
const crypto = require('crypto');
const fs = require('fs');

function b64url(input) {
  return Buffer.from(input).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

const keyId = process.env.ASC_KEY_ID;
const issuerId = process.env.ASC_ISSUER_ID;
const keyPath = process.env.ASC_PRIVATE_KEY_PATH;
if (!keyId || !issuerId || !keyPath) {
  console.error('Missing ASC_KEY_ID / ASC_ISSUER_ID / ASC_PRIVATE_KEY_PATH');
  process.exit(1);
}
const privateKey = fs.readFileSync(keyPath, 'utf8');

const header = { alg: 'ES256', kid: keyId, typ: 'JWT' };
const now = Math.floor(Date.now() / 1000);
const payload = {
  iss: issuerId,
  iat: now,
  exp: now + 60 * 15, // 15 minutes (max 20 allowed)
  aud: 'appstoreconnect-v1',
};

const encodedHeader = b64url(JSON.stringify(header));
const encodedPayload = b64url(JSON.stringify(payload));
const signingInput = `${encodedHeader}.${encodedPayload}`;

const sign = crypto.createSign('SHA256');
sign.update(signingInput);
sign.end();
// ES256 requires the raw (r||s) signature format, not DER.
const derSig = sign.sign({ key: privateKey, dsaEncoding: 'der' });
const jose = require('crypto').createSign; // no-op to keep lints quiet

// Convert DER ECDSA signature to raw r||s (32 bytes each for P-256)
function derToRaw(der) {
  let offset = 2; // skip SEQUENCE tag+len
  if (der[0] !== 0x30) throw new Error('Invalid DER signature');
  // r
  if (der[offset] !== 0x02) throw new Error('Invalid DER (r)');
  let rLen = der[offset + 1];
  let rStart = offset + 2;
  let r = der.slice(rStart, rStart + rLen);
  offset = rStart + rLen;
  // s
  if (der[offset] !== 0x02) throw new Error('Invalid DER (s)');
  let sLen = der[offset + 1];
  let sStart = offset + 2;
  let s = der.slice(sStart, sStart + sLen);

  function toFixed32(buf) {
    buf = buf.filter((b, i) => !(i === 0 && b === 0x00 && buf.length > 32)); // strip leading zero padding byte if present
    buf = Buffer.from(buf);
    if (buf.length > 32) buf = buf.slice(buf.length - 32);
    if (buf.length < 32) buf = Buffer.concat([Buffer.alloc(32 - buf.length, 0), buf]);
    return buf;
  }
  return Buffer.concat([toFixed32(r), toFixed32(s)]);
}

const rawSig = derToRaw(derSig);
const encodedSig = rawSig.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

console.log(`${signingInput}.${encodedSig}`);
