import '../entities/hero_entities.dart';
import '../entities/buff_entities.dart';
import '../../presentation/manager/battle_state.dart';

class SoakEntry {
  final String heroId;
  final int amount;
  const SoakEntry({required this.heroId, required this.amount});
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
    final buff = currentState.allBuffs.firstWhere((b) => b.id == buffId);

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
      } else if (condition == BuffTriggerCondition.onBattleStart ||
                 condition == BuffTriggerCondition.onTurnStart ||
                 condition == BuffTriggerCondition.onTurnEnd) {
        state = _applyBuffToTargets(state, buff);
      }
    }

    return state;
  }

  /// `onHpBelowPercent` tetikleyicisinin çağrı yerlerini sadeleştiren yardımcı.
  BattleInProgress checkHpTriggers(BattleInProgress state) {
    return checkAutoBuffs(state, BuffTriggerCondition.onHpBelowPercent);
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
        if (_isPrerequisiteMet(newState, hero, isPlayerTeam, buff.prerequisites)) {
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
        final buff = stateWithEffects.allBuffs.firstWhere((b) => b.id == activeBuff.buffId);
        final allHeroes = [...stateWithEffects.playerTeam, ...stateWithEffects.enemyTeam, ...stateWithEffects.benchHeroes];
        final hero = allHeroes.where((h) => h.id == activeBuff.targetHeroId).firstOrNull;
        if (hero != null) {
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
      final buff = state.allBuffs.firstWhere((b) => b.id == activeBuff.buffId);

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
      final damage = buff.value.abs();
      updatedHero = hero.copyWith(health: (hero.health - damage).clamp(0, hero.currentCp));
      logMsg = "${hero.name}, ${buff.name} etkisiyle $damage hasar aldı.";
    } else if (buff.type == BuffType.hot) {
      final heal = buff.value;
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

    final heroBuffs = activeBuffs.where((ab) => ab.targetHeroId == hero.id);

    for (final activeBuff in heroBuffs) {
      final buff = allBuffs.firstWhere((b) => b.id == activeBuff.buffId);
      if (buff.type == BuffType.statChange) {
        if (buff.statType == StatType.attack) {
          bonusAtk += buff.value;
        } else if (buff.statType == StatType.defense) {
          bonusDef += buff.value;
        }
      }
    }

    return hero.copyWith(
      bonusAttack: bonusAtk,
      bonusDefense: bonusDef,
    );
  }
}
