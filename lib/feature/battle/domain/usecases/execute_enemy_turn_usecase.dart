import 'dart:math';
import 'dart:async';
import '../../presentation/manager/battle_state.dart';
import '../entities/buff_entities.dart';
import 'handle_buffs_usecase.dart';

class ExecuteEnemyTurnUseCase {
  final HandleBuffsUseCase _handleBuffsUseCase;

  ExecuteEnemyTurnUseCase(this._handleBuffsUseCase);

  static Map<String, int> _computeXpGains(BattleInProgress state, {required bool isVictory}) {
    final result = <String, int>{};
    for (final hero in state.playerTeam) {
      final dmgXp = (state.totalDamageDealt[hero.id] ?? 0).round();
      final bonusXp = isVictory ? 300 : 0;
      result[hero.id] = dmgXp + bonusXp;
    }
    return result;
  }

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

      // Oyuncu tarafında hasar emme kontrolü
      final soakResult = _handleBuffsUseCase.calculateDamageSoak(current, target.id, damage, isPlayerTarget: true);
      final finalDamage = soakResult.remainingDamage;

      var updatedPlayerTeam = current.playerTeam.map((p) {
        if (p.id == target.id) {
          return p.copyWith(health: (p.health - finalDamage).clamp(0, p.currentCp).toInt());
        }
        return p;
      }).toList();

      final updatedReceivedMap = Map<String, double>.from(current.totalDamageReceived);
      updatedReceivedMap[target.id] = (updatedReceivedMap[target.id] ?? 0) + finalDamage;

      final logs = <String>["${enemy.name} hiddetle saldırdı: ${target.name} $finalDamage hasar aldı!"];

      current = current.copyWith(
        playerTeam: updatedPlayerTeam,
        totalDamageReceived: updatedReceivedMap,
        battleLogs: [...logs, ...current.battleLogs],
        clearAction: true,
      );

      // Soak hasarını absorbe eden tüm tanklara uygula
      if (soakResult.hasSoak) {
        current = _handleBuffsUseCase.applySoakDamage(current, soakResult.soakers);
        for (final entry in soakResult.soakers) {
          final soakerName = current.playerTeam.firstWhere((h) => h.id == entry.heroId).name;
          final soakLog = "$soakerName takım arkadaşının yerine ${entry.amount} hasarı üstlendi! (hasar emme)";
          current = current.copyWith(battleLogs: [soakLog, ...current.battleLogs]);
        }
      }

      // Hasar sonrası HP eşiği tetikleyicilerini kontrol et.
      current = _handleBuffsUseCase.checkHpTriggers(current);

      onEmit(current);

      // Kaybetme Kontrolü
      if (current.playerTeam.every((p) => !p.isAlive)) {
        await onFinalize(false);
        onEmit(BattleResult(
          message: "MAĞLUBİYET... Kut elimizden kayıp gitti.",
          isVictory: false,
          playerTeam: current.playerTeam,
          benchHeroes: current.benchHeroes,
          totalDamageDealt: current.totalDamageDealt,
          totalDamageReceived: current.totalDamageReceived,
          heroXpGained: _computeXpGains(current, isVictory: false),
          activeBuffs: current.activeBuffs,
          allBuffs: current.allBuffs,
        ));
        return;
      }
    }

    // Düşman turu bitti, yeni tura geç ve oyuncuya ver
    await Future.delayed(const Duration(milliseconds: 500));

    // 1. Düşman turu bitiyor — onTurnEnd tetikleyicileri.
    current = _handleBuffsUseCase.checkAutoBuffs(current, BuffTriggerCondition.onTurnEnd);

    // 2. Tur sonu buff işlemlerini yap (DoT/HoT etkileri ve süre azaltma).
    current = _handleBuffsUseCase.processTurnEnd(current);

    // 3. DoT etkilerinden sonra oluşan HP düşüşleri için bir kez daha eşik kontrolü.
    current = _handleBuffsUseCase.checkHpTriggers(current);

    // 4. Yeni tur başında tetiklenen buff'ları kontrol et.
    current = _handleBuffsUseCase.checkAutoBuffs(current, BuffTriggerCondition.onTurnStart);

    // 5. Passive buff'ları yeni tur başında yeniden değerlendir.
    current = _handleBuffsUseCase.checkPassiveBuffs(current);

    // Yeni turda oyuncunun yaşayan karakterlerine +1 Kut (DoT sonrası güncel state üzerinden)
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
