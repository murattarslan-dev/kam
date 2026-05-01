import 'dart:math';
import 'dart:async';
import '../../presentation/manager/battle_state.dart';

class ExecuteEnemyTurnUseCase {
  Future<void> execute({
    required BattleInProgress currentState,
    required Function(BattleState) onEmit,
    required Future<void> Function() waitForAnimation,
    required Future<void> Function(bool isVictory) onFinalize,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    var current = currentState;
    final aliveEnemies = current.enemyTeam.where((e) => e.isAlive).toList();

    for (var enemy in aliveEnemies) {
      // Her düşman saldırısı arasında kısa bir bekletme
      await Future.delayed(const Duration(milliseconds: 800));

      final alivePlayers = current.playerTeam.where((p) => p.isAlive).toList();
      if (alivePlayers.isEmpty) break;

      // Rastgele bir hedef seç
      final target = alivePlayers[Random().nextInt(alivePlayers.length)];
      
      // Animasyonu başlat
      onEmit(current.copyWith(
        currentAction: BattleAction(
          attacker: enemy,
          target: target,
          isPlayerAttacking: false,
        ),
      ));

      // Animasyonun bitmesini bekle
      await waitForAnimation();

      final rawDamage = (enemy.currentAttackPower * enemy.element.getDamageMultiplier(target.element)).round();
      final defenseReduction = (target.currentDefensePower * 0.2).round();
      final damage = max(1, rawDamage - defenseReduction);

      final updatedPlayerTeam = current.playerTeam.map((p) {
        if (p.id == target.id) {
          return p.copyWith(health: (p.health - damage).clamp(0, p.currentCp).toInt());
        }
        return p;
      }).toList();

      final log = "${enemy.name} hiddetle saldırdı: ${target.name} $damage hasar aldı!";

      current = current.copyWith(
        playerTeam: updatedPlayerTeam,
        battleLogs: [log, ...current.battleLogs],
        clearAction: true,
      );

      onEmit(current);

      // Kaybetme Kontrolü
      if (updatedPlayerTeam.every((p) => !p.isAlive)) {
        await onFinalize(false);
        onEmit(const BattleResult(message: "MAĞLUBİYET... Kut elimizden kayıp gitti.", isVictory: false));
        return;
      }
    }

    // Düşman turu bitti, yeni tura geç ve oyuncuya ver
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Yeni turda oyuncunun yaşayan karakterlerine +1 Kut
    final updatedPlayerTeam = current.playerTeam.map((p) {
      if (p.isAlive) {
        return p.copyWith(kut: p.kut + 1);
      }
      return p;
    }).toList();

    final nextTurnState = current.copyWith(
      playerTeam: updatedPlayerTeam,
      isPlayerTurn: true,
      currentTurn: current.currentTurn + 1,
      actedHeroIds: [],
      battleLogs: ["Yeni Tur başladı (${current.currentTurn + 1}). Tüm canlı kahramanlar +1 Kut kazandı!", ...current.battleLogs],
    );
    onEmit(nextTurnState);
  }
}
