import '../../domain/entities/hero_entities.dart';
import '../../domain/entities/buff_entities.dart';
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
        'skills': h.skillCards.map((s) => s.toMap()).toList(),
      };

  static HeroCardEntity heroFromDoc(Map<String, dynamic> m, {String? fallbackId}) {
    final skills = (m['skills'] as List<dynamic>? ?? [])
        .map((s) => SkillEntity.fromMap(Map<String, dynamic>.from(s as Map)))
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
      skillCards: skills,
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
        skillCards: h.skillCards,
        userHeroDocId: h.userHeroDocId,
      );
    });
  }

  // ── Active buff serileştirme ────────────────────────────────────────────

  static Map<String, dynamic> activeBuffToDoc(ActiveBuff b) => b.toMap();
  static ActiveBuff activeBuffFromDoc(Map<String, dynamic> m) => ActiveBuff.fromMap(m);

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
      usedSkillIds: ((doc['usedSkillIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      activeBuffs: activeBuffs,
      allBuffs: allBuffs,
      currentAction: currentAction,
      battleId: battleId,
    );
  }

  /// Result için: doc → BattleResult (mySide perspektifi).
  static BattleResult buildResult({
    required Map<String, dynamic> doc,
    required String mySide,
    required List<BuffEntity> allBuffs,
  }) {
    final isHostPerspective = mySide == 'host';
    final hostTeam = teamFromDoc(doc['hostTeam'], prefix: 'h:');
    final hostBench = teamFromDoc(doc['hostBench'], prefix: 'hb:');
    final guestTeam = teamFromDoc(doc['guestTeam'], prefix: 'g:');
    final guestBench = teamFromDoc(doc['guestBench'], prefix: 'gb:');

    final dealt = <String, double>{};
    ((doc['totalDamageDealt'] as Map?) ?? const {}).forEach((k, v) {
      dealt[k as String] = (v as num).toDouble();
    });
    final received = <String, double>{};
    ((doc['totalDamageReceived'] as Map?) ?? const {}).forEach((k, v) {
      received[k as String] = (v as num).toDouble();
    });

    final result = (doc['result'] as Map?) ?? const {};
    final winnerSide = result['winnerSide'] as String?;
    final isVictory = winnerSide == mySide;

    final heroStats = (result['heroStats'] as List?) ?? const [];
    final xpGained = <String, int>{};
    for (final r in heroStats) {
      final m = Map<String, dynamic>.from(r as Map);
      xpGained[m['instanceId'] as String] = (m['xpGained'] as num?)?.toInt() ?? 0;
    }

    final activeBuffs = ((doc['activeBuffs'] as List?) ?? const [])
        .map((e) => activeBuffFromDoc(Map<String, dynamic>.from(e as Map)))
        .toList();

    return BattleResult(
      message: result['message'] as String? ??
          (isVictory ? 'Zafer!' : 'Mağlubiyet...'),
      isVictory: isVictory,
      rewards: ((result['rewards'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      playerTeam: isHostPerspective ? hostTeam : guestTeam,
      benchHeroes: isHostPerspective ? hostBench : guestBench,
      totalDamageDealt: dealt,
      totalDamageReceived: received,
      heroXpGained: xpGained,
      activeBuffs: activeBuffs,
      allBuffs: allBuffs,
    );
  }
}
