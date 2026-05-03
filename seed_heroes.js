/**
 * Kullanıcının heroes koleksiyonuna 3 yeni kahraman referansı ekler.
 * Çalıştır: node seed_heroes.js
 */

const https = require('https');
const os = require('os');
const path = require('path');
const fs = require('fs');

const PROJECT_ID = 'kam-1a8ab';
const USER_ID = 'IKATT9z1LnPFpxuU0wVED4NgyC03';

const querystring = require('querystring');

// ---------- Firebase CLI token ----------

const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

async function getFreshAccessToken() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (!fs.existsSync(configPath)) throw new Error('Firebase CLI config bulunamadı. `firebase login` çalıştırın.');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const refreshToken = config?.tokens?.refresh_token;
  if (!refreshToken) throw new Error('refresh_token bulunamadı. `firebase login` ile giriş yapın.');

  const body = querystring.stringify({
    grant_type: 'refresh_token',
    client_id: CLI_CLIENT_ID,
    client_secret: CLI_CLIENT_SECRET,
    refresh_token: refreshToken,
  });

  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': Buffer.byteLength(body) },
    }, res => {
      let raw = '';
      res.on('data', c => (raw += c));
      res.on('end', () => {
        const data = JSON.parse(raw);
        if (data.access_token) resolve(data.access_token);
        else reject(new Error('Token yenilenemedi: ' + JSON.stringify(data)));
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// ---------- Firestore REST helpers ----------

function firestoreGet(accessToken, docPath) {
  return new Promise((resolve, reject) => {
    const reqPath = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${docPath}?pageSize=100`;
    const req = https.request(
      {
        hostname: 'firestore.googleapis.com',
        path: reqPath,
        method: 'GET',
        headers: { 'Authorization': `Bearer ${accessToken}` },
      },
      res => {
        let raw = '';
        res.on('data', c => (raw += c));
        res.on('end', () => {
          try { resolve(JSON.parse(raw)); }
          catch { resolve(raw); }
        });
      }
    );
    req.on('error', reject);
    req.end();
  });
}

function firestorePost(accessToken, collectionPath, fields) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ fields });
    const reqPath = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collectionPath}`;
    const req = https.request(
      {
        hostname: 'firestore.googleapis.com',
        path: reqPath,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
          'Authorization': `Bearer ${accessToken}`,
        },
      },
      res => {
        let raw = '';
        res.on('data', c => (raw += c));
        res.on('end', () => {
          try { resolve(JSON.parse(raw)); }
          catch { resolve(raw); }
        });
      }
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function extractDocId(name) {
  return name.split('/').pop();
}

function getStringField(doc, field) {
  return doc.fields?.[field]?.stringValue ?? '';
}

// ---------- Main ----------

async function main() {
  const accessToken = await getFreshAccessToken();
  console.log('✓ Firebase CLI token yenilendi\n');

  // 1. Tüm global kahramanları listele
  const heroesRes = await firestoreGet(accessToken, 'heroes');
  const allGlobalHeroes = (heroesRes.documents ?? []).map(doc => ({
    id: extractDocId(doc.name),
    name: getStringField(doc, 'name'),
  }));
  console.log(`✓ ${allGlobalHeroes.length} global kahraman bulundu`);

  if (allGlobalHeroes.length === 0) {
    console.error('✗ Global kahraman bulunamadı. heroes koleksiyonu boş olabilir.');
    process.exit(1);
  }

  // 2. Kullanıcının mevcut kahramanlarını listele
  const userHeroesRes = await firestoreGet(accessToken, `users/${USER_ID}/heroes`);
  const existingHeroIds = new Set(
    (userHeroesRes.documents ?? []).map(doc => getStringField(doc, 'hero_id')).filter(Boolean)
  );
  console.log(`✓ Kullanıcının mevcut ${existingHeroIds.size} kahramanı var: [${[...existingHeroIds].join(', ')}]\n`);

  // 3. Kullanıcının sahip olmadığı ilk 3 global kahramanı seç
  const newHeroes = allGlobalHeroes.filter(h => !existingHeroIds.has(h.id)).slice(0, 3);

  if (newHeroes.length === 0) {
    console.log('ℹ Kullanıcı zaten tüm kahramanlara sahip veya yeni eklenecek kahraman yok.');
    process.exit(0);
  }

  console.log(`Eklenecek ${newHeroes.length} kahraman:\n${newHeroes.map(h => `  - ${h.name} (${h.id})`).join('\n')}\n`);

  // 4. Kullanıcının heroes koleksiyonuna ekle
  for (const hero of newHeroes) {
    const fields = {
      hero_id: { stringValue: hero.id },
      xp: { integerValue: '0' },
    };
    const res = await firestorePost(accessToken, `users/${USER_ID}/heroes`, fields);

    if (res.name) {
      const newDocId = extractDocId(res.name);
      console.log(`✓ Eklendi: ${hero.name} → doc ID: ${newDocId}`);
    } else {
      const msg = res?.error?.message ?? JSON.stringify(res).slice(0, 200);
      console.error(`✗ ${hero.name}: ${msg}`);
      if (res?.error?.code === 401) {
        console.error('  → Token süresi dolmuş. `firebase login` çalıştırın.');
        process.exit(1);
      }
    }
  }

  console.log('\n✓ Tamamlandı.');
}

main().catch(err => { console.error('Hata:', err.message); process.exit(1); });
