import '../entities/hero_entities.dart';
import '../entities/buff_entities.dart';
import '../../presentation/manager/battle_state.dart';
import 'handle_buffs_usecase.dart';

class SwapHeroUseCase {
  final HandleBuffsUseCase _handleBuffsUseCase;

  SwapHeroUseCase(this._handleBuffsUseCase);

  /// Sahadaki [fieldIndex] numaralı kahramanı yedek kadrodaki [benchIndex]
  /// numaralı kahraman ile değiştirir. Değişim bir tur aksiyonu sayılır,
  /// oyuncu turu hemen sona erer ve düşman sırası başlar.
  BattleState execute(BattleInProgress state, int fieldIndex, int benchIndex) {
    if (fieldIndex < 0 || fieldIndex >= state.playerTeam.length) return state;
    if (benchIndex < 0 || benchIndex >= state.benchHeroes.length) return state;

    final fieldHero = state.playerTeam[fieldIndex];
    final benchHero = state.benchHeroes[benchIndex];

    final updatedTeam = List<HeroCardEntity>.from(state.playerTeam);
    updatedTeam[fieldIndex] = benchHero;

    final updatedBench = List<HeroCardEntity>.from(state.benchHeroes);
    updatedBench[benchIndex] = fieldHero;

    final log = "${fieldHero.name} sahadan çekildi, ${benchHero.name} sahaya girdi!";
    final updatedLogs = List<String>.from(state.battleLogs)..insert(0, log);

    final stateAfterSwap = state.copyWith(
      playerTeam: updatedTeam,
      benchHeroes: updatedBench,
      battleLogs: updatedLogs,
      actedHeroIds: const [],
      clearSelection: true,
    );

    // Değişim turu sona erdiriyor — onTurnEnd tetikleyicileri çalışsın.
    final stateAfterTurnEnd = _handleBuffsUseCase.checkAutoBuffs(
      stateAfterSwap,
      BuffTriggerCondition.onTurnEnd,
    );

    return stateAfterTurnEnd.copyWith(
      isPlayerTurn: false,
      battleLogs: ["Sıra düşmanda! Savunmaya geç!", ...stateAfterTurnEnd.battleLogs],
    );
  }
}
