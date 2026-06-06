import 'dart:async';
import '../manager/battle_state.dart';
import '../manager/battle_cubit_base.dart';
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
import '../../domain/usecases/log_battle_event_usecase.dart';
import '../../domain/entities/buff_entities.dart';

class BattleCubit extends BattleCubitBase {
  final StartBattleUseCase _startBattleUseCase;
  final SelectHeroUseCase _selectHeroUseCase;
  final ExecutePlayerAttackUseCase _executePlayerAttackUseCase;
  final ApplyPlayerAttackUseCase _applyPlayerAttackUseCase;
  final UseSkillUseCase _useSkillUseCase;
  final ExecuteEnemyTurnUseCase _executeEnemyTurnUseCase;
  final FinalizeXpUseCase _finalizeXpUseCase;
  final HandleBuffsUseCase _handleBuffsUseCase;
  final SwapHeroUseCase _swapHeroUseCase;
  final LogBattleEventUseCase _logBattleEventUseCase;

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
    this._logBattleEventUseCase,
  ) : super(const BattleInitial());

  /// Takım hazırlama ekranından veya doğrudan başlatma ile savaşı başlatır.
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
      final stateWithPassives = _handleBuffsUseCase.checkPassiveBuffs(stateWithBuffs);

      // Firestore battle dokümanını oluştur ve battleId'yi state'e ekle.
      final battleId = await _logBattleEventUseCase.createBattle(
        playerTeam: stateWithPassives.playerTeam,
        enemyTeam: stateWithPassives.enemyTeam,
      );
      final stateWithId = stateWithPassives.copyWith(battleId: battleId);
      emit(stateWithId);

      await _logBattleEventUseCase.log(
        stateAfter: stateWithId,
        side: 'system',
        type: 'battle_start',
        message: 'Savaş başladı.',
      );
    } else {
      emit(result);
    }
  }

  /// Bir kahramanı seçme veya hedef belirleme
  @override
  void selectHero(int index, bool isEnemy) {
    if (state is! BattleInProgress) return;
    final newState = _selectHeroUseCase.execute(state as BattleInProgress, index, isEnemy);
    emit(newState);
  }

  /// Oyuncu saldırısını başlatır (Animasyonu tetikler)
  @override
  void executePlayerAttack() {
    if (state is! BattleInProgress) return;
    final newState = _executePlayerAttackUseCase.execute(state as BattleInProgress);
    emit(newState);
  }

  /// Animasyon tamamlandığında hasarı uygular
  @override
  void onAnimationComplete() {
    if (state is! BattleInProgress) return;
    final currentState = state as BattleInProgress;
    final action = currentState.currentAction;
    if (action == null) return;

    if (action.isPlayerAttacking) {
      // Hedefin hasar öncesi HP'sini sakla.
      final hpBefore = currentState.enemyTeam
              .firstWhere((e) => e.id == action.target.id, orElse: () => action.target)
              .health;

      final newState = _applyPlayerAttackUseCase.execute(currentState, action);
      emit(newState);

      if (newState is BattleInProgress) {
        final hpAfter = newState.enemyTeam
            .firstWhere((e) => e.id == action.target.id, orElse: () => action.target)
            .health;
        final dealt = (hpBefore - hpAfter).clamp(0, 1 << 30);
        _logBattleEventUseCase.log(
          stateAfter: newState,
          side: 'player',
          type: 'attack',
          message: newState.battleLogs.isNotEmpty
              ? newState.battleLogs.first
              : '${action.attacker.name}, ${action.target.name} birimine $dealt hasar verdi.',
          actor: LogBattleEventUseCase.heroRef(action.attacker, isBot: false),
          target: LogBattleEventUseCase.heroRef(action.target, isBot: true),
          damage: {'finalDamage': dealt},
          result: {
            'targetHpAfter': hpAfter,
            'killed': hpAfter <= 0,
          },
        );

        if (!newState.isPlayerTurn) {
          _executeEnemyTurn();
        }
      } else if (newState is BattleResult && newState.isVictory) {
        _logBattleEventUseCase.log(
          stateAfter: currentState,
          side: 'system',
          type: 'battle_end',
          message: newState.message,
        );
        _finalizeXp(isVictory: true, finalState: currentState, result: newState);
      }
    } else {
      // Düşman saldırı animasyonu bittiğinde akışı devam ettir
      _enemyAnimationCompleter?.complete();
    }
  }

  Completer<void>? _enemyAnimationCompleter;

  /// Sahadaki kahramanı yedek kadrodan biriyle değiştirir.
  @override
  void swapHero(int fieldIndex, int benchIndex) {
    if (state is! BattleInProgress) return;
    final before = state as BattleInProgress;
    final fieldHero = before.playerTeam[fieldIndex];
    final benchHero = before.benchHeroes[benchIndex];
    final newState = _swapHeroUseCase.execute(before, fieldIndex, benchIndex);
    emit(newState);
    if (newState is BattleInProgress) {
      _logBattleEventUseCase.log(
        stateAfter: newState,
        side: 'player',
        type: 'swap',
        message: '${fieldHero.name} sahadan çekildi, yerine ${benchHero.name} geçti.',
        actor: LogBattleEventUseCase.heroRef(benchHero, isBot: false),
        target: LogBattleEventUseCase.heroRef(fieldHero, isBot: false),
      );
      if (!newState.isPlayerTurn) {
        _executeEnemyTurn();
      }
    }
  }

  /// Seçilen kahraman için Töz kartı kullan
  @override
  void useSkill(int heroIndex, SkillEntity skill) {
    if (state is! BattleInProgress) return;
    final before = state as BattleInProgress;
    final hero = before.playerTeam[heroIndex];
    final newState = _useSkillUseCase.execute(before, heroIndex, skill);
    emit(newState);
    if (newState is BattleInProgress &&
        newState.usedSkillIds.contains(skill.id) &&
        !before.usedSkillIds.contains(skill.id)) {
      _logBattleEventUseCase.log(
        stateAfter: newState,
        side: 'player',
        type: 'skill',
        message: newState.battleLogs.isNotEmpty
            ? newState.battleLogs.first
            : '${hero.name} ${skill.name} kullandı.',
        actor: LogBattleEventUseCase.heroRef(hero, isBot: false),
        skill: {'id': skill.id, 'name': skill.name, 'kind': skill.type.name},
      );
    }
  }

  /// Düşman Yapay Zekası
  Future<void> _executeEnemyTurn() async {
    if (state is! BattleInProgress) return;

    BattleInProgress? lastEmitted = state as BattleInProgress;

    await _executeEnemyTurnUseCase.execute(
      currentState: state as BattleInProgress,
      onEmit: (newState) {
        emit(newState);
        if (newState is BattleInProgress) {
          // Düşman saldırı state geçişlerini gözleyerek event üret.
          final prev = lastEmitted;
          if (prev != null) {
            final action = newState.currentAction;
            // Saldırı sonrası emit (hasar uygulanmış): currentAction null olabilir.
            if (action == null && prev.currentAction != null && !prev.currentAction!.isPlayerAttacking) {
              final atk = prev.currentAction!.attacker;
              final tgt = prev.currentAction!.target;
              final hpBefore = prev.playerTeam
                  .firstWhere((p) => p.id == tgt.id, orElse: () => tgt)
                  .health;
              final hpAfter = newState.playerTeam
                  .firstWhere((p) => p.id == tgt.id, orElse: () => tgt)
                  .health;
              final dealt = (hpBefore - hpAfter).clamp(0, 1 << 30);
              _logBattleEventUseCase.log(
                stateAfter: newState,
                side: 'enemy',
                type: 'attack',
                message: newState.battleLogs.isNotEmpty
                    ? newState.battleLogs.first
                    : '${atk.name} → ${tgt.name} ($dealt hasar)',
                actor: LogBattleEventUseCase.heroRef(atk, isBot: true),
                target: LogBattleEventUseCase.heroRef(tgt, isBot: false),
                damage: {'finalDamage': dealt},
                result: {'targetHpAfter': hpAfter, 'killed': hpAfter <= 0},
              );
            }
            // Yeni tur başladıysa
            if (newState.currentTurn > prev.currentTurn) {
              _logBattleEventUseCase.log(
                stateAfter: newState,
                side: 'system',
                type: 'turn_start',
                message: 'Yeni tur: ${newState.currentTurn}',
              );
            }
          }
          lastEmitted = newState;
        } else if (newState is BattleResult) {
          _logBattleEventUseCase.log(
            stateAfter: lastEmitted!,
            side: 'system',
            type: 'battle_end',
            message: newState.message,
          );
        }
      },
      waitForAnimation: () async {
        _enemyAnimationCompleter = Completer<void>();
        await _enemyAnimationCompleter!.future;
        _enemyAnimationCompleter = null;
      },
      onFinalize: (isVictory) => _finalizeXp(
        isVictory: isVictory,
        finalState: lastEmitted,
      ),
    );
  }

  /// Savaş sonunda kahramanlara XP'lerini dağıtır ve Firestore kaydını kapatır.
  Future<void> _finalizeXp({
    required bool isVictory,
    BattleInProgress? finalState,
    BattleResult? result,
  }) async {
    final stateForXp = state is BattleInProgress ? state as BattleInProgress : finalState;
    if (stateForXp != null) {
      await _finalizeXpUseCase.execute(
        currentState: stateForXp,
        isVictory: isVictory,
      );
      // XP kazanımlarını hesapla (FinalizeXpUseCase ile aynı formül)
      final heroXpGained = <String, int>{};
      for (final hero in [...stateForXp.playerTeam, ...stateForXp.benchHeroes]) {
        final dmgXp = (stateForXp.totalDamageDealt[hero.id] ?? 0).round();
        heroXpGained[hero.id] = dmgXp + (isVictory ? 300 : 0);
      }
      await _logBattleEventUseCase.finalize(
        isVictory: isVictory,
        message: result?.message ?? (isVictory ? 'Zafer' : 'Mağlubiyet'),
        rewards: result?.rewards ?? const [],
        lastState: stateForXp,
        heroXpGained: heroXpGained,
      );
    }
  }

  /// UI Tarafından Töz kontrolü için yardımcı metod (Logic UseCase'de kalır)
  @override
  bool isSkillPrerequisiteMet(HeroCardEntity hero, SkillEntity skill) {
    if (state is! BattleInProgress) return false;
    return _useSkillUseCase.isSkillPrerequisiteMet(state as BattleInProgress, hero, skill);
  }
}
