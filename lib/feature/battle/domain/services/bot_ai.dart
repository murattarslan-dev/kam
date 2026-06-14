import 'dart:math';

import '../entities/buff_entities.dart';
// Random şu an deterministik karar verdiğimiz için kullanılmıyor; constructor
// imzasını korumak için import'u tutuyoruz (DI bozulmasın).
import '../entities/hero_entities.dart';
import '../../presentation/manager/battle_state.dart';

/// Botun bir tickteki tek aksiyonu. Motor `_runBotLoop` bunun türüne göre
/// `submitAttack` / `submitSkill` / `submitSwap` çağırır.
sealed class BotAction {
  const BotAction();
}

class BotAttack extends BotAction {
  final String actorInstanceId;
  final String targetInstanceId;
  const BotAttack({required this.actorInstanceId, required this.targetInstanceId});
}

class BotSkill extends BotAction {
  final String actorInstanceId;
  final String skillId;
  const BotSkill({required this.actorInstanceId, required this.skillId});
}

class BotSwap extends BotAction {
  final int fieldIndex;
  final int benchIndex;
  const BotSwap({required this.fieldIndex, required this.benchIndex});
}

/// Bot perspektifinde state: `playerTeam` = bot sahası, `benchHeroes` = bot
/// yedeği, `enemyTeam` = oyuncu sahası. Tek seviye, çok zor. 1-ply, tam bilgi.
class BotAi {
  BotAi({Random? random});

  /// Geriye uyumluluk için eski API. Motor `nextAction`'a geçti, ama varsa
  /// dışarıdan gelen çağrılar bozulmasın diye sade bir saldırı sarmalayıcı.
  BotMove? nextMove(BattleInProgress state) {
    final a = nextAction(state);
    if (a is BotAttack) {
      return BotMove(actorInstanceId: a.actorInstanceId, targetInstanceId: a.targetInstanceId);
    }
    return null;
  }

  BotAction? nextAction(BattleInProgress state) {
    final mySaha = state.playerTeam;
    final foes = state.enemyTeam.where((e) => e.isAlive).toList();
    if (foes.isEmpty) return null;

    final myAliveUnacted = <HeroCardEntity>[
      for (final h in mySaha)
        if (h.isAlive && !state.actedHeroIds.contains(h.id)) h,
    ];

    // 1) Tur başıysa (henüz kimse vurmadıysa) swap'i değerlendir.
    if (state.actedHeroIds.isEmpty) {
      final swap = _bestSwap(state);
      if (swap != null) return swap;
    }

    // Sahada vuracak kimse kalmadıysa (hepsi vurdu) tur biter — motor turu
    // çevirsin diye null dönüyoruz.
    if (myAliveUnacted.isEmpty) return null;

    // 2) En iyi skill ve en iyi saldırıyı kıyasla.
    final bestSkill = _bestSkill(state, myAliveUnacted);
    final bestAttack = _bestAttack(state, myAliveUnacted, foes);

    if (bestSkill != null && bestSkill.score > bestAttack.score) {
      return BotSkill(
        actorInstanceId: bestSkill.actorId,
        skillId: bestSkill.skillId,
      );
    }
    return BotAttack(
      actorInstanceId: bestAttack.actorId,
      targetInstanceId: bestAttack.targetId,
    );
  }

  // ── Swap ──────────────────────────────────────────────────────────────────

  BotAction? _bestSwap(BattleInProgress state) {
    final aliveBench = <MapEntry<int, HeroCardEntity>>[
      for (var i = 0; i < state.benchHeroes.length; i++)
        if (state.benchHeroes[i].isAlive) MapEntry(i, state.benchHeroes[i]),
    ];
    if (aliveBench.isEmpty) return null;

    final foes = state.enemyTeam.where((e) => e.isAlive).toList();

    BotSwap? best;
    double bestScore = 0;

    for (var f = 0; f < state.playerTeam.length; f++) {
      final fieldHero = state.playerTeam[f];

      // (a) Ölü slot → her zaman değiştir, en iyi yedeği seç.
      if (!fieldHero.isAlive) {
        final pick = _pickBestBenchForSlot(aliveBench, foes);
        // Ölü slot swap'i çok yüksek skorla işaretle — başka her şeyin önüne geç.
        const deadSlotBonus = 10000.0;
        final score = deadSlotBonus + pick.value;
        if (score > bestScore) {
          bestScore = score;
          best = BotSwap(fieldIndex: f, benchIndex: pick.key);
        }
        continue;
      }

      // (b) Yaralı/dezavantajlı saha kahramanını sağlam bir alternatifle değiştir.
      // Swap tüm turu yer; bu yüzden sıkı bir eşik uyguluyoruz.
      final hpPct = fieldHero.health / fieldHero.currentCp;
      final incomingNext = _maxIncomingDamage(fieldHero, foes);
      final willDieNextTurn = incomingNext >= fieldHero.health;

      if (hpPct >= 0.30 && !willDieNextTurn) continue;

      final currentScore = _slotValueAgainst(fieldHero, foes);
      for (final entry in aliveBench) {
        final cand = entry.value;
        final candScore = _slotValueAgainst(cand, foes);
        // Bench daha güçlü değilse veya marjinal bir iyileşmeyse atla.
        final delta = candScore - currentScore;
        if (delta <= 30) continue;
        // Düşük HP ve gelecek turda ölecekse swap'i kuvvetle ödüllendir.
        final survivalBonus = willDieNextTurn ? 200.0 : 0.0;
        final score = delta + survivalBonus;
        if (score > bestScore) {
          bestScore = score;
          best = BotSwap(fieldIndex: f, benchIndex: entry.key);
        }
      }
    }

    return best;
  }

  MapEntry<int, double> _pickBestBenchForSlot(
    List<MapEntry<int, HeroCardEntity>> aliveBench,
    List<HeroCardEntity> foes,
  ) {
    int bestIdx = aliveBench.first.key;
    double bestVal = -1;
    for (final e in aliveBench) {
      final v = _slotValueAgainst(e.value, foes);
      if (v > bestVal) {
        bestVal = v;
        bestIdx = e.key;
      }
    }
    return MapEntry(bestIdx, bestVal);
  }

  /// Bir kahramanın mevcut düşmanlara karşı kabaca değeri.
  /// = en iyi element çarpanı × atk + def + (hp / 2)
  double _slotValueAgainst(HeroCardEntity h, List<HeroCardEntity> foes) {
    double bestMult = 1.0;
    for (final f in foes) {
      final m = h.element.getDamageMultiplier(f.element);
      if (m > bestMult) bestMult = m;
    }
    return bestMult * h.currentAttackPower +
        h.currentDefensePower +
        h.health / 2.0;
  }

  // ── Attack ────────────────────────────────────────────────────────────────

  _ScoredAttack _bestAttack(
    BattleInProgress state,
    List<HeroCardEntity> myAliveUnacted,
    List<HeroCardEntity> foes,
  ) {
    String bestActor = myAliveUnacted.first.id;
    String bestTarget = foes.first.id;
    double bestScore = -double.infinity;

    for (final attacker in myAliveUnacted) {
      for (final target in foes) {
        final s = _scoreAttack(state, attacker, target, foes);
        if (s > bestScore) {
          bestScore = s;
          bestActor = attacker.id;
          bestTarget = target.id;
        }
      }
    }
    return _ScoredAttack(actorId: bestActor, targetId: bestTarget, score: bestScore);
  }

  double _scoreAttack(
    BattleInProgress state,
    HeroCardEntity attacker,
    HeroCardEntity target,
    List<HeroCardEntity> allFoes,
  ) {
    final elemMult = attacker.element.getDamageMultiplier(target.element);
    final raw = (attacker.currentAttackPower * elemMult).round();
    final dmg = max(1, raw - target.currentDefensePower);
    final hits = dmg >= target.health;

    double score = dmg.toDouble();

    // Element üstünlüğü ödülü.
    if (elemMult >= 1.2) score += 25 * (elemMult - 1.0);
    if (elemMult < 1.0) score -= 20 * (1.0 - elemMult);

    // Lethal: bu vuruş öldürüyorsa mutlak öncelik.
    if (hits) {
      score += 500;
      // Yüksek tehditli düşmanı öldürmek daha kıymetli.
      score += target.currentAttackPower * 1.5;
      // Overkill cezası (kalan fazla hasarı boşa harcama).
      score -= (dmg - target.health) * 0.4;
    } else {
      // Düşmanı ne kadar yaralı bırakırsak o kadar iyi (bitirme zinciri).
      final newHp = target.health - dmg;
      final lowHpBonus = (1.0 - newHp / target.currentCp) * 40;
      score += lowHpBonus;
      // Yaralı düşmanı bitirmeye yaklaş.
      if (target.health / target.currentCp < 0.4) score += 30;
    }

    // Tehdit: yüksek ATK'li düşmanı önce indir.
    score += target.currentAttackPower * 0.6;

    // Hedefin üzerindeki damageSoak buff'ı varsa skoru düşür (kalkan emer).
    final soakOnTarget = _activeBuffsOf(state, target.id)
        .where((b) => b.type == BuffType.damageSoak)
        .fold<int>(0, (acc, b) => acc + b.value.abs());
    if (soakOnTarget > 0) score -= soakOnTarget * 0.8;

    // Soaker (tank) hedefe öncelik: düşman tarafta damageSoak veren biri varsa
    // ve bu hedef o kalkanı sağlıyorsa, onu önce kırmak değerli.
    if (_isSoakerForTeam(state, target, allFoes)) score += 80;

    return score;
  }

  // ── Skill ─────────────────────────────────────────────────────────────────

  _ScoredSkill? _bestSkill(
    BattleInProgress state,
    List<HeroCardEntity> myAliveUnacted,
  ) {
    _ScoredSkill? best;
    final foes = state.enemyTeam.where((e) => e.isAlive).toList();

    for (final hero in myAliveUnacted) {
      final used = state.usedTozIdsByHero[hero.id] ?? const [];
      for (final buffId in hero.tozler) {
        if (used.contains(buffId)) continue;
        final buff = state.allBuffs.where((b) => b.id == buffId).firstOrNull;
        if (buff == null) continue;
        if (!buff.isManual) continue;
        if (hero.kut < (buff.cost ?? 0)) continue;
        if (!_useReqMet(state, hero, buff)) continue;

        final score = _scoreBuffTrigger(state, hero, buff, foes);
        if (score <= 0) continue;
        if (best == null || score > best.score) {
          best = _ScoredSkill(actorId: hero.id, skillId: buffId, score: score);
        }
      }
    }
    return best;
  }

  double _scoreBuffTrigger(
    BattleInProgress state,
    HeroCardEntity caster,
    BuffEntity buff,
    List<HeroCardEntity> foes,
  ) {
    final teammates =
        state.playerTeam.where((h) => h.isAlive).toList(growable: false);
    final aliveFoes = foes;

    int targetCount;
    bool targetsEnemies;
    switch (buff.targetType) {
      case BuffTargetType.self:
        targetCount = 1;
        targetsEnemies = false;
        break;
      case BuffTargetType.singleTeammate:
        targetCount = teammates.length > 1 ? 1 : 0;
        targetsEnemies = false;
        break;
      case BuffTargetType.allTeammates:
        targetCount = teammates.length;
        targetsEnemies = false;
        break;
      case BuffTargetType.singleEnemy:
        targetCount = aliveFoes.isEmpty ? 0 : 1;
        targetsEnemies = true;
        break;
      case BuffTargetType.allEnemies:
        targetCount = aliveFoes.length;
        targetsEnemies = true;
        break;
    }
    if (targetCount == 0) return 0;

    final turns = buff.duration <= 0 ? 4 : buff.duration; // -1 = savaş sonu
    final magnitude = buff.value.abs().toDouble();

    switch (buff.type) {
      case BuffType.dot:
        if (!targetsEnemies) return 0;
        return magnitude * turns * targetCount + 40; // erken kullanmak iyi
      case BuffType.hot:
        if (targetsEnemies) return 0;
        // Takımın eksik HP'si yoksa düşük puan.
        final missing = teammates.fold<int>(
            0, (a, h) => a + (h.currentCp - h.health));
        if (missing <= 0) return 0;
        return min(magnitude * turns * targetCount, missing.toDouble()) + 20;
      case BuffType.damageSoak:
        return magnitude * targetCount * 1.5 + 30;
      case BuffType.statChange:
        // Düşmana stat debuff (value<0) veya takıma stat buff.
        return magnitude * turns * targetCount * 0.7;
      case BuffType.arenaImmunity:
        // Arena etkisinin gücüne göre kabaca değer biç; bot bilmediği için
        // ortalama bir puan veriyoruz.
        if (targetsEnemies) return 0;
        return targetCount * turns * 5.0;
      case BuffType.dispel:
        // Rakipte aktif buff sayısına göre değerli; programatik hedef rastgele.
        if (!targetsEnemies) return 0;
        return magnitude * 25 + 20;
      case BuffType.damageRedirect:
        // Self/takıma uygulanır; yansıtma yüzdesi büyüdükçe değerli.
        if (targetsEnemies) return 0;
        return magnitude * turns * 0.8 + 25;
    }
  }

  /// Buff'ın `useRequirements` listesini bot perspektifinden değerlendirir.
  bool _useReqMet(BattleInProgress state, HeroCardEntity hero, BuffEntity buff) {
    if (buff.useRequirements.isEmpty) return true;
    return buff.useRequirements.every((p) {
      switch (p.type) {
        case BuffPrerequisiteType.none:
          return true;
        case BuffPrerequisiteType.heroElementIs:
          return hero.element.name == p.value;
        case BuffPrerequisiteType.heroRoleIs:
          return hero.role.name == p.value;
        case BuffPrerequisiteType.heroIdIs:
          return hero.id == p.value;
        case BuffPrerequisiteType.heroHpBelowPercent:
          final pct = double.tryParse(p.value);
          if (pct == null || hero.currentCp <= 0) return false;
          return (hero.health / hero.currentCp) * 100 <= pct;
        case BuffPrerequisiteType.heroIdIn:
          return p.value
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .contains(hero.id);
        case BuffPrerequisiteType.hasTeammateWithElement:
          return state.playerTeam.any((h) =>
              h.id != hero.id && h.isAlive && h.element.name == p.value);
        case BuffPrerequisiteType.hasTeammateWithRole:
          return state.playerTeam.any((h) =>
              h.id != hero.id && h.isAlive && h.role.name == p.value);
        case BuffPrerequisiteType.hasTeammateWithId:
          return state.playerTeam.any(
              (h) => h.id != hero.id && h.isAlive && h.id == p.value);
        case BuffPrerequisiteType.hasEnemyWithElement:
          return state.enemyTeam
              .any((h) => h.isAlive && h.element.name == p.value);
        case BuffPrerequisiteType.hasEnemyWithRole:
          return state.enemyTeam.any((h) => h.isAlive && h.role.name == p.value);
      }
    });
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  int _maxIncomingDamage(HeroCardEntity h, List<HeroCardEntity> foes) {
    int worst = 0;
    for (final f in foes) {
      final m = f.element.getDamageMultiplier(h.element);
      final raw = (f.currentAttackPower * m).round();
      final dmg = max(1, raw - h.currentDefensePower);
      if (dmg > worst) worst = dmg;
    }
    return worst;
  }

  Iterable<BuffEntity> _activeBuffsOf(BattleInProgress state, String heroId) {
    return state.activeBuffs
        .where((ab) => ab.targetHeroId == heroId)
        .map((ab) =>
            state.allBuffs.where((b) => b.id == ab.buffId).firstOrNull)
        .whereType<BuffEntity>();
  }

  /// Hedef düşman, kendi takımına damageSoak sağlıyor mu? Çok kaba bir
  /// yaklaşım: hedef üzerinde damageSoak/allTeammates buff'ı varsa true.
  bool _isSoakerForTeam(BattleInProgress state, HeroCardEntity target,
      List<HeroCardEntity> foes) {
    for (final b in _activeBuffsOf(state, target.id)) {
      if (b.type == BuffType.damageSoak) return true;
    }
    return false;
  }
}

class _ScoredAttack {
  final String actorId;
  final String targetId;
  final double score;
  const _ScoredAttack(
      {required this.actorId, required this.targetId, required this.score});
}

class _ScoredSkill {
  final String actorId;
  final String skillId;
  final double score;
  const _ScoredSkill(
      {required this.actorId, required this.skillId, required this.score});
}

class BotMove {
  final String actorInstanceId;
  final String targetInstanceId;
  const BotMove({required this.actorInstanceId, required this.targetInstanceId});
}
