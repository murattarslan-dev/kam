/**
 * Firestore'daki tüm hero dokümanlarını listeler.
 * Çalıştır: node fetch_heroes.js
 */
const https = require('https');
const os = require('os');
const path = require('path');
const fs = require('fs');
const querystring = require('querystring');

const PROJECT_ID = 'kam-1a8ab';
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

async function getFreshAccessToken() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const refreshToken = config?.tokens?.refresh_token;
  const body = querystring.stringify({
    grant_type: 'refresh_token',
    client_id: CLI_CLIENT_ID,
    client_secret: CLI_CLIENT_SECRET,
    refresh_token: refreshToken,
  });
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'oauth2.googleapis.com', path: '/token', method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': Buffer.byteLength(body) },
    }, res => {
      let raw = '';
      res.on('data', c => raw += c);
      res.on('end', () => {
        const data = JSON.parse(raw);
        if (data.error) reject(new Error(data.error_description || data.error));
        else resolve(data.access_token);
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function firestoreGet(token, path) {
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}`,
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` },
    }, res => {
      let raw = '';
      res.on('data', c => raw += c);
      res.on('end', () => resolve(JSON.parse(raw)));
    });
    req.on('error', reject);
    req.end();
  });
}

function str(field) { return field?.stringValue ?? field?.integerValue ?? '?'; }

async function main() {
  const token = await getFreshAccessToken();
  const data = await firestoreGet(token, 'heroes');
  const docs = data.documents ?? [];
  console.log(`\n${docs.length} kahraman bulundu:\n`);
  for (const doc of docs) {
    const id = doc.name.split('/').pop();
    const f = doc.fields ?? {};
    const name = str(f.name);
    const element = str(f.element);
    const role = str(f.role);
    const skills = (f.skillCards?.arrayValue?.values ?? []).map(sv => {
      const sf = sv.mapValue?.fields ?? {};
      return `${str(sf.name)}(${str(sf.type)})`;
    });
    console.log(`  ID: ${id}`);
    console.log(`  Ad: ${name}  Element: ${element}  Sınıf: ${role}`);
    console.log(`  Tözler: ${skills.join(', ') || '—'}`);
    console.log();
  }
}
main().catch(e => { console.error(e.message); process.exit(1); });
