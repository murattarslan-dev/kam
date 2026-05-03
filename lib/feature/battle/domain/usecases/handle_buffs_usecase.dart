import '../entities/hero_entities.dart';
import '../entities/buff_entities.dart';
import '../../presentation/manager/battle_state.dart';

class HandleBuffsUseCase {
  /// Bir buff'ı manuel veya tetiklenme sonucu bir kahramana uygular.
  BattleInProgress applyBuff(BattleInProgress currentState, String buffId, String targetHeroId) {
    final buff = currentState.allBuffs.firstWhere((b) => b.id == buffId);
    
    // Eğer buff zaten aktifse (aynı kahramanda), süresini yenileyebiliriz veya stackleyebiliriz.
    // Şimdilik süresini yenileyelim.
    final existingIndex = currentState.activeBuffs.indexWhere(
      (ab) => ab.buffId == buffId && ab.targetHeroId == targetHeroId
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

    return recalculateAllHeroStats(pruned);
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
