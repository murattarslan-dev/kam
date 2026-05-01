import '../../../../core/domain/entities/user_entity.dart';
import '../entities/hero_entities.dart';

abstract class BattleRepository {
  UserEntity? get currentUser;
  Future<List<HeroCardEntity>> fetchAllHeroes();
  Future<List<HeroCardEntity>> fetchUserHeroes(String userId);
  Future<void> updateHeroXp(String userId, String userHeroDocId, int xpGain);
}
