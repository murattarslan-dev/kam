import '../../presentation/manager/battle_state.dart';

class ExecutePlayerAttackUseCase {
  BattleState execute(BattleInProgress currentState) {
    if (currentState.selectedHeroIndex == null || currentState.selectedTargetIndex == null) return currentState;

    final attacker = currentState.playerTeam[currentState.selectedHeroIndex!];
    final target = currentState.enemyTeam[currentState.selectedTargetIndex!];

    return currentState.copyWith(
      currentAction: BattleAction(
        attacker: attacker,
        target: target,
        isPlayerAttacking: true,
      ),
    );
  }
}
