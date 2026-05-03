/**
 * Firestore 'buffs' koleksiyonuna örnek test verisi ekler.
 * Çalıştır: node seed_buffs.js
 *
 * Firebase CLI'nin kayıtlı OAuth token'ını kullanır.
 * Token süresi dolduysa `firebase login` ile yenilenebilir.
 */

const https = require('https');
const os = require('os');
const path = require('path');
const fs = require('fs');

const PROJECT_ID = 'kam-1a8ab';

// ---------- Firebase CLI token ----------

function getCliAccessToken() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (!fs.existsSync(configPath)) throw new Error('Firebase CLI config bulunamadı. `firebase login` çalıştırın.');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const token = config?.tokens?.access_token;
  if (!token) throw new Error('access_token bulunamadı. `firebase login` ile yeniden giriş yapın.');
  return token;
}

// ---------- Firestore REST ----------

function toFirestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'string')  return { stringValue: val };
  if (typeof val === 'number' && Number.isInteger(val)) return { integerValue: String(val) };
  if (typeof val === 'number')  return { doubleValue: val };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (Array.isArray(val))       return { arrayValue: { values: val.map(toFirestoreValue) } };
  if (typeof val === 'object')  return { mapValue: { fields: toFirestoreFields(val) } };
  return { stringValue: String(val) };
}

function toFirestoreFields(obj) {
  return Object.fromEntries(
    Object.entries(obj)
      .filter(([, v]) => v !== undefined)
      .map(([k, v]) => [k, toFirestoreValue(v)])
  );
}

function firestorePatch(accessToken, docId, fields) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ fields });
    const path = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/buffs/${docId}`;
    const req = https.request(
      {
        hostname: 'firestore.googleapis.com',
        path,
        method: 'PATCH',
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

// ---------- Örnek buff dokümanları ----------

const BUFFS = [
  {
    id: 'buff_battle_start_atk',
    name: 'Kut Öfkesi',
    description: 'Savaşın başında tüm kahramanlara +10 saldırı verir.',
    type: 'statChange',
    statType: 'attack',
    value: 10,
    duration: -1,
    targetType: 'allTeammates',
    triggerCondition: 'onBattleStart',
  },
  {
    id: 'buff_turn_start_atk',
    name: 'Bozkır Rüzgarı',
    description: 'Her tur başında tüm kahramanlara +5 saldırı verir, 3 tur sürer.',
    type: 'statChange',
    statType: 'attack',
    value: 5,
    duration: 3,
    targetType: 'allTeammates',
    triggerCondition: 'onTurnStart',
  },
  {
    id: 'buff_hp_below_def',
    name: 'Son Nefes Kalkanı',
    description: '%50 HP altına düşünce kendine +20 savunma verir, savaş boyunca.',
    type: 'statChange',
    statType: 'defense',
    value: 20,
    duration: -1,
    targetType: 'self',
    triggerCondition: 'onHpBelowPercent',
    triggerValue: 0.5,
  },
  {
    id: 'buff_dot_poison',
    name: 'Bozkır Zehri',
    description: 'Tur sonunda tüm düşmanlara 15 hasar veren zehir etkisi, 3 tur.',
    type: 'dot',
    value: -15,
    duration: 3,
    targetType: 'allEnemies',
    triggerCondition: 'onTurnEnd',
  },
  {
    id: 'buff_hot_regen',
    name: 'Şaman Şifası',
    description: 'Tur başında tüm kahramanlara 10 can yenileyen şifa etkisi, 4 tur.',
    type: 'hot',
    value: 10,
    duration: 4,
    targetType: 'allTeammates',
    triggerCondition: 'onTurnStart',
  },
  {
    id: 'buff_turn_end_def',
    name: 'Gece Kalkanı',
    description: 'Oyuncu turu bittiğinde tüm kahramanlara +8 savunma, 2 tur sürer.',
    type: 'statChange',
    statType: 'defense',
    value: 8,
    duration: 2,
    targetType: 'allTeammates',
    triggerCondition: 'onTurnEnd',
  },
];

// ---------- Main ----------

async function main() {
  const accessToken = getCliAccessToken();
  console.log('✓ Firebase CLI token alındı\n');

  for (const { id, ...fields } of BUFFS) {
    const res = await firestorePatch(accessToken, id, toFirestoreFields(fields));

    if (res.name) {
      console.log(`✓ ${id} — ${fields.name}`);
    } else {
      const msg = res?.error?.message ?? JSON.stringify(res).slice(0, 200);
      console.error(`✗ ${id}: ${msg}`);
      if (res?.error?.code === 401) {
        console.error('  → Token süresi dolmuş. `firebase login` çalıştırın.');
        process.exit(1);
      }
    }
  }

  console.log('\n✓ Tamamlandı. Firebase Console → Firestore → buffs koleksiyonunda görünmeli.');
}

main().catch(err => { console.error('Hata:', err.message); process.exit(1); });
