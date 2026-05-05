import 'package:firebase_auth/firebase_auth.dart';
import '../entities/battle_event.dart';
import '../entities/hero_entities.dart';
import '../../data/datasources/battle_log_datasource.dart';
import '../../data/mappers/battle_firestore_mapper.dart';
import '../../presentation/manager/battle_state.dart';

/// BattleCubit'in Firestore'a savaş kaydı yazmak için kullandığı facade.
/// Sıra numarasını (seq) içeride yönetir.
class LogBattleEventUseCase {
  final BattleLogDataSource _dataSource;
  int _seq = 0;
  String? _activeBattleId;

  LogBattleEventUseCase(this._dataSource);

  String? get activeBattleId => _activeBattleId;

  Future<String?> createBattle({
    required List<HeroCardEntity> playerTeam,
    required List<HeroCardEntity> enemyTeam,
  }) async {
    _seq = 0;
    final user = FirebaseAuth.instance.currentUser;
    final player = {
      'uid': user?.uid,
      'displayName': user?.displayName ?? user?.email ?? 'Oyuncu',
      'isAnonymous': user?.isAnonymous ?? false,
    };
    const opponent = {
      'uid': null,
      'displayName': 'YZ',
      'isBot': true,
    };

    final id = await _dataSource.createBattle(
      player: player,
      opponent: opponent,
      playerTeam: playerTeam,
      enemyTeam: enemyTeam,
    );
    _activeBattleId = id;
    return id;
  }

  Future<void> log({
    required BattleInProgress stateAfter,
    required String side,
    required String type,
    required String message,
    Map<String, dynamic>? actor,
    Map<String, dynamic>? target,
    Map<String, dynamic>? skill,
    Map<String, dynamic>? damage,
    Map<String, dynamic>? result,
    Map<String, dynamic>? buff,
  }) async {
    final id = _activeBattleId;
    if (id == null) return;
    _seq += 1;
    final dto = BattleEventDto(
      seq: _seq,
      turn: stateAfter.currentTurn,
      side: side,
      type: type,
      message: message,
      actor: actor,
      target: target,
      skill: skill,
      damage: damage,
      result: result,
      buff: buff,
    );
    await _dataSource.appendEvent(
      battleId: id,
      event: dto,
      stateAfter: stateAfter,
    );
  }

  Future<void> finalize({
    required bool isVictory,
    required String message,
    required List<String> rewards,
    required BattleInProgress lastState,
    Map<String, int> heroXpGained = const {},
  }) async {
    final id = _activeBattleId;
    if (id == null) return;
    await _dataSource.finalizeBattle(
      battleId: id,
      isVictory: isVictory,
      message: message,
      rewards: rewards,
      lastState: lastState,
      heroXpGained: heroXpGained,
    );
    _activeBattleId = null;
    _seq = 0;
  }

  /// Yardımcı: HeroCardEntity → event'in actor/target referansı.
  static Map<String, dynamic> heroRef(HeroCardEntity h, {required bool isBot}) =>
      BattleFirestoreMapper.heroRef(h, isBot: isBot);
}
