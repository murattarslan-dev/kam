import '../../domain/entities/hero_entities.dart';
import '../../domain/entities/buff_entities.dart';
import '../../domain/entities/arena_entities.dart';
import '../../presentation/manager/battle_state.dart';

/// Birleşik battles/{id} doc'u ↔ BattleInProgress dönüşümü.
///
/// Şema (PvE ve PvP tek koleksiyon):
/// - identity: mode, status, hostId, guestId, hostName, guestName
/// - teams (live): hostTeam, hostBench, guestTeam, guestBench
///     · her hero { instanceId, name, element, role, maxCp,
///                  attackPower, defensePower, health, kut, isAlive,
///                  imageUrl, skills[], xp, userHeroDocId }
/// - tur durumu: currentTurn, turnOwner, actedHeroIds[], activeBuffs[],
///     usedSkillIds[], totalDamageDealt{}, totalDamageReceived{}, battleLogs[]
/// - animasyon: lastAction { seq, type, actorInstanceId, targetInstanceId,
///     actorSide, finalDamage, killed, message }, seq
/// - sonuç: result { winnerSide, isHostVictory, message, rewards,
///     heroStats[{instanceId,name,isBench,side,damageDealt,
///                damageReceived,xpGained}], finishedAt }
///
/// Instance id'ler savaş süresince stabildir. Swap yapılsa bile entity'nin
/// `id`'si değişmez; yalnızca konum değişir.
class BattleDocMapper {
  // ── Hero serileştirme ───────────────────────────────────────────────────

  static Map<String, dynamic> heroToDoc(HeroCardEntity h) => {
        'instanceId': h.id,
        'name': h.name,
        'description': h.description,
        'element': h.element.name,
        'role': h.role.name,
        'xp': h.xp,
        'cp': h.cp,
        'health': h.health,
        'attackPower': h.attackPower,
        'defensePower': h.defensePower,
        'imageUrl': h.imageUrl,
        'kut': h.kut,
        'userHeroDocId': h.userHeroDocId,
        'tozler': h.tozler,
      };

  static HeroCardEntity heroFromDoc(Map<String, dynamic> m, {String? fallbackId}) {
    final tozler = ((m['tozler'] as List<dynamic>?) ?? const [])
        .map((e) => e.toString())
        .toList();
    return HeroCardEntity(
      id: m['instanceId'] as String? ?? fallbackId ?? '',
      name: m['name'] as String? ?? 'Adsız',
      description: m['description'] as String? ?? '',
      element: HeroElement.fromString(m['element'] as String? ?? 'steppe'),
      role: HeroRole.fromString(m['role'] as String? ?? 'warrior'),
      xp: (m['xp'] as num?)?.toInt() ?? 0,
      cp: (m['cp'] as num?)?.toInt() ?? 100,
      health: (m['health'] as num?)?.toInt() ?? 100,
      attackPower: (m['attackPower'] as num?)?.toInt() ?? 10,
      defensePower: (m['defensePower'] as num?)?.toInt() ?? 5,
      imageUrl: m['imageUrl'] as String? ?? '',
      kut: (m['kut'] as num?)?.toInt() ?? 0,
      tozler: tozler,
      userHeroDocId: m['userHeroDocId'] as String? ?? '',
    );
  }

  static List<Map<String, dynamic>> teamToDoc(List<HeroCardEntity> team) =>
      team.map(heroToDoc).toList();

  static List<HeroCardEntity> teamFromDoc(dynamic raw, {String prefix = ''}) {
    if (raw is! List) return const [];
    final out = <HeroCardEntity>[];
    for (var i = 0; i < raw.length; i++) {
      out.add(heroFromDoc(
        Map<String, dynamic>.from(raw[i] as Map),
        fallbackId: '$prefix$i',
      ));
    }
    return out;
  }

  // ── Instance id atama (savaş kurulurken bir kez) ────────────────────────

  /// Bir takıma stabil instance id'leri verir: 'h:0','h:1',... veya 'g:0',...
  /// Bench için 'hb:0' / 'gb:0' önekleri.
  static List<HeroCardEntity> assignInstanceIds(
    List<HeroCardEntity> heroes,
    String prefix,
  ) {
    return List.generate(heroes.length, (i) {
      final h = heroes[i];
      return HeroCardEntity(
        id: '$prefix:$i',
        name: h.name,
        description: h.description,
        element: h.element,
        role: h.role,
        xp: h.xp,
        cp: h.cp,
        health: h.health,
        attackPower: h.attackPower,
        defensePower: h.defensePower,
        imageUrl: h.imageUrl,
        kut: h.kut,
        bonusAttack: h.bonusAttack,
        bonusDefense: h.bonusDefense,
        bonusMaxHealth: h.bonusMaxHealth,
        tozler: h.tozler,
        userHeroDocId: h.userHeroDocId,
      );
    });
  }

  // ── Active buff serileştirme ────────────────────────────────────────────

  static Map<String, dynamic> activeBuffToDoc(ActiveBuff b) => b.toMap();
  static ActiveBuff activeBuffFromDoc(Map<String, dynamic> m) => ActiveBuff.fromMap(m);

  static Map<String, List<String>> _readUsedTozMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, List<String>>{};
    raw.forEach((k, v) {
      if (v is List) {
        out[k.toString()] = v.map((e) => e.toString()).toList();
      }
    });
    return out;
  }

  // ── Perspektif: doc → BattleInProgress (mySide kendi takımı olur) ───────

  static BattleInProgress buildPerspective({
    required Map<String, dynamic> doc,
    required String mySide, // 'host' | 'guest'
    required List<BuffEntity> allBuffs,
    required String battleId,
  }) {
    final isHostPerspective = mySide == 'host';
    final hostTeam = teamFromDoc(doc['hostTeam'], prefix: 'h:');
    final hostBench = teamFromDoc(doc['hostBench'], prefix: 'hb:');
    final guestTeam = teamFromDoc(doc['guestTeam'], prefix: 'g:');
    final guestBench = teamFromDoc(doc['guestBench'], prefix: 'gb:');

    final activeBuffs = ((doc['activeBuffs'] as List?) ?? const [])
        .map((e) => activeBuffFromDoc(Map<String, dynamic>.from(e as Map)))
        .toList();

    final dealt = <String, double>{};
    ((doc['totalDamageDealt'] as Map?) ?? const {}).forEach((k, v) {
      dealt[k as String] = (v as num).toDouble();
    });
    final received = <String, double>{};
    ((doc['totalDamageReceived'] as Map?) ?? const {}).forEach((k, v) {
      received[k as String] = (v as num).toDouble();
    });
    final kills = ((doc['kills'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // currentAction: lastAction'ı oyuncunun perspektifinden BattleAction'a çevir.
    BattleAction? currentAction;
    final la = doc['lastAction'] as Map?;
    if (la != null && la['type'] == 'attack') {
      final actorId = la['actorInstanceId'] as String?;
      final targetId = la['targetInstanceId'] as String?;
      final actorSide = la['actorSide'] as String?;
      final all = [...hostTeam, ...hostBench, ...guestTeam, ...guestBench];
      final actor = all.where((h) => h.id == actorId).firstOrNull;
      final target = all.where((h) => h.id == targetId).firstOrNull;
      if (actor != null && target != null && actorSide != null) {
        currentAction = BattleAction(
          attacker: actor,
          target: target,
          isPlayerAttacking: actorSide == mySide,
        );
      }
    }

    // Floating sayı için HP delta'ları (varsa).
    final deltas = <String, int>{};
    final rawDeltas = la?['deltas'];
    if (rawDeltas is Map) {
      rawDeltas.forEach((k, v) {
        deltas[k.toString()] = (v as num).toInt();
      });
    }
    final lastSeq = (la?['seq'] as num?)?.toInt();

    // Arena snapshot — doc'a yazılan elementEffects map'iyle rebuild.
    ArenaEntity? arena;
    final arenaRaw = doc['arena'];
    if (arenaRaw is Map) {
      arena = ArenaEntity.fromMap(Map<String, dynamic>.from(arenaRaw));
    }

    return BattleInProgress(
      playerTeam: isHostPerspective ? hostTeam : guestTeam,
      enemyTeam: isHostPerspective ? guestTeam : hostTeam,
      benchHeroes: isHostPerspective ? hostBench : guestBench,
      currentTurn: (doc['currentTurn'] as num?)?.toInt() ?? 1,
      isPlayerTurn: (doc['turnOwner'] as String?) == mySide,
      actedHeroIds: ((doc['actedHeroIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      battleLogs: ((doc['battleLogs'] as List?) ?? const ['Savaş başladı!'])
          .map((e) => e.toString())
          .toList(),
      totalDamageDealt: dealt,
      totalDamageReceived: received,
      kills: kills,
      usedTozIdsByHero: _readUsedTozMap(doc['usedTozIdsByHero']),
      activeBuffs: activeBuffs,
      allBuffs: allBuffs,
      currentAction: currentAction,
      battleId: battleId,
      floatingDeltas: deltas,
      lastActionSeq: lastSeq,
      playerName: isHostPerspective
          ? (doc['hostName'] as String?)
          : (doc['guestName'] as String?),
      enemyName: isHostPerspective
          ? (doc['guestName'] as String?)
          : (doc['hostName'] as String?),
      arena: arena,
    );
  }

}
