import 'dart:math';

import '../entities/hero_entities.dart';
import '../entities/buff_entities.dart';
import '../../presentation/manager/battle_state.dart';

class SoakEntry {
  final String heroId;
  final int amount;
  const SoakEntry({required this.heroId, required this.amount});
}

class DamageRedirectResult {
  final int remainingDamage;
  final Map<String, int> perEnemyDamage;
  final String? buffName;
  const DamageRedirectResult({
    required this.remainingDamage,
    required this.perEnemyDamage,
    required this.buffName,
  });
  bool get hasRedirect => perEnemyDamage.isNotEmpty;
  int get totalRedirected => perEnemyDamage.values.fold(0, (s, v) => s + v);
}

class DamageSoakResult {
  final List<SoakEntry> soakers;
  final int remainingDamage;
  const DamageSoakResult({required this.soakers, required this.remainingDamage});
  static const none = DamageSoakResult(soakers: [], remainingDamage: 0);
  bool get hasSoak => soakers.isNotEmpty;
  int get totalSoaked => soakers.fold(0, (s, e) => s + e.amount);
}

class HandleBuffsUseCase {
  /// Bir buff'ı manuel veya tetiklenme sonucu bir kahramana uygular.
  BattleInProgress applyBuff(BattleInProgress currentState, String buffId, String targetHeroId) {
    final buff = currentState.allBuffs.where((b) => b.id == buffId).firstOrNull;
    if (buff == null) return currentState;

    // Dispel anlık çalışır: ActiveBuff olarak depolanmaz, çağrı sırasında
    // rakip takımdaki rastgele canlı kahramanın N aktif buff'ı silinir.
    // targetHeroId burada "caster"dır (sahip); rakip takımı belirlemek için kullanılır.
    if (buff.type == BuffType.dispel) {
      return _applyDispel(currentState, buff, targetHeroId);
    }

    // Eğer buff zaten aktifse (aynı kahramanda), süresini yenileyebiliriz veya stackleyebiliriz.
    // Şimdilik süresini yenileyelim.
    final existingIndex = currentState.activeBuffs.indexWhere(
      (ab) => ab.buffId == buffId && ab.targetHeroId == targetHeroId,
    );

    List<ActiveBuff> updatedActiveBuffs = List.from(currentState.activeBuffs);
    if (existingIndex != -1) {
      updatedActiveBuffs[existingIndex] = updatedActiveBuffs[existingIndex].copyWith(
        remainingTurns: buff.duration,
      );
    } else {
      updatedActiveBuffs.add(ActiveBuff(
        buffId: buffId,
        targetHeroId: targetHeroId,
        remainingTurns: buff.duration,
      ));
    }

    final newState = currentState.copyWith(activeBuffs: updatedActiveBuffs);
    return recalculateAllHeroStats(newState);
  }

  /// Belirli bir koşula bağlı otomatik buff'ları kontrol eder ve gerekirse aktifleştirir.
  BattleInProgress checkAutoBuffs(BattleInProgress currentState, BuffTriggerCondition condition) {
    BattleInProgress state = currentState;

    for (final buff in state.allBuffs) {
      if (buff.triggerCondition != condition) continue;

      if (condition == BuffTriggerCondition.onHpBelowPercent && buff.triggerValue != null) {
        final allHeroes = [...state.playerTeam, ...state.enemyTeam];
        for (final hero in allHeroes) {
          if (!hero.isAlive) continue;
          final hpPercent = hero.currentHealth / hero.currentCp;
          if (hpPercent <= buff.triggerValue!) {
            final alreadyActive = state.activeBuffs.any((ab) => ab.buffId == buff.id && ab.targetHeroId == hero.id);
            if (!alreadyActive) {
              state = applyBuff(state, buff.id, hero.id);
            }
          }
        }
      } else if (condition == BuffTriggerCondition.onTeammateHpBelowPercent && buff.triggerValue != null) {
        // Buff sahibi: prerequisites'ı geçen kahraman. Hedef ise targetType'a göre:
        // - self → sahip (eski davranış)
        // - singleTeammate → eşiği aşan yaralı takım arkadaşı
        // - allTeammates → tüm canlı takım arkadaşları (sahip dahil)
        for (final owner in [...state.playerTeam, ...state.enemyTeam]) {
          if (!owner.isAlive) continue;
          final isPlayer = state.playerTeam.any((h) => h.id == owner.id);
          if (!_isPrerequisiteMet(state, owner, isPlayer, buff.targetFilter)) continue;
          final team = isPlayer ? state.playerTeam : state.enemyTeam;
          final wounded = team
              .where((h) => h.id != owner.id && h.isAlive)
              .where((h) => h.currentHealth / h.currentCp <= buff.triggerValue!)
              .toList();
          if (wounded.isEmpty) continue;

          List<String> targetIds;
          switch (buff.targetType) {
            case BuffTargetType.self:
              targetIds = [owner.id];
              break;
            case BuffTargetType.allTeammates:
              targetIds = team.where((h) => h.isAlive).map((h) => h.id).toList();
              break;
            case BuffTargetType.singleTeammate:
            default:
              targetIds = wounded.map((h) => h.id).toList();
              break;
          }

          for (final tid in targetIds) {
            if (!_isAlreadyActive(state, buff.id, tid)) {
              state = applyBuff(state, buff.id, tid);
            }
          }
        }
      } else if (condition == BuffTriggerCondition.onBattleStart ||
                 condition == BuffTriggerCondition.onTurnStart ||
                 condition == BuffTriggerCondition.onTurnEnd) {
        state = _applyBuffToTargets(state, buff);
      }
    }

    return state;
  }

  bool _isAlreadyActive(BattleInProgress state, String buffId, String heroId) {
    return state.activeBuffs.any((ab) => ab.buffId == buffId && ab.targetHeroId == heroId);
  }

  /// Olay-bazlı tetikleyicileri çalıştırır (defeat, skillUsed, damageTaken).
  /// [eventHeroId]: olayı yaşayan kahraman (ölen, hasar alan, skill kullanan).
  /// [isEventHeroPlayer]: olay-kahraman oyuncu takımında mı.
  ///
  /// Eşleşen buff için "sahip" tespiti prerequisites üzerinden yapılır:
  /// - `onDamageTaken`: sahip = eventHero (kahramanın kendisi)
  /// - diğerleri: sahip = eventHero'nun takımındaki, prerequisites'ı geçen herkes
  BattleInProgress checkEventTriggers(
    BattleInProgress currentState,
    BuffTriggerCondition condition,
    String eventHeroId,
    bool isEventHeroPlayer,
  ) {
    BattleInProgress state = currentState;

    for (final buff in state.allBuffs) {
      if (buff.triggerCondition != condition) continue;

      List<HeroCardEntity> ownerCandidates;
      if (condition == BuffTriggerCondition.onDamageTaken) {
        // Sahip = hasar alan kahramanın kendisi.
        final all = [...state.playerTeam, ...state.enemyTeam];
        final self = all.where((h) => h.id == eventHeroId && h.isAlive).toList();
        ownerCandidates = self;
      } else if (condition == BuffTriggerCondition.onEnemyDefeated) {
        // Sahip = düşen düşmanın KARŞI takımı (yani olay-kahramanın rakipleri).
        final ownerTeam = isEventHeroPlayer ? state.enemyTeam : state.playerTeam;
        ownerCandidates = ownerTeam.where((h) => h.isAlive).toList();
      } else {
        // onTeammateDefeated, onSkillUsed: sahip = olay-kahramanın takım arkadaşları.
        final ownerTeam = isEventHeroPlayer ? state.playerTeam : state.enemyTeam;
        ownerCandidates = ownerTeam.where((h) => h.isAlive && h.id != eventHeroId).toList();
      }

      for (final owner in ownerCandidates) {
        final ownerIsPlayer = state.playerTeam.any((h) => h.id == owner.id);
        if (!_isPrerequisiteMet(state, owner, ownerIsPlayer, buff.targetFilter)) continue;
        if (_isAlreadyActive(state, buff.id, owner.id)) continue;
        state = applyBuff(state, buff.id, owner.id);
      }
    }

    return state;
  }

  /// `onHpBelowPercent` tetikleyicisinin çağrı yerlerini sadeleştiren yardımcı.
  BattleInProgress checkHpTriggers(BattleInProgress state) {
    final s1 = checkAutoBuffs(state, BuffTriggerCondition.onHpBelowPercent);
    return checkAutoBuffs(s1, BuffTriggerCondition.onTeammateHpBelowPercent);
  }

  /// Çağıranın kolaylığı için eventHero'nun hangi takımda olduğunu otomatik bulur.
  BattleInProgress checkDefeatTriggers(BattleInProgress state, String defeatedHeroId) {
    final isPlayer = state.playerTeam.any((h) => h.id == defeatedHeroId);
    final s1 = checkEventTriggers(state, BuffTriggerCondition.onTeammateDefeated, defeatedHeroId, isPlayer);
    return checkEventTriggers(s1, BuffTriggerCondition.onEnemyDefeated, defeatedHeroId, isPlayer);
  }

  BattleInProgress checkDamageTakenTriggers(BattleInProgress state, String damagedHeroId) {
    final isPlayer = state.playerTeam.any((h) => h.id == damagedHeroId);
    return checkEventTriggers(state, BuffTriggerCondition.onDamageTaken, damagedHeroId, isPlayer);
  }

  BattleInProgress checkSkillUsedTriggers(BattleInProgress state, String casterHeroId) {
    final isPlayer = state.playerTeam.any((h) => h.id == casterHeroId);
    return checkEventTriggers(state, BuffTriggerCondition.onSkillUsed, casterHeroId, isPlayer);
  }

  /// Passive buff'ların ön koşullarını değerlendirir ve uygun olanlara uygular.
  /// Her tur sonunda veya savaş başlangıcında çağrılmalıdır.
  BattleInProgress checkPassiveBuffs(BattleInProgress state) {
    final passiveBuffIds = state.allBuffs
        .where((b) => b.triggerCondition == BuffTriggerCondition.passive)
        .map((b) => b.id)
        .toSet();

    // Mevcut passive aktif buff'ları temizle; ön koşullar her seferinde yeniden değerlendirilir.
    final withoutPassives = state.activeBuffs
        .where((ab) => !passiveBuffIds.contains(ab.buffId))
        .toList();

    BattleInProgress newState = state.copyWith(activeBuffs: withoutPassives);

    final passiveBuffs = state.allBuffs
        .where((b) => b.triggerCondition == BuffTriggerCondition.passive)
        .toList();

    for (final buff in passiveBuffs) {
      final allHeroes = [...newState.playerTeam, ...newState.enemyTeam];
      for (final hero in allHeroes) {
        if (!hero.isAlive) continue;
        final isPlayerTeam = newState.playerTeam.any((h) => h.id == hero.id);
        if (_isPrerequisiteMet(newState, hero, isPlayerTeam, buff.targetFilter)) {
          newState = applyBuff(newState, buff.id, hero.id);
        }
      }
    }

    // applyBuff içinde recalculate çağrıldığı için buradaki çağrı güvenlik katmanıdır.
    return recalculateAllHeroStats(newState);
  }

  bool _isSinglePrerequisiteMet(
    BattleInProgress state,
    HeroCardEntity hero,
    bool isPlayerTeam,
    BuffPrerequisite prereq,
  ) {
    switch (prereq.type) {
      case BuffPrerequisiteType.none:
        return true;
      case BuffPrerequisiteType.heroElementIs:
        return hero.element.name == prereq.value;
      case BuffPrerequisiteType.heroRoleIs:
        return hero.role.name == prereq.value;
      case BuffPrerequisiteType.hasTeammateWithElement:
        final team = isPlayerTeam ? state.playerTeam : state.enemyTeam;
        return team.any((h) => h.id != hero.id && h.isAlive && h.element.name == prereq.value);
      case BuffPrerequisiteType.hasTeammateWithRole:
        final team = isPlayerTeam ? state.playerTeam : state.enemyTeam;
        return team.any((h) => h.id != hero.id && h.isAlive && h.role.name == prereq.value);
      case BuffPrerequisiteType.heroIdIs:
        return hero.id == prereq.value;
      case BuffPrerequisiteType.heroHpBelowPercent:
        final pct = double.tryParse(prereq.value);
        if (pct == null || hero.currentCp <= 0) return false;
        return (hero.currentHealth / hero.currentCp) * 100 <= pct;
      case BuffPrerequisiteType.heroIdIn:
        // value: virgülle ayrılmış kahraman ID'leri. Bu prereq tek başına
        // OR semantiği taşır; birden fazla heroIdIn prereq'i AND'lenir.
        return prereq.value
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .contains(hero.id);
      case BuffPrerequisiteType.hasTeammateWithId:
        final team = isPlayerTeam ? state.playerTeam : state.enemyTeam;
        return team.any((h) => h.id != hero.id && h.isAlive && h.id == prereq.value);
      case BuffPrerequisiteType.hasEnemyWithElement:
        final opponents = isPlayerTeam ? state.enemyTeam : state.playerTeam;
        return opponents.any((h) => h.isAlive && h.element.name == prereq.value);
      case BuffPrerequisiteType.hasEnemyWithRole:
        final opponents = isPlayerTeam ? state.enemyTeam : state.playerTeam;
        return opponents.any((h) => h.isAlive && h.role.name == prereq.value);
    }
  }

  bool _isPrerequisiteMet(
    BattleInProgress state,
    HeroCardEntity hero,
    bool isPlayerTeam,
    List<BuffPrerequisite> prerequisites,
  ) {
    if (prerequisites.isEmpty) return true;
    return prerequisites.every((p) => _isSinglePrerequisiteMet(state, hero, isPlayerTeam, p));
  }

  /// Buff hedeflerine göre uygulamayı yönetir
  BattleInProgress _applyBuffToTargets(BattleInProgress state, BuffEntity buff) {
    List<String> targetIds = [];

    switch (buff.targetType) {
      case BuffTargetType.allTeammates:
        targetIds = state.playerTeam.where((h) => h.isAlive).map((h) => h.id).toList();
        break;
      case BuffTargetType.allEnemies:
        targetIds = state.enemyTeam.where((h) => h.isAlive).map((h) => h.id).toList();
        break;
      case BuffTargetType.self:
      case BuffTargetType.singleTeammate:
      case BuffTargetType.singleEnemy:
        // Otomatik tetiklenmede tek hedef belirlenemez; bu hedef tipleri
        // manuel akışlardan (skill, applyBuff doğrudan çağrı) tetiklenir.
        // TODO: tetikleyen kahramanın geçirilmesini destekleyecek context gerekirse genişlet.
        break;
    }

    BattleInProgress newState = state;
    for (final id in targetIds) {
      newState = applyBuff(newState, buff.id, id);
    }
    return newState;
  }

  /// Her tur sonunda DoT/HoT etkilerini uygular, ardından buff sürelerini
  /// azaltır ve süresi dolmuş olanları kaldırır.
  ///
  /// Sıralama önemli: önce etki uygulanır, sonra süre düşülür. Aksi halde
  /// `remainingTurns == 1` olan bir DoT son tikini atmadan kaldırılır.
  BattleInProgress processTurnEnd(BattleInProgress currentState) {
    // 1) Mevcut aktif buff'lar üzerinden DoT/HoT etkilerini uygula.
    BattleInProgress stateWithEffects = _applyOverTimeEffects(currentState);

    // 2) Süreleri azalt / bitenleri kaldır.
    final List<ActiveBuff> updatedActiveBuffs = [];
    final List<String> logs = List.from(stateWithEffects.battleLogs);

    for (final activeBuff in stateWithEffects.activeBuffs) {
      if (activeBuff.remainingTurns == -1) {
        updatedActiveBuffs.add(activeBuff);
      } else if (activeBuff.remainingTurns > 1) {
        updatedActiveBuffs.add(activeBuff.copyWith(remainingTurns: activeBuff.remainingTurns - 1));
      } else {
        final buff = stateWithEffects.allBuffs.where((b) => b.id == activeBuff.buffId).firstOrNull;
        final allHeroes = [...stateWithEffects.playerTeam, ...stateWithEffects.enemyTeam, ...stateWithEffects.benchHeroes];
        final hero = allHeroes.where((h) => h.id == activeBuff.targetHeroId).firstOrNull;
        if (buff != null && hero != null) {
          logs.insert(0, "${hero.name} üzerindeki ${buff.name} etkisi sona erdi.");
        }
      }
    }

    final pruned = stateWithEffects.copyWith(
      activeBuffs: updatedActiveBuffs,
      battleLogs: logs,
    );

    // 3) Stat'ları yeniden hesapla, ardından passive buff'ları tekrar değerlendir.
    final recalculated = recalculateAllHeroStats(pruned);
    return checkPassiveBuffs(recalculated);
  }

  /// DoT (Damage over Time) ve HoT (Heal over Time) etkilerini uygula
  BattleInProgress _applyOverTimeEffects(BattleInProgress state) {
    BattleInProgress newState = state;

    for (final activeBuff in state.activeBuffs) {
      final buff = state.allBuffs.where((b) => b.id == activeBuff.buffId).firstOrNull;
      if (buff == null) continue;

      if (buff.type == BuffType.dot || buff.type == BuffType.hot) {
        newState = _applySingleEffect(newState, buff, activeBuff.targetHeroId);
      }
    }

    return newState;
  }

  BattleInProgress _applySingleEffect(BattleInProgress state, BuffEntity buff, String heroId) {
    final isPlayerHero = state.playerTeam.any((h) => h.id == heroId);
    final team = isPlayerHero ? state.playerTeam : state.enemyTeam;
    final heroIndex = team.indexWhere((h) => h.id == heroId);

    if (heroIndex == -1) return state;

    final hero = team[heroIndex];
    if (!hero.isAlive) return state;

    HeroCardEntity updatedHero = hero;
    String logMsg = "";

    if (buff.type == BuffType.dot) {
      final raw = _resolveValue(buff, hero.currentCp).abs();
      final damage = raw < 1 ? 1 : raw;
      updatedHero = hero.copyWith(health: (hero.health - damage).clamp(0, hero.currentCp));
      logMsg = "${hero.name}, ${buff.name} etkisiyle $damage hasar aldı.";
    } else if (buff.type == BuffType.hot) {
      final raw = _resolveValue(buff, hero.currentCp);
      final heal = raw < 1 ? 1 : raw;
      updatedHero = hero.copyWith(health: (hero.health + heal).clamp(0, hero.currentCp));
      logMsg = "${hero.name}, ${buff.name} etkisiyle $heal can yeniledi.";
    }

    final updatedTeam = List<HeroCardEntity>.from(team);
    updatedTeam[heroIndex] = updatedHero;

    final updatedLogs = List<String>.from(state.battleLogs)..insert(0, logMsg);

    return isPlayerHero
        ? state.copyWith(playerTeam: updatedTeam, battleLogs: updatedLogs)
        : state.copyWith(enemyTeam: updatedTeam, battleLogs: updatedLogs);
  }

  /// Hedef kahramana gelen hasarın bir kısmını emmek için takım arkadaşlarını tarar.
  /// damageSoak tipinde aktif buff'u olan tüm uygun takım arkadaşları sıraya girer;
  /// her biri kendi soak yüzdesini orijinal hasardan keser. Toplam soak, hedefin
  /// en az 1 hasar almasını garantilemek için damage-1 ile sınırlandırılır.
  DamageSoakResult calculateDamageSoak(BattleInProgress state, String targetHeroId, int damage, {required bool isPlayerTarget}) {
    final defendingTeam = isPlayerTarget ? state.playerTeam : state.enemyTeam;

    final List<SoakEntry> soakers = [];
    int totalSoaked = 0;

    for (final teammate in defendingTeam) {
      if (!teammate.isAlive || teammate.id == targetHeroId) continue;

      for (final activeBuff in state.activeBuffs) {
        if (activeBuff.targetHeroId != teammate.id) continue;
        final buffEntity = state.allBuffs.firstWhere(
          (b) => b.id == activeBuff.buffId,
          orElse: () => const BuffEntity(
            id: '', name: '', description: '',
            type: BuffType.statChange, value: 0, duration: 0,
            targetType: BuffTargetType.self,
          ),
        );
        if (buffEntity.id.isEmpty || buffEntity.type != BuffType.damageSoak) continue;

        // Her tank kendi yüzdesiyle orijinal hasarı emer (kümülatif değil)
        final soakPercent = buffEntity.value;
        final soakedByThisTank = (damage * soakPercent / 100).round().clamp(1, damage);
        soakers.add(SoakEntry(heroId: teammate.id, amount: soakedByThisTank));
        totalSoaked += soakedByThisTank;
        break; // bu takım arkadaşı için ilk damageSoak buff'ı yeterli
      }
    }

    if (soakers.isEmpty) return DamageSoakResult(soakers: const [], remainingDamage: damage);

    // Hedef en az 1 hasar almalı; fazla soak oransal olarak kırpılır
    final cappedTotal = totalSoaked.clamp(0, damage - 1);
    final List<SoakEntry> cappedSoakers;
    if (cappedTotal == totalSoaked) {
      cappedSoakers = soakers;
    } else {
      final ratio = cappedTotal / totalSoaked;
      cappedSoakers = soakers.map((e) => SoakEntry(heroId: e.heroId, amount: (e.amount * ratio).round())).toList();
    }

    return DamageSoakResult(soakers: cappedSoakers, remainingDamage: damage - cappedTotal);
  }

  /// Soak miktarlarını absorbe eden her kahramanın canından düşer.
  BattleInProgress applySoakDamage(BattleInProgress state, List<SoakEntry> soakers) {
    BattleInProgress current = state;
    for (final entry in soakers) {
      final isPlayer = current.playerTeam.any((h) => h.id == entry.heroId);
      if (isPlayer) {
        final updated = current.playerTeam.map((h) {
          if (h.id != entry.heroId) return h;
          return h.copyWith(health: (h.health - entry.amount).clamp(0, h.currentCp));
        }).toList();
        current = current.copyWith(playerTeam: updated);
      } else {
        final updated = current.enemyTeam.map((h) {
          if (h.id != entry.heroId) return h;
          return h.copyWith(health: (h.health - entry.amount).clamp(0, h.currentCp));
        }).toList();
        current = current.copyWith(enemyTeam: updated);
      }
    }
    return current;
  }

  /// Tüm kahramanların bonus statlarını aktif buff'lara göre yeniden hesaplar.
  /// Yedek kadrodaki kahramanların statları da güncellenir (geri döndüklerinde doğru görünsün).
  BattleInProgress recalculateAllHeroStats(BattleInProgress state) {
    final updatedPlayerTeam = state.playerTeam.map((h) => _calculateHeroStats(h, state.activeBuffs, state.allBuffs)).toList();
    final updatedEnemyTeam = state.enemyTeam.map((h) => _calculateHeroStats(h, state.activeBuffs, state.allBuffs)).toList();
    final updatedBenchHeroes = state.benchHeroes.map((h) => _calculateHeroStats(h, state.activeBuffs, state.allBuffs)).toList();

    return state.copyWith(
      playerTeam: updatedPlayerTeam,
      enemyTeam: updatedEnemyTeam,
      benchHeroes: updatedBenchHeroes,
    );
  }

  HeroCardEntity _calculateHeroStats(HeroCardEntity hero, List<ActiveBuff> activeBuffs, List<BuffEntity> allBuffs) {
    int bonusAtk = 0;
    int bonusDef = 0;
    int bonusMaxHp = 0;

    final heroBuffs = activeBuffs.where((ab) => ab.targetHeroId == hero.id);

    for (final activeBuff in heroBuffs) {
      final buff = allBuffs.where((b) => b.id == activeBuff.buffId).firstOrNull;
      if (buff == null) continue;
      if (buff.type != BuffType.statChange) continue;

      switch (buff.statType) {
        case StatType.attack:
          bonusAtk += _resolveValue(buff, hero.baseAttackScaled);
          break;
        case StatType.defense:
          bonusDef += _resolveValue(buff, hero.baseDefenseScaled);
          break;
        case StatType.maxHealth:
          bonusMaxHp += _resolveValue(buff, hero.baseMaxHealthScaled);
          break;
        case StatType.currentHealth:
        case null:
          // currentHealth statChange üzerinden yürütülmez; bunun için
          // BuffType.hot / BuffType.dot kullanılmalı.
          break;
      }
    }

    // Max HP düşerse mevcut canı yeni tavana clamp et (taşmayı engelle).
    final newMaxHp = hero.baseMaxHealthScaled + bonusMaxHp;
    final clampedHealth = hero.health > newMaxHp ? newMaxHp : hero.health;

    return hero.copyWith(
      bonusAttack: bonusAtk,
      bonusDefense: bonusDef,
      bonusMaxHealth: bonusMaxHp,
      health: clampedHealth,
    );
  }

  /// Caster'ın karşı takımındaki rastgele canlı bir kahramanın N (buff.value)
  /// aktif buff'ını siler. ActiveBuff listesi kalıcı olarak güncellenir.
  /// Anlık efekttir — kendisi ActiveBuff olarak eklenmez.
  BattleInProgress _applyDispel(BattleInProgress state, BuffEntity buff, String casterId) {
    final casterIsPlayer = state.playerTeam.any((h) => h.id == casterId);
    final enemyTeam = casterIsPlayer ? state.enemyTeam : state.playerTeam;
    final liveEnemies = enemyTeam.where((h) => h.isAlive).toList();
    if (liveEnemies.isEmpty) return state;

    final candidates = liveEnemies
        .where((h) => state.activeBuffs.any((ab) => ab.targetHeroId == h.id))
        .toList();
    if (candidates.isEmpty) return state;

    final victim = candidates[Random().nextInt(candidates.length)];
    final removeCount = buff.value <= 0 ? 1 : buff.value;

    // En sonda eklenen aktif buff'lar listede en sondadır — sondan başla.
    final victimBuffs = <int>[];
    for (int i = state.activeBuffs.length - 1; i >= 0 && victimBuffs.length < removeCount; i--) {
      if (state.activeBuffs[i].targetHeroId == victim.id) {
        victimBuffs.add(i);
      }
    }
    if (victimBuffs.isEmpty) return state;

    final removedSet = victimBuffs.toSet();
    final updatedActive = <ActiveBuff>[];
    final removedNames = <String>[];
    for (int i = 0; i < state.activeBuffs.length; i++) {
      if (removedSet.contains(i)) {
        final ab = state.activeBuffs[i];
        final b = state.allBuffs.where((x) => x.id == ab.buffId).firstOrNull;
        if (b != null) removedNames.add(b.name);
      } else {
        updatedActive.add(state.activeBuffs[i]);
      }
    }

    final log =
        "${victim.name} üzerindeki ${removedNames.join(', ')} etkisi ${buff.name} ile temizlendi.";
    final logs = List<String>.from(state.battleLogs)..insert(0, log);
    final next = state.copyWith(activeBuffs: updatedActive, battleLogs: logs);
    return recalculateAllHeroStats(next);
  }

  /// Hedef kahramanın aktif damageRedirect buff'ı varsa, gelen [damage]'in
  /// `value%`'unu rakip takımdaki tüm canlı kahramanlara eşit böler.
  /// Geri kalan kısım [remainingDamage] olarak normal akışa devam eder.
  /// Hedefte aktif redirect buff'ı yoksa hasarı olduğu gibi döner.
  DamageRedirectResult calculateDamageRedirect(
    BattleInProgress state,
    String targetHeroId,
    int damage, {
    required bool isPlayerTarget,
  }) {
    // Hedefin aktif damageRedirect buff'larından en yüksek yüzdeliyi seç.
    int bestPercent = 0;
    String? bestBuffName;
    for (final ab in state.activeBuffs) {
      if (ab.targetHeroId != targetHeroId) continue;
      final b = state.allBuffs.where((x) => x.id == ab.buffId).firstOrNull;
      if (b == null || b.type != BuffType.damageRedirect) continue;
      if (b.value > bestPercent) {
        bestPercent = b.value;
        bestBuffName = b.name;
      }
    }
    if (bestPercent <= 0 || bestBuffName == null) {
      return DamageRedirectResult(
          remainingDamage: damage, perEnemyDamage: const {}, buffName: null);
    }

    final enemyTeam = isPlayerTarget ? state.enemyTeam : state.playerTeam;
    final liveEnemies = enemyTeam.where((h) => h.isAlive).toList();
    if (liveEnemies.isEmpty) {
      return DamageRedirectResult(
          remainingDamage: damage, perEnemyDamage: const {}, buffName: null);
    }

    final clamped = bestPercent.clamp(0, 100);
    final redirected = (damage * clamped / 100).round();
    final remaining = damage - redirected;
    if (redirected <= 0) {
      return DamageRedirectResult(
          remainingDamage: damage, perEnemyDamage: const {}, buffName: null);
    }

    final perEnemy = (redirected / liveEnemies.length).floor();
    final remainder = redirected - perEnemy * liveEnemies.length;
    final map = <String, int>{};
    for (int i = 0; i < liveEnemies.length; i++) {
      final extra = i < remainder ? 1 : 0;
      final amount = perEnemy + extra;
      if (amount > 0) map[liveEnemies[i].id] = amount;
    }

    return DamageRedirectResult(
        remainingDamage: remaining, perEnemyDamage: map, buffName: bestBuffName);
  }

  /// Yansıtılan hasarı her bir düşmana doğrudan uygular (defense/element/arena bypass).
  /// Ölüm tespit edilirse defeat trigger'ları motorda zincirlenir.
  BattleInProgress applyRedirectDamage(BattleInProgress state, Map<String, int> perEnemyDamage) {
    BattleInProgress current = state;
    perEnemyDamage.forEach((heroId, amount) {
      final isPlayer = current.playerTeam.any((h) => h.id == heroId);
      if (isPlayer) {
        final updated = current.playerTeam.map((h) {
          if (h.id != heroId) return h;
          return h.copyWith(health: (h.health - amount).clamp(0, h.currentCp));
        }).toList();
        current = current.copyWith(playerTeam: updated);
      } else {
        final updated = current.enemyTeam.map((h) {
          if (h.id != heroId) return h;
          return h.copyWith(health: (h.health - amount).clamp(0, h.currentCp));
        }).toList();
        current = current.copyWith(enemyTeam: updated);
      }
    });
    return current;
  }

  /// Buff'ın `valueMode`'una göre bonus miktarını çözer.
  /// percent → temel statın yüzdesi, absolute → ham değer.
  int _resolveValue(BuffEntity buff, int base) {
    if (buff.valueMode == ValueMode.percent) {
      return (base * buff.value / 100).round();
    }
    return buff.value;
  }
}
