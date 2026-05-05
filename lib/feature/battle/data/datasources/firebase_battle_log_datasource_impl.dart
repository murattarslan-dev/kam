import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/hero_entities.dart';
import '../../domain/entities/battle_event.dart';
import '../../presentation/manager/battle_state.dart';
import '../mappers/battle_firestore_mapper.dart';
import 'battle_log_datasource.dart';

class FirebaseBattleLogDataSourceImpl implements BattleLogDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('battles');

  @override
  Future<String?> createBattle({
    required Map<String, dynamic> player,
    required Map<String, dynamic> opponent,
    required List<HeroCardEntity> playerTeam,
    required List<HeroCardEntity> enemyTeam,
  }) async {
    try {
      final doc = _col.doc();
      await doc.set({
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'in_progress',
        'currentTurn': 1,
        'isPlayerTurn': true,
        'player': player,
        'opponent': opponent,
        'playerTeam':
            playerTeam.map((h) => BattleFirestoreMapper.heroSnapshot(h, isBot: false)).toList(),
        'enemyTeam':
            enemyTeam.map((h) => BattleFirestoreMapper.heroSnapshot(h, isBot: true)).toList(),
        'playerTeamCurrent':
            playerTeam.map(BattleFirestoreMapper.heroCurrent).toList(),
        'enemyTeamCurrent':
            enemyTeam.map(BattleFirestoreMapper.heroCurrent).toList(),
        'totalDamageDealt': <String, dynamic>{},
        'usedSkillIds': <String>[],
        'activeBuffs': <Map<String, dynamic>>[],
        'result': null,
      });
      return doc.id;
    } catch (e) {
      // ignore: avoid_print
      print('createBattle error: $e');
      return null;
    }
  }

  @override
  Future<void> appendEvent({
    required String battleId,
    required BattleEventDto event,
    required BattleInProgress stateAfter,
  }) async {
    try {
      final battleRef = _col.doc(battleId);
      final eventRef = battleRef.collection('events').doc();
      final batch = _firestore.batch();

      batch.set(eventRef, {
        ...event.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(battleRef, {
        'updatedAt': FieldValue.serverTimestamp(),
        'currentTurn': stateAfter.currentTurn,
        'isPlayerTurn': stateAfter.isPlayerTurn,
        'playerTeamCurrent':
            stateAfter.playerTeam.map(BattleFirestoreMapper.heroCurrent).toList(),
        'enemyTeamCurrent':
            stateAfter.enemyTeam.map(BattleFirestoreMapper.heroCurrent).toList(),
        'totalDamageDealt':
            stateAfter.totalDamageDealt.map((k, v) => MapEntry(k, v)),
        'usedSkillIds': stateAfter.usedSkillIds,
        'activeBuffs':
            stateAfter.activeBuffs.map(BattleFirestoreMapper.activeBuffMap).toList(),
      });

      await batch.commit();
    } catch (e) {
      // ignore: avoid_print
      print('appendEvent error: $e');
    }
  }

  @override
  Future<void> finalizeBattle({
    required String battleId,
    required bool isVictory,
    required String message,
    required List<String> rewards,
    required BattleInProgress lastState,
    Map<String, int> heroXpGained = const {},
  }) async {
    try {
      // Tüm oyuncu kahramanları (saha + yedek) için istatistik özeti
      final allPlayerHeroes = [...lastState.playerTeam, ...lastState.benchHeroes];
      final heroStats = allPlayerHeroes.map((h) => {
        'id': h.id,
        'name': h.name,
        'isBench': lastState.benchHeroes.any((b) => b.id == h.id),
        'damageDealt': (lastState.totalDamageDealt[h.id] ?? 0).round(),
        'damageReceived': (lastState.totalDamageReceived[h.id] ?? 0).round(),
        'xpGained': heroXpGained[h.id] ?? 0,
      }).toList();

      await _col.doc(battleId).update({
        'updatedAt': FieldValue.serverTimestamp(),
        'status': isVictory ? 'victory' : 'defeat',
        'playerTeamCurrent':
            lastState.playerTeam.map(BattleFirestoreMapper.heroCurrent).toList(),
        'enemyTeamCurrent':
            lastState.enemyTeam.map(BattleFirestoreMapper.heroCurrent).toList(),
        'heroStats': heroStats,
        'result': {
          'isVictory': isVictory,
          'message': message,
          'rewards': rewards,
          'finishedAt': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      // ignore: avoid_print
      print('finalizeBattle error: $e');
    }
  }
}
