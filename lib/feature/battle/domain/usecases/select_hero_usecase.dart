import '../../presentation/manager/battle_state.dart';

class SelectHeroUseCase {
  BattleState execute(BattleInProgress currentState, int index, bool isEnemy) {
    // Sıra oyuncuda değilse seçim yapılamaz
    if (!currentState.isPlayerTurn) return currentState;

    if (isEnemy) {
      // Oyuncu kartı seçilmeden düşman seçilemez
      if (currentState.selectedHeroIndex == null) return currentState;
      
      // Düşman kartına tıklandı: Hedef seçimi
      if (currentState.enemyTeam[index].isAlive) {
        if (currentState.selectedTargetIndex == index) {
          return currentState.copyWith(clearTarget: true);
        } else {
          return currentState.copyWith(selectedTargetIndex: index);
        }
      }
    } else {
      // Oyuncu kartına tıklandı: Saldırgan seçimi
      final hero = currentState.playerTeam[index];
      // Kart yaşıyorsa ve bu tur hamle yapmadıysa seçilebilir
      if (hero.isAlive && !currentState.actedHeroIds.contains(hero.id)) {
        if (currentState.selectedHeroIndex == index) {
          return currentState.copyWith(clearSelection: true);
        } else {
          return currentState.copyWith(selectedHeroIndex: index);
        }
      }
    }
    return currentState;
  }
}
