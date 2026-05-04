/**
 * Firestore'a şunları ekler / günceller:
 *   1. Pasif buff dokümanları (buffs koleksiyonu)
 *   2. Her kahramana Töz (skillCards) kartları (heroes koleksiyonu)
 *
 * Çalıştır: node seed_new_content.js
 */

const https      = require('https');
const os         = require('os');
const path       = require('path');
const fs         = require('fs');
const querystring = require('querystring');

const PROJECT_ID       = 'kam-1a8ab';
const CLI_CLIENT_ID    = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

// ── Hero ID'leri ─────────────────────────────────────────────────────────────
const H = {
  erlikHan:   '2RY6tYBy5hyyF8thzx0j',  // dark   / tank
  tulpar:     '2vlIvL79VOdGhKpzcXQa',  // wind   / support
  umayAna:    '6vqxjf3p2K19kNmFLypj',  // forest / support
  tasAdam:    'IhcolbHPAfecijwfZ84I',  // steppe / warrior
  kizagan:    'UrtygLBhuGZd79afHUnY',  // fire   / warrior
  kayraHan:   'XX8UsvcurRCpvIjoJQNJ',  // water  / mage
  magaraIyesi:'eYzAPMaTkAOfE5nOUjjn',  // steppe / tank
  bozkurt:    'gqEClK2BOjqD01jJpZaT',  // steppe / warrior
  mergen:     'nbttdGBwteHX2bFCXkJU',  // forest / warrior
  oguzKagan:  'ukqOHNh1tdPpzudMIhWV',  // steppe / warrior
  asena:      'vXESZfAQFqEp3ogCDkjI',  // wind   / mage
  tepegoz:    'xS48akFe8j8HpWCNsUYB',  // dark   / tank
};

// ── Token ────────────────────────────────────────────────────────────────────
async function getFreshAccessToken() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const body = querystring.stringify({
    grant_type:    'refresh_token',
    client_id:     CLI_CLIENT_ID,
    client_secret: CLI_CLIENT_SECRET,
    refresh_token: config?.tokens?.refresh_token,
  });
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'oauth2.googleapis.com', path: '/token', method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Content-Length': Buffer.byteLength(body) },
    }, res => {
      let raw = '';
      res.on('data', c => raw += c);
      res.on('end', () => {
        const d = JSON.parse(raw);
        d.error ? reject(new Error(d.error_description || d.error)) : resolve(d.access_token);
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// ── Firestore REST yardımcıları ───────────────────────────────────────────────
function toValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'boolean')          return { booleanValue: val };
  if (typeof val === 'number' && Number.isInteger(val)) return { integerValue: String(val) };
  if (typeof val === 'number')           return { doubleValue: val };
  if (typeof val === 'string')           return { stringValue: val };
  if (Array.isArray(val))                return { arrayValue: { values: val.map(toValue) } };
  if (typeof val === 'object')           return { mapValue: { fields: toFields(val) } };
  return { stringValue: String(val) };
}
function toFields(obj) {
  return Object.fromEntries(
    Object.entries(obj).filter(([,v]) => v !== undefined).map(([k,v]) => [k, toValue(v)])
  );
}

function patch(token, collection, docId, fields, maskFields) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ fields: toFields(fields) });
    let urlPath = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}`;
    if (maskFields) urlPath += '?' + maskFields.map(f => `updateMask.fieldPaths=${f}`).join('&');
    const req = https.request({
      hostname: 'firestore.googleapis.com', path: urlPath, method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body), Authorization: `Bearer ${token}` },
    }, res => {
      let raw = '';
      res.on('data', c => raw += c);
      res.on('end', () => { try { resolve(JSON.parse(raw)); } catch { resolve(raw); } });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// ── 1. PASIF BUFF DOKÜMANLARI ─────────────────────────────────────────────────
//
// prerequisites: tüm koşulların TÜMÜ sağlanmalı (AND mantığı).
// heroIdIs        → kahramanın kendisi bu ID olmalı
// hasTeammateWithId → bu ID'deki kahraman aynı takımda ve canlı olmalı
// heroElementIs   → kahramanın elementi eşleşmeli
// heroRoleIs      → kahramanın sınıfı eşleşmeli
// hasTeammateWithElement / hasTeammateWithRole
// hasEnemyWithElement / hasEnemyWithRole

const PASSIVE_BUFFS = [

  // ── Element Sinerjileri ──────────────────────────────────────────────────

  {
    id: 'passive_steppe_forest_synergy',
    name: 'Bozkır-Orman Sinerji',
    description: 'Takımda orman elementli bir kahraman varken bozkır kahramanı +15 saldırı alır.',
    type: 'statChange', statType: 'attack', value: 15,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroElementIs',          value: 'steppe' },
      { type: 'hasTeammateWithElement', value: 'forest' },
    ],
  },

  {
    id: 'passive_wind_forest_debuff',
    name: 'Orman Baskısı',
    description: 'Rakip takımda orman elementli kahraman varken rüzgar kahramanının saldırısı -10 düşer.',
    type: 'statChange', statType: 'attack', value: -10,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroElementIs',       value: 'wind' },
      { type: 'hasEnemyWithElement', value: 'forest' },
    ],
  },

  {
    id: 'passive_fire_water_disadvantage',
    name: 'Soğuk Dalga',
    description: 'Rakip takımda su elementli kahraman varken ateş kahramanının saldırısı -12 düşer.',
    type: 'statChange', statType: 'attack', value: -12,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroElementIs',       value: 'fire' },
      { type: 'hasEnemyWithElement', value: 'water' },
    ],
  },

  {
    id: 'passive_dark_steppe_bonus',
    name: 'Karanlık Bozkır',
    description: 'Takımda bozkır elementli kahraman varken karanlık kahramanı +12 savunma alır.',
    type: 'statChange', statType: 'defense', value: 12,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroElementIs',          value: 'dark' },
      { type: 'hasTeammateWithElement', value: 'steppe' },
    ],
  },

  // ── Sınıf Sinerjileri ────────────────────────────────────────────────────

  {
    id: 'passive_tank_damage_soak',
    name: 'Kalkan Duvarı',
    description: 'Tank sınıfı kahramanlar takım arkadaşlarına gelen hasarın %30\'unu üstlenir.',
    type: 'damageSoak', value: 30,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroRoleIs', value: 'tank' },
    ],
  },

  {
    id: 'passive_support_heal',
    name: 'Kut Şifası',
    description: 'Takımda destek sınıfı kahraman varken takım arkadaşları her tur sonu +5 can yeniler.',
    type: 'hot', value: 5,
    duration: -1, triggerCondition: 'passive', targetType: 'allTeammates',
    prerequisites: [
      { type: 'hasTeammateWithRole', value: 'support' },
    ],
  },

  {
    id: 'passive_warrior_duo_atk',
    name: 'Savaş Kardeşliği',
    description: 'Takımda en az iki savaşçı sınıfı kahraman varken her savaşçı +10 saldırı alır.',
    type: 'statChange', statType: 'attack', value: 10,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroRoleIs',             value: 'warrior' },
      { type: 'hasTeammateWithRole',    value: 'warrior' },
    ],
  },

  {
    id: 'passive_mage_support_combo',
    name: 'Büyücü-Şaman Ritmi',
    description: 'Takımda destek varken büyücü +15 saldırı alır.',
    type: 'statChange', statType: 'attack', value: 15,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroRoleIs',          value: 'mage'    },
      { type: 'hasTeammateWithRole', value: 'support' },
    ],
  },

  // ── İkili Kahraman Sinerjileri ────────────────────────────────────────────

  // Dolunay Ruhu: Erlik Han + Bozkurt
  {
    id: 'dolunay_ruhu_erlik',
    name: 'Dolunay Ruhu',
    description: 'Bozkurt ile aynı takımda savaşınca karanlık güç uyanır. +25 saldırı.',
    type: 'statChange', statType: 'attack', value: 25,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.erlikHan },
      { type: 'hasTeammateWithId', value: H.bozkurt  },
    ],
  },
  {
    id: 'dolunay_ruhu_bozkurt',
    name: 'Dolunay Ruhu',
    description: 'Erlik Han ile aynı takımda savaşınca kurt içgüdüsü keskinleşir. +25 saldırı.',
    type: 'statChange', statType: 'attack', value: 25,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.bozkurt  },
      { type: 'hasTeammateWithId', value: H.erlikHan },
    ],
  },

  // Karanlık İkili: Erlik Han + Tepegöz
  {
    id: 'karanlik_ikili_erlik',
    name: 'Karanlık İkili',
    description: 'Tepegöz ile aynı takımda karanlık güç katlanır. +20 savunma.',
    type: 'statChange', statType: 'defense', value: 20,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.erlikHan },
      { type: 'hasTeammateWithId', value: H.tepegoz  },
    ],
  },
  {
    id: 'karanlik_ikili_tepegoz',
    name: 'Karanlık İkili',
    description: 'Erlik Han ile aynı takımda Tepegöz\'ün karanlık gözü keskinleşir. +20 savunma.',
    type: 'statChange', statType: 'defense', value: 20,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.tepegoz  },
      { type: 'hasTeammateWithId', value: H.erlikHan },
    ],
  },

  // Orman Birliği: Umay Ana + Mergen
  {
    id: 'orman_birligi_umay',
    name: 'Orman Birliği',
    description: 'Mergen ile birlikte savaşınca Umay Ana\'nın doğa gücü artar. +18 saldırı.',
    type: 'statChange', statType: 'attack', value: 18,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.umayAna },
      { type: 'hasTeammateWithId', value: H.mergen  },
    ],
  },
  {
    id: 'orman_birligi_mergen',
    name: 'Orman Birliği',
    description: 'Umay Ana ile birlikte savaşınca Mergen\'in okları orman ruhundan güç alır. +18 saldırı.',
    type: 'statChange', statType: 'attack', value: 18,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.mergen  },
      { type: 'hasTeammateWithId', value: H.umayAna },
    ],
  },

  // Rüzgar Ruhu: Tulpar + Asena
  {
    id: 'ruzgar_ruhu_tulpar',
    name: 'Rüzgar Ruhu',
    description: 'Asena ile aynı takımda rüzgar enerjisi birleşir. +15 saldırı.',
    type: 'statChange', statType: 'attack', value: 15,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.tulpar },
      { type: 'hasTeammateWithId', value: H.asena  },
    ],
  },
  {
    id: 'ruzgar_ruhu_asena',
    name: 'Rüzgar Ruhu',
    description: 'Tulpar ile aynı takımda Asena\'nın büyü gücü kanatlanır. +15 saldırı.',
    type: 'statChange', statType: 'attack', value: 15,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.asena  },
      { type: 'hasTeammateWithId', value: H.tulpar },
    ],
  },

  // ── Üçlü Kahraman Sinerjisi ───────────────────────────────────────────────

  // Bozkır Üçlüsü: Bozkurt + Oğuz Kağan + Taş Adam (üç bozkır savaşçısı)
  {
    id: 'bozkiruclu_bozkurt',
    name: 'Bozkır Üçlüsü',
    description: 'Oğuz Kağan ve Taş Adam ile aynı takımda bozkır ruhu üç katına çıkar. +30 saldırı.',
    type: 'statChange', statType: 'attack', value: 30,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.bozkurt   },
      { type: 'hasTeammateWithId', value: H.oguzKagan },
      { type: 'hasTeammateWithId', value: H.tasAdam   },
    ],
  },
  {
    id: 'bozkiruclu_oguz',
    name: 'Bozkır Üçlüsü',
    description: 'Bozkurt ve Taş Adam ile aynı takımda Oğuz Kağan\'ın liderlik gücü patlama yapar. +30 saldırı.',
    type: 'statChange', statType: 'attack', value: 30,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.oguzKagan },
      { type: 'hasTeammateWithId', value: H.bozkurt   },
      { type: 'hasTeammateWithId', value: H.tasAdam   },
    ],
  },
  {
    id: 'bozkiruclu_tasadam',
    name: 'Bozkır Üçlüsü',
    description: 'Bozkurt ve Oğuz Kağan ile aynı takımda Taş Adam\'ın kayası yenilmez olur. +30 saldırı.',
    type: 'statChange', statType: 'attack', value: 30,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.tasAdam   },
      { type: 'hasTeammateWithId', value: H.bozkurt   },
      { type: 'hasTeammateWithId', value: H.oguzKagan },
    ],
  },

  // Kut Üçlemesi: Erlik Han + Bozkurt + Umay Ana (karanlık + bozkır + orman dengesi)
  {
    id: 'kut_uclemesi_erlik',
    name: 'Kut Üçlemesi',
    description: 'Bozkurt ve Umay Ana ile aynı takımda Kut enerjisi zirveye ulaşır. +20 saldırı, +15 savunma (saldırı olarak uygulanır).',
    type: 'statChange', statType: 'attack', value: 20,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.erlikHan },
      { type: 'hasTeammateWithId', value: H.bozkurt  },
      { type: 'hasTeammateWithId', value: H.umayAna  },
    ],
  },
  {
    id: 'kut_uclemesi_bozkurt',
    name: 'Kut Üçlemesi',
    description: 'Erlik Han ve Umay Ana ile aynı takımda Kut enerjisi zirveye ulaşır. +20 saldırı.',
    type: 'statChange', statType: 'attack', value: 20,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.bozkurt  },
      { type: 'hasTeammateWithId', value: H.erlikHan },
      { type: 'hasTeammateWithId', value: H.umayAna  },
    ],
  },
  {
    id: 'kut_uclemesi_umay',
    name: 'Kut Üçlemesi',
    description: 'Erlik Han ve Bozkurt ile aynı takımda Umay Ana\'nın şifa gücü katlanır. +20 saldırı.',
    type: 'statChange', statType: 'attack', value: 20,
    duration: -1, triggerCondition: 'passive', targetType: 'self',
    prerequisites: [
      { type: 'heroIdIs',          value: H.umayAna  },
      { type: 'hasTeammateWithId', value: H.erlikHan },
      { type: 'hasTeammateWithId', value: H.bozkurt  },
    ],
  },
];

// ── 2. KAHRAMAN TÖZ KARTLARI ─────────────────────────────────────────────────
//
// prerequisite alanı (SkillPrerequisite):
//   target:           "teammate" | "opponent"
//   requiredElements: [...element adları]   // boş = herhangi
//   requiredRoles:    [...sınıf adları]     // boş = herhangi
//   minCount:         kaç tane gerekli
//
// type: "heal" | "attackBuff" | "defenseBuff"
// cost: kut maliyeti

const HERO_SKILLS = {

  [H.erlikHan]: [
    {
      id: 'erlik_karanlik_kalkan',
      name: 'Karanlık Kalkan',
      description: 'Yeraltının gücüyle zırhını pekiştirir.',
      type: 'defenseBuff', cost: 2, value: 35,
    },
    {
      id: 'erlik_yeraltı_gazabi',
      name: 'Yeraltı Gazabı',
      description: 'Takımda karanlık bir dost olduğunda yeraltı gücü patlar. +40 saldırı.',
      type: 'attackBuff', cost: 3, value: 40,
      prerequisite: { target: 'teammate', requiredElements: ['dark'], requiredRoles: [], minCount: 1 },
    },
  ],

  [H.bozkurt]: [
    {
      id: 'bozkurt_kurt_saldirisi',
      name: 'Kurt Saldırısı',
      description: 'Gözleri kızaran Bozkurt saldırısını ikiye katlar.',
      type: 'attackBuff', cost: 2, value: 35,
    },
    {
      id: 'bozkurt_suru_gudüsü',
      name: 'Sürü Güdüsü',
      description: 'Takımda bozkır savaşçıları varken sürü içgüdüsü uyanır. +50 saldırı.',
      type: 'attackBuff', cost: 4, value: 50,
      prerequisite: { target: 'teammate', requiredElements: ['steppe'], requiredRoles: ['warrior'], minCount: 1 },
    },
  ],

  [H.umayAna]: [
    {
      id: 'umay_ana_sifasi',
      name: 'Ana Şifası',
      description: 'Umay Ana\'nın doğa gücü yaraları iyileştirir.',
      type: 'heal', cost: 2, value: 50,
    },
    {
      id: 'umay_orman_korumasi',
      name: 'Orman Koruması',
      description: 'Takımda orman ruhu taşıyan bir yoldaş varken savunma kalkanı güçlenir. +30 savunma.',
      type: 'defenseBuff', cost: 3, value: 30,
      prerequisite: { target: 'teammate', requiredElements: ['forest'], requiredRoles: [], minCount: 1 },
    },
  ],

  [H.tulpar]: [
    {
      id: 'tulpar_kanatli_sifa',
      name: 'Kanatlı Şifa',
      description: 'Rüzgar kanatlarıyla dostuna can taşır.',
      type: 'heal', cost: 2, value: 40,
    },
    {
      id: 'tulpar_ruzgar_darbesi',
      name: 'Rüzgar Darbesi',
      description: 'Takımda rüzgar büyücüsü olduğunda Tulpar\'ın hızı sınır tanımaz. +30 saldırı.',
      type: 'attackBuff', cost: 3, value: 30,
      prerequisite: { target: 'teammate', requiredElements: ['wind'], requiredRoles: ['mage'], minCount: 1 },
    },
  ],

  [H.asena]: [
    {
      id: 'asena_firtina_saldirisi',
      name: 'Fırtına Saldırısı',
      description: 'Asena fırtına büyüsünü serbest bırakır.',
      type: 'attackBuff', cost: 3, value: 40,
    },
    {
      id: 'asena_ruzgar_kardeslik',
      name: 'Rüzgar Kardeşliği',
      description: 'Takımda rüzgar destek varken Asena\'nın büyüsü kanatlanır. +55 saldırı.',
      type: 'attackBuff', cost: 4, value: 55,
      prerequisite: { target: 'teammate', requiredElements: ['wind'], requiredRoles: ['support'], minCount: 1 },
    },
  ],

  [H.magaraIyesi]: [
    {
      id: 'magara_kaya_duvari',
      name: 'Kaya Duvarı',
      description: 'Topraktan sarsılmaz bir kalkan çağırır.',
      type: 'defenseBuff', cost: 2, value: 40,
    },
    {
      id: 'magara_toprak_gucu',
      name: 'Toprak Gücü',
      description: 'Takımda bozkır savaşçısı olduğunda Mağara İyesi\'nin gücü coşar. +25 saldırı.',
      type: 'attackBuff', cost: 3, value: 25,
      prerequisite: { target: 'teammate', requiredElements: ['steppe'], requiredRoles: ['warrior'], minCount: 1 },
    },
  ],

  [H.kayraHan]: [
    {
      id: 'kayra_buyuk_sifa',
      name: 'Büyük Şifa',
      description: 'Kayra Han suyun iyileştirici gücünü serbest bırakır.',
      type: 'heal', cost: 3, value: 65,
    },
    {
      id: 'kayra_su_kalkani',
      name: 'Su Kalkanı',
      description: 'Suyun akışı bir savunma zırhı oluşturur.',
      type: 'defenseBuff', cost: 2, value: 25,
    },
  ],

  [H.mergen]: [
    {
      id: 'mergen_nisan_al',
      name: 'Nişan Al',
      description: 'Mergen hedefini kilitler; saldırısı artar.',
      type: 'attackBuff', cost: 2, value: 30,
    },
    {
      id: 'mergen_ruzgar_avcisi',
      name: 'Rüzgar Avcısı',
      description: 'Rakipte rüzgar varken Mergen\'in okları rüzgara karşı güçlenir. +45 saldırı.',
      type: 'attackBuff', cost: 3, value: 45,
      prerequisite: { target: 'opponent', requiredElements: ['wind'], requiredRoles: [], minCount: 1 },
    },
  ],

  [H.kizagan]: [
    {
      id: 'kizagan_alev_kilici',
      name: 'Alev Kılıcı',
      description: 'Kızagan kılıcını ateşle kaplar.',
      type: 'attackBuff', cost: 2, value: 40,
    },
    {
      id: 'kizagan_ates_hedefi',
      name: 'Ateş Hedefi',
      description: 'Rakipte orman varken ateş avantajı fışkırır. +55 saldırı.',
      type: 'attackBuff', cost: 4, value: 55,
      prerequisite: { target: 'opponent', requiredElements: ['forest'], requiredRoles: [], minCount: 1 },
    },
  ],

  [H.oguzKagan]: [
    {
      id: 'oguz_bozkirimparatorlugu',
      name: 'Bozkır İmparatorluğu',
      description: 'Kağan\'ın emriyle savunma hattı çelik gibi sertleşir.',
      type: 'defenseBuff', cost: 2, value: 30,
    },
    {
      id: 'oguz_kagan_darbesi',
      name: 'Kağan Darbesi',
      description: 'Takımda bozkır savaşçıları olduğunda Kağan\'ın emri tüm gücüyle iner. +45 saldırı.',
      type: 'attackBuff', cost: 3, value: 45,
      prerequisite: { target: 'teammate', requiredElements: ['steppe'], requiredRoles: ['warrior'], minCount: 1 },
    },
  ],

  [H.tasAdam]: [
    {
      id: 'tasadam_tas_yumruk',
      name: 'Taş Yumruk',
      description: 'Taş Adam kaya yumruğunu savurur.',
      type: 'attackBuff', cost: 2, value: 35,
    },
    {
      id: 'tasadam_kaya_savascisi',
      name: 'Kaya Savaşçısı',
      description: 'Takımda bozkır tankı olduğunda Taş Adam\'ın savunması taş gibi sertleşir. +35 savunma.',
      type: 'defenseBuff', cost: 3, value: 35,
      prerequisite: { target: 'teammate', requiredElements: ['steppe'], requiredRoles: ['tank'], minCount: 1 },
    },
  ],

  [H.tepegoz]: [
    {
      id: 'tepegoz_karanlik_zirh',
      name: 'Karanlık Zırh',
      description: 'Karanlığın koruması altına girer.',
      type: 'defenseBuff', cost: 2, value: 45,
    },
    {
      id: 'tepegoz_tek_goz_bakisi',
      name: 'Tek Göz Bakışı',
      description: 'Erlik Han yanında olduğunda Tepegöz\'ün karanlık gözü düşmanı büyüler. +35 saldırı.',
      type: 'attackBuff', cost: 3, value: 35,
      prerequisite: { target: 'teammate', requiredElements: ['dark'], requiredRoles: ['tank'], minCount: 1 },
    },
  ],
};

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log('Token alınıyor...');
  const token = await getFreshAccessToken();
  console.log('✓ Token alındı\n');

  // 1) Pasif buff'ları yaz
  console.log('── Pasif Buff\'lar ──────────────────────────────────────────');
  for (const { id, ...fields } of PASSIVE_BUFFS) {
    const res = await patch(token, 'buffs', id, fields);
    if (res.name) {
      console.log(`  ✓ ${id}  "${fields.name}"`);
    } else {
      const msg = res?.error?.message ?? JSON.stringify(res).slice(0, 120);
      console.error(`  ✗ ${id}: ${msg}`);
      if (res?.error?.code === 401) { console.error('  → Token süresi dolmuş.'); process.exit(1); }
    }
  }

  // 2) Hero skill kartlarını yaz (yalnızca skillCards alanı güncellenir)
  console.log('\n── Kahraman Töz Kartları ───────────────────────────────────');
  for (const [heroId, skills] of Object.entries(HERO_SKILLS)) {
    const res = await patch(token, 'heroes', heroId, { skillCards: skills }, ['skillCards']);
    if (res.name) {
      const name = Object.entries(H).find(([,v]) => v === heroId)?.[0] ?? heroId;
      console.log(`  ✓ ${name} — ${skills.map(s => s.name).join(', ')}`);
    } else {
      const msg = res?.error?.message ?? JSON.stringify(res).slice(0, 120);
      console.error(`  ✗ hero/${heroId}: ${msg}`);
    }
  }

  console.log('\n✓ Tamamlandı.');
}

main().catch(e => { console.error('Hata:', e.message); process.exit(1); });
