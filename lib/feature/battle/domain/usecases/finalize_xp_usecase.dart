import 'package:flutter/foundation.dart';
import '../../presentation/manager/battle_state.dart';
import '../repository/battle_repository.dart';

class FinalizeXpUseCase {
  final BattleRepository _repository;

  FinalizeXpUseCase(this._repository);

  Future<void> execute({required BattleInProgress currentState, required bool isVictory}) async {
    try {
      final user = _repository.currentUser;
      if (user == null) return;

      for (var hero in currentState.playerTeam) {
        // 1. Verdiği hasar kadar XP
        int damageXp = (currentState.totalDamageDealt[hero.id] ?? 0).round();
        
        // 2. Zafer bonusu
        int victoryXp = isVictory ? 300 : 0;
        
        int totalGain = damageXp + victoryXp;
        
        if (totalGain > 0) {
          // Firestore'u güncelle
          await _repository.updateHeroXp(user.uid, hero.id, totalGain);
        }
      }
    } catch (e) {
      debugPrint("XP güncellenirken hata: $e");
    }
  }
}
