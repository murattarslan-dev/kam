import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../manager/battle_state.dart';
import '../../domain/entities/hero_entities.dart';
import '../../domain/usecases/start_battle_usecase.dart';
import '../../domain/usecases/select_hero_usecase.dart';
import '../../domain/usecases/execute_player_attack_usecase.dart';
import '../../domain/usecases/apply_player_attack_usecase.dart';
import '../../domain/usecases/use_skill_usecase.dart';
import '../../domain/usecases/execute_enemy_turn_usecase.dart';
import '../../domain/usecases/finalize_xp_usecase.dart';
import '../../domain/usecases/handle_buffs_usecase.dart';
import '../../domain/usecases/swap_hero_usecase.dart';
import '../../domain/entities/buff_entities.dart';

class BattleCubit extends Cubit<BattleState> {
  final StartBattleUseCase _startBattleUseCase;
  final SelectHeroUseCase _selectHeroUseCase;
  final ExecutePlayerAttackUseCase _executePlayerAttackUseCase;
  final ApplyPlayerAttackUseCase _applyPlayerAttackUseCase;
  final UseSkillUseCase _useSkillUseCase;
  final ExecuteEnemyTurnUseCase _executeEnemyTurnUseCase;
  final FinalizeXpUseCase _finalizeXpUseCase;
  final HandleBuffsUseCase _handleBuffsUseCase;
  final SwapHeroUseCase _swapHeroUseCase;

  BattleCubit(
    this._startBattleUseCase,
    this._selectHeroUseCase,
    this._executePlayerAttackUseCase,
    this._applyPlayerAttackUseCase,
    this._useSkillUseCase,
    this._executeEnemyTurnUseCase,
    this._finalizeXpUseCase,
    this._handleBuffsUseCase,
    this._swapHeroUseCase,
  ) : super(const BattleInitial());

  /// Takım hazırlama ekranından veya doğrudan başlatma ile savaşı başlatır.
  /// [playerTeam] ve [benchHeroes] verilirse bunlar kullanılır, verilmezse Firestore'dan çekilir.
  Future<void> startBattle({
    List<HeroCardEntity>? playerTeam,
    List<HeroCardEntity>? benchHeroes,
  }) async {
    emit(const BattleLoading());
    final result = await _startBattleUseCase.execute(
      predefinedPlayerTeam: playerTeam,
      predefinedBenchHeroes: benchHeroes,
    );

    if (result is BattleInProgress) {
      final stateWithBuffs = _handleBuffsUseCase.checkAutoBuffs(
          result, BuffTriggerCondition.onBattleStart);
      emit(stateWithBuffs);
    } else {
      emit(result);
    }
  }

  /// Bir kahramanı seçme veya hedef belirleme
  void selectHero(int index, bool isEnemy) {
    if (state is! BattleInProgress) return;
    final newState = _selectHeroUseCase.execute(state as BattleInProgress, index, isEnemy);
    emit(newState);
  }

  /// Oyuncu saldırısını başlatır (Animasyonu tetikler)
  void executePlayerAttack() {
    if (state is! BattleInProgress) return;
    final newState = _executePlayerAttackUseCase.execute(state as BattleInProgress);
    emit(newState);
  }

  /// Animasyon tamamlandığında hasarı uygular
  void onAnimationComplete() {
    if (state is! BattleInProgress) return;
    final currentState = state as BattleInProgress;
    final action = currentState.currentAction;
    if (action == null) return;

    if (action.isPlayerAttacking) {
      final newState = _applyPlayerAttackUseCase.execute(currentState, action);
      emit(newState);

      if (newState is BattleInProgress && !newState.isPlayerTurn) {
        _executeEnemyTurn();
      } else if (newState is BattleResult && newState.isVictory) {
        _finalizeXp(isVictory: true);
      }
    } else {
      // Düşman saldırı animasyonu bittiğinde akışı devam ettir
      _enemyAnimationCompleter?.complete();
    }
  }

  Completer<void>? _enemyAnimationCompleter;

  /// Sahadaki kahramanı yedek kadrodan biriyle değiştirir.
  /// Değişim tur aksiyonu sayılır — düşman sırası hemen başlar.
  void swapHero(int fieldIndex, int benchIndex) {
    if (state is! BattleInProgress) return;
    final newState = _swapHeroUseCase.execute(state as BattleInProgress, fieldIndex, benchIndex);
    emit(newState);
    if (newState is BattleInProgress && !newState.isPlayerTurn) {
      _executeEnemyTurn();
    }
  }

  /// Seçilen kahraman için Töz kartı kullan
  void useSkill(int heroIndex, SkillEntity skill) {
    if (state is! BattleInProgress) return;
    final newState = _useSkillUseCase.execute(state as BattleInProgress, heroIndex, skill);
    emit(newState);
  }

  /// Düşman Yapay Zekası
  Future<void> _executeEnemyTurn() async {
    if (state is! BattleInProgress) return;
    
    await _executeEnemyTurnUseCase.execute(
      currentState: state as BattleInProgress,
      onEmit: (newState) => emit(newState),
      waitForAnimation: () async {
        _enemyAnimationCompleter = Completer<void>();
        await _enemyAnimationCompleter!.future;
        _enemyAnimationCompleter = null;
      },
      onFinalize: (isVictory) => _finalizeXp(isVictory: isVictory),
    );
  }

  /// Savaş sonunda kahramanlara XP'lerini dağıtır
  Future<void> _finalizeXp({required bool isVictory}) async {
    if (state is! BattleInProgress) return;
    await _finalizeXpUseCase.execute(
      currentState: state as BattleInProgress,
      isVictory: isVictory,
    );
  }

  /// UI Tarafından Töz kontrolü için yardımcı metod (Logic UseCase'de kalır)
  bool isSkillPrerequisiteMet(HeroCardEntity hero, SkillEntity skill) {
    if (state is! BattleInProgress) return false;
    return _useSkillUseCase.isSkillPrerequisiteMet(state as BattleInProgress, hero, skill);
  }
}