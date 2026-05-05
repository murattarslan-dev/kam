import '../../domain/entities/hero_entities.dart';
import '../../domain/entities/battle_event.dart';
import '../../presentation/manager/battle_state.dart';

/// Aktif savaşların Firestore'a yazımını yöneten datasource.
abstract class BattleLogDataSource {
  Future<String?> createBattle({
    required Map<String, dynamic> player,
    required Map<String, dynamic> opponent,
    required List<HeroCardEntity> playerTeam,
    required List<HeroCardEntity> enemyTeam,
  });

  Future<void> appendEvent({
    required String battleId,
    required BattleEventDto event,
    required BattleInProgress stateAfter,
  });

  Future<void> finalizeBattle({
    required String battleId,
    required bool isVictory,
    required String message,
    required List<String> rewards,
    required BattleInProgress lastState,
    Map<String, int> heroXpGained = const {},
  });
}
