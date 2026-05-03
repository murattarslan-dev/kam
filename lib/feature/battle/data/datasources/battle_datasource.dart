import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/hero_entities.dart';
import '../../domain/entities/buff_entities.dart';

abstract class BattleDataSource {
  User? get currentUser;
  Future<List<HeroCardEntity>> fetchAllHeroes();
  Future<List<HeroCardEntity>> fetchUserHeroes(String userId);
  Future<void> updateHeroXp(String userId, String userHeroDocId, int xpGain);
  Future<List<BuffEntity>> fetchAllBuffs();
}
