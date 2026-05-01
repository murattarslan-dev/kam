import 'dart:math';
import '../entities/hero_entities.dart';
import '../../presentation/manager/battle_state.dart';

class ApplyPlayerAttackUseCase {
  BattleState execute(BattleInProgress currentState, BattleAction action) {
    final attacker = action.attacker;
    final target = action.target;

    // Hasar hesaplama
    final rawDamage = (attacker.currentAttackPower * attacker.element.getDamageMultiplier(target.element)).round();
    final defenseReduction = (target.currentDefensePower).round();
    final damage = max(1, rawDamage - defenseReduction);
    final newHealth = (target.health - damage).clamp(0, target.currentCp).toDouble();

    int earnedKut = 0;
    if (newHealth <= 0) {
      earnedKut = 2;
    }

    // Düşman takımını güncelle
    final updatedEnemyTeam = List<HeroCardEntity>.from(currentState.enemyTeam);
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

    final newLog = "${attacker.name}, ${target.name} birimine $damage hasar verdi!${earnedKut > 0 ? " (+2 Kut kazandı!)" : ""}";
    final updatedLogs = List<String>.from(currentState.battleLogs)..insert(0, newLog);

    final updatedDamageMap = Map<String, double>.from(currentState.totalDamageDealt);
    updatedDamageMap[attacker.id] = (updatedDamageMap[attacker.id] ?? 0) + damage;

    final updatedActedIds = List<String>.from(currentState.actedHeroIds)..add(attacker.id);

    final nextState = currentState.copyWith(
      playerTeam: updatedPlayerTeam,
      enemyTeam: updatedEnemyTeam,
      battleLogs: updatedLogs,
      actedHeroIds: updatedActedIds,
      totalDamageDealt: updatedDamageMap,
      clearSelection: true,
      clearAction: true,
    );

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
      // Oyuncu turu bitti, düşman turuna geç
      return nextState.copyWith(
        isPlayerTurn: false,
        actedHeroIds: [], // Düşman için hamle listesini temizle
        battleLogs: ["Sıra düşmanda! Savunmaya geç!", ...nextState.battleLogs],
      );
    } else {
      return nextState;
    }
  }
}
