import 'package:cloud_firestore/cloud_firestore.dart';

import '../../battle/domain/entities/buff_entities.dart';

/// Tek seferlik seed: basit Töz seti (3 ve 5 Kut) buff'larını üretir ve
/// her kahramana role göre 1× 3-Kut + 1× 5-Kut atar.
///
/// Davranış:
/// - Buff'lar: yoksa oluşturulur, varsa olduğu gibi bırakılır.
/// - Kahramanlar: mevcut `tozler` listesine eksik olan id'ler eklenir
///   (silinmez). İdempotenttir.
class TozSeed {
  static const _buffs = <_SeedBuff>[
    // 3 Kut — kendine yönelik
    _SeedBuff(
      id: 'toz_oz_guc',
      name: 'Öz Güç',
      description: 'Kendisine 3 tur boyunca +%15 saldırı.',
      type: BuffType.statChange,
      statType: StatType.attack,
      value: 15,
      valueMode: ValueMode.percent,
      duration: 3,
      targetType: BuffTargetType.self,
      cost: 3,
    ),
    _SeedBuff(
      id: 'toz_oz_zirh',
      name: 'Öz Zırh',
      description: 'Kendisine 3 tur boyunca +%20 savunma.',
      type: BuffType.statChange,
      statType: StatType.defense,
      value: 20,
      valueMode: ValueMode.percent,
      duration: 3,
      targetType: BuffTargetType.self,
      cost: 3,
    ),
    _SeedBuff(
      id: 'toz_oz_sifa',
      name: 'Şifalı Nefes',
      description: 'Kendisine 3 tur boyunca her tur sonu can yeniler.',
      type: BuffType.hot,
      statType: null,
      value: 8, // her tur currentCp'nin %8'i (percent mode)
      valueMode: ValueMode.percent,
      duration: 3,
      targetType: BuffTargetType.self,
      cost: 3,
    ),

    // 5 Kut — takım/düşman yönelimli
    _SeedBuff(
      id: 'toz_takim_kalkani',
      name: 'Takım Kalkanı',
      description: 'Tüm takıma 3 tur boyunca +%15 savunma.',
      type: BuffType.statChange,
      statType: StatType.defense,
      value: 15,
      valueMode: ValueMode.percent,
      duration: 3,
      targetType: BuffTargetType.allTeammates,
      cost: 5,
    ),
    _SeedBuff(
      id: 'toz_savas_narasi',
      name: 'Savaş Narası',
      description: 'Tüm takıma 3 tur boyunca +%10 saldırı.',
      type: BuffType.statChange,
      statType: StatType.attack,
      value: 10,
      valueMode: ValueMode.percent,
      duration: 3,
      targetType: BuffTargetType.allTeammates,
      cost: 5,
    ),
    _SeedBuff(
      id: 'toz_dusman_yarasi',
      name: 'Düşman Yarası',
      description: 'Tüm düşmanlara 3 tur boyunca -%15 savunma.',
      type: BuffType.statChange,
      statType: StatType.defense,
      value: -15,
      valueMode: ValueMode.percent,
      duration: 3,
      targetType: BuffTargetType.allEnemies,
      cost: 5,
    ),
    _SeedBuff(
      id: 'toz_kara_zehir',
      name: 'Kara Zehir',
      description:
          'Tek düşmana 3 tur boyunca her tur sonu canının %8\'i kadar hasar.',
      type: BuffType.dot,
      statType: null,
      value: 8,
      valueMode: ValueMode.percent,
      duration: 3,
      targetType: BuffTargetType.singleEnemy,
      cost: 5,
    ),
  ];

  /// Role göre {3-Kut id, 5-Kut id} ataması.
  static const _assignmentByRole = <String, List<String>>{
    'warrior': ['toz_oz_guc', 'toz_dusman_yarasi'],
    'tank': ['toz_oz_zirh', 'toz_takim_kalkani'],
    'support': ['toz_oz_sifa', 'toz_savas_narasi'],
    'mage': ['toz_oz_guc', 'toz_kara_zehir'],
  };

  static Future<SeedResult> run(FirebaseFirestore fs) async {
    int buffsCreated = 0;
    int buffsSkipped = 0;
    int heroesUpdated = 0;
    int tozlerAdded = 0;

    // 1) Buff'ları oluştur.
    for (final s in _buffs) {
      final ref = fs.collection('buffs').doc(s.id);
      final exists = (await ref.get()).exists;
      if (exists) {
        buffsSkipped++;
        continue;
      }
      final buff = BuffEntity(
        id: s.id,
        name: s.name,
        description: s.description,
        type: s.type,
        statType: s.statType,
        value: s.value,
        valueMode: s.valueMode,
        duration: s.duration,
        targetType: s.targetType,
        triggerCondition: BuffTriggerCondition.manual,
        cost: s.cost,
      );
      await ref.set(buff.toMap());
      buffsCreated++;
    }

    // 2) Her kahramana role göre ata.
    final heroes = await fs.collection('heroes').get();
    for (final doc in heroes.docs) {
      final data = doc.data();
      final role = (data['role'] as String?) ?? 'warrior';
      final assignment = _assignmentByRole[role] ?? _assignmentByRole['warrior']!;

      final existing = ((data['tozler'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      final updated = List<String>.from(existing);
      int added = 0;
      for (final id in assignment) {
        if (!updated.contains(id)) {
          updated.add(id);
          added++;
        }
      }
      if (added > 0) {
        await doc.reference.update({'tozler': updated});
        heroesUpdated++;
        tozlerAdded += added;
      }
    }

    return SeedResult(
      buffsCreated: buffsCreated,
      buffsSkipped: buffsSkipped,
      heroesUpdated: heroesUpdated,
      tozlerAdded: tozlerAdded,
    );
  }
}

class _SeedBuff {
  final String id;
  final String name;
  final String description;
  final BuffType type;
  final StatType? statType;
  final int value;
  final ValueMode valueMode;
  final int duration;
  final BuffTargetType targetType;
  final int cost;

  const _SeedBuff({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.statType,
    required this.value,
    required this.valueMode,
    required this.duration,
    required this.targetType,
    required this.cost,
  });
}

class SeedResult {
  final int buffsCreated;
  final int buffsSkipped;
  final int heroesUpdated;
  final int tozlerAdded;

  const SeedResult({
    required this.buffsCreated,
    required this.buffsSkipped,
    required this.heroesUpdated,
    required this.tozlerAdded,
  });

  @override
  String toString() =>
      'Buff: +$buffsCreated yeni, $buffsSkipped atlandı · '
      'Kahraman güncellendi: $heroesUpdated · Atanan töz: $tozlerAdded';
}
