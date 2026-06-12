import 'package:cloud_firestore/cloud_firestore.dart';

import '../../battle/domain/entities/buff_entities.dart';

/// Eski şemadan yeni şemaya tek seferlik geçiş.
///
/// Eski:
///   heroes/[heroId]/skills/[skillId] → SkillEntity (type, value, cost,
///   prerequisite, triggersBuffId)
///
/// Yeni:
///   heroes/[heroId].tozler: `List<String>` (buff id referansları)
///   buffs/{id}: BuffEntity (cost ve useRequirements buff'ta)
///
/// Davranış:
/// - Her skill için:
///   * `triggersBuffId` doluysa o id `tozler`'e eklenir (yeni buff üretilmez).
///   * Boşsa `skill_<skillId>` adıyla bir buff üretilir (yoksa) ve `tozler`'e
///     eklenir. SkillType → BuffType eşlemesi:
///       heal        → hot, duration:1, target:self
///       attackBuff  → statChange/attack, duration:-1, target:self
///       defenseBuff → statChange/defense, duration:-1, target:self
/// - Bir kahramanda hâlihazırda `tozler` doluysa o kahraman atlanır (idempotent).
/// - Alt-koleksiyon (skills) silinmez; manuel temizlenir.
class SkillToTozMigration {
  static Future<MigrationResult> run(FirebaseFirestore fs) async {
    int heroesProcessed = 0;
    int heroesSkipped = 0;
    int buffsCreated = 0;
    int tozlerAssigned = 0;

    final heroesSnap = await fs.collection('heroes').get();
    for (final heroDoc in heroesSnap.docs) {
      final data = heroDoc.data();
      final existing = (data['tozler'] as List?) ?? const [];
      if (existing.isNotEmpty) {
        heroesSkipped++;
        continue;
      }

      final tozler = <String>[];
      final skillsSnap = await heroDoc.reference.collection('skills').get();
      for (final skillDoc in skillsSnap.docs) {
        final s = skillDoc.data();
        final triggersBuffId = (s['triggersBuffId'] as String?)?.trim();

        String buffId;
        if (triggersBuffId != null && triggersBuffId.isNotEmpty) {
          buffId = triggersBuffId;
        } else {
          buffId = 'skill_${skillDoc.id}';
          final ref = fs.collection('buffs').doc(buffId);
          final exists = (await ref.get()).exists;
          if (!exists) {
            final buff = _synthesizeBuff(buffId, s);
            await ref.set(buff.toMap());
            buffsCreated++;
          }
        }

        if (!tozler.contains(buffId)) {
          tozler.add(buffId);
          tozlerAssigned++;
        }
      }

      await heroDoc.reference.update({'tozler': tozler});
      heroesProcessed++;
    }

    return MigrationResult(
      heroesProcessed: heroesProcessed,
      heroesSkipped: heroesSkipped,
      buffsCreated: buffsCreated,
      tozlerAssigned: tozlerAssigned,
    );
  }

  static BuffEntity _synthesizeBuff(String id, Map<String, dynamic> s) {
    final type = (s['type'] as String?) ?? 'attackBuff';
    final value = (s['value'] as num?)?.toInt() ?? 10;
    final cost = (s['cost'] as num?)?.toInt() ?? 1;
    final name = (s['name'] as String?) ?? id;
    final description = (s['description'] as String?) ?? '';

    BuffType bt;
    StatType? st;
    int duration;
    switch (type) {
      case 'heal':
        bt = BuffType.hot;
        st = null;
        duration = 1;
        break;
      case 'defenseBuff':
        bt = BuffType.statChange;
        st = StatType.defense;
        duration = -1;
        break;
      case 'attackBuff':
      default:
        bt = BuffType.statChange;
        st = StatType.attack;
        duration = -1;
        break;
    }

    return BuffEntity(
      id: id,
      name: name,
      description: description,
      type: bt,
      statType: st,
      value: value,
      valueMode: ValueMode.absolute,
      duration: duration,
      targetType: BuffTargetType.self,
      triggerCondition: BuffTriggerCondition.manual,
      cost: cost,
    );
  }
}

class MigrationResult {
  final int heroesProcessed;
  final int heroesSkipped;
  final int buffsCreated;
  final int tozlerAssigned;

  const MigrationResult({
    required this.heroesProcessed,
    required this.heroesSkipped,
    required this.buffsCreated,
    required this.tozlerAssigned,
  });

  @override
  String toString() =>
      'İşlenen: $heroesProcessed kahraman · Atlanan (zaten dolu): $heroesSkipped · '
      'Üretilen buff: $buffsCreated · Atanan töz: $tozlerAssigned';
}
