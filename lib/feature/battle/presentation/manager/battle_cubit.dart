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

class BattleCubit extends Cubit<BattleState> {
  final StartBattleUseCase _startBattleUseCase;
  final SelectHeroUseCase _selectHeroUseCase;
  final ExecutePlayerAttackUseCase _executePlayerAttackUseCase;
  final ApplyPlayerAttackUseCase _applyPlayerAttackUseCase;
  final UseSkillUseCase _useSkillUseCase;
  final ExecuteEnemyTurnUseCase _executeEnemyTurnUseCase;
  final FinalizeXpUseCase _finalizeXpUseCase;

  BattleCubit(
    this._startBattleUseCase,
    this._selectHeroUseCase,
    this._executePlayerAttackUseCase,
    this._applyPlayerAttackUseCase,
    this._useSkillUseCase,
    this._executeEnemyTurnUseCase,
    this._finalizeXpUseCase,
  ) : super(const BattleInitial());

  /// Firestore'dan verileri çeker ve savaşı başlatır
  Future<void> startBattle() async {
    emit(const BattleLoading());
    final result = await _startBattleUseCase.execute();
    emit(result);
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