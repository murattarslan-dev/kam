import '../../domain/entities/hero_entities.dart';
import '../../domain/entities/buff_entities.dart';

/// Firestore battles/{id} dokümanı için snapshot/dto mapper'ları.
class BattleFirestoreMapper {
  static Map<String, dynamic> heroSnapshot(HeroCardEntity h, {required bool isBot}) => {
        'id': h.id,
        'name': h.name,
        'element': h.element.name,
        'role': h.role.name,
        'maxCp': h.currentCp,
        'attackPower': h.currentAttackPower,
        'defensePower': h.currentDefensePower,
        'isBot': isBot,
      };

  static Map<String, dynamic> heroCurrent(HeroCardEntity h) => {
        'id': h.id,
        'name': h.name,
        'health': h.health,
        'kut': h.kut,
        'isAlive': h.isAlive,
      };

  static Map<String, dynamic> heroRef(HeroCardEntity h, {required bool isBot}) => {
        'id': h.id,
        'name': h.name,
        'isBot': isBot,
      };

  static Map<String, dynamic> activeBuffMap(ActiveBuff b) => {
        'buffId': b.buffId,
        'targetHeroId': b.targetHeroId,
        'remainingTurns': b.remainingTurns,
      };
}
