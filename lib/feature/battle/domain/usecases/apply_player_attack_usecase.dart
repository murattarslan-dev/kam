import 'dart:math';
import '../entities/hero_entities.dart';
import '../entities/buff_entities.dart';
import '../../presentation/manager/battle_state.dart';
import 'handle_buffs_usecase.dart';

class ApplyPlayerAttackUseCase {
  final HandleBuffsUseCase _handleBuffsUseCase;

  ApplyPlayerAttackUseCase(this._handleBuffsUseCase);

  BattleState execute(BattleInProgress currentState, BattleAction action) {
    final attacker = action.attacker;
    final target = action.target;

    // Hasar hesaplama
    final rawDamage = (attacker.currentAttackPower * attacker.element.getDamageMultiplier(target.element)).round();
    final defenseReduction = (target.currentDefensePower).round();
    final damage = max(1, rawDamage - defenseReduction);

    // Düşman tarafında hasar emme kontrolü
    final soakResult = _handleBuffsUseCase.calculateDamageSoak(currentState, target.id, damage, isPlayerTarget: false);
    final finalDamage = soakResult.remainingDamage;

    final newHealth = (target.health - finalDamage).clamp(0, target.currentCp).toDouble();

    int earnedKut = 0;
    if (newHealth <= 0) {
      earnedKut = 2;
    }

    // Düşman takımını güncelle
    List<HeroCardEntity> updatedEnemyTeam = List<HeroCardEntity>.from(currentState.enemyTeam);
    final targetIndex = updatedEnemyTeam.indexWhere((e) => e.id == target.id);
    if (targetIndex != -1) {
      updatedEnemyTeam[targetIndex] = target.copyWith(health: newHealth.toInt());
    }

    // Oyuncu takımını güncelle
    final updatedPlayerTeam = List<HeroCardEntity>.from(currentState.playerTeam);
    final attackerIndex = updatedPlayerTeam.indexWhere((p) => p.id == attacker.id);
    if (attackerIndex != -1) {
      updatedPlayerTeam[attackerIndex] = attacker.copyWith(kut: attacker.kut + earnedKut);
    }

    final logs = List<String>.from(currentState.battleLogs);
    logs.insert(0, "${attacker.name}, ${target.name} birimine $finalDamage hasar verdi!${earnedKut > 0 ? " (+2 Kut kazandı!)" : ""}");

    final updatedDamageMap = Map<String, double>.from(currentState.totalDamageDealt);
    updatedDamageMap[attacker.id] = (updatedDamageMap[attacker.id] ?? 0) + finalDamage;

    final updatedActedIds = List<String>.from(currentState.actedHeroIds)..add(attacker.id);

    BattleInProgress nextState = currentState.copyWith(
      playerTeam: updatedPlayerTeam,
      enemyTeam: updatedEnemyTeam,
      battleLogs: logs,
      actedHeroIds: updatedActedIds,
      totalDamageDealt: updatedDamageMap,
      clearSelection: true,
      clearAction: true,
    );

    // Soak hasarını absorbe eden tüm tanklara uygula
    if (soakResult.hasSoak) {
      nextState = _handleBuffsUseCase.applySoakDamage(nextState, soakResult.soakers);
      final allHeroes = [...nextState.playerTeam, ...nextState.enemyTeam];
      for (final entry in soakResult.soakers) {
        final soakerName = allHeroes.firstWhere((h) => h.id == entry.heroId).name;
        final soakLog = "$soakerName takım arkadaşının yerine ${entry.amount} hasarı üstlendi! (hasar emme)";
        nextState = nextState.copyWith(battleLogs: [soakLog, ...nextState.battleLogs]);
      }
    }

    // Hasar sonrası HP eşiği tetikleyicilerini kontrol et.
    nextState = _handleBuffsUseCase.checkHpTriggers(nextState);

    return _processTurnEnd(nextState);
  }

  BattleState _processTurnEnd(BattleInProgress nextState) {
    // 1. Kazanma Kontrolü
    if (nextState.enemyTeam.every((e) => !e.isAlive)) {
      return const BattleResult(
        message: "ZAFER! Karanlık ordu bozguna uğratıldı.",
        isVictory: true,
        rewards: ["100 Altın", "Kadim Ruh Parçası"],
      );
    }

    // 2. Sıra Değişim Kontrolü (Tüm yaşayan oyuncular hamle yaptı mı?)
    final alivePlayerCount = nextState.playerTeam.where((p) => p.isAlive).length;
    if (nextState.actedHeroIds.length >= alivePlayerCount) {
      // Oyuncu turu bitiyor — onTurnEnd tetikleyicilerini çalıştır.
      final stateAfterTurnEnd = _handleBuffsUseCase.checkAutoBuffs(
        nextState,
        BuffTriggerCondition.onTurnEnd,
      );

      return stateAfterTurnEnd.copyWith(
        isPlayerTurn: false,
        actedHeroIds: [], // Düşman için hamle listesini temizle
        battleLogs: ["Sıra düşmanda! Savunmaya geç!", ...stateAfterTurnEnd.battleLogs],
      );
    } else {
      return nextState;
    }
  }
}
