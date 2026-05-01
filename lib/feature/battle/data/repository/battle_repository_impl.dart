import '../../../../core/domain/entities/user_entity.dart';
import '../../domain/entities/hero_entities.dart';
import '../../domain/repository/battle_repository.dart';
import '../datasources/battle_datasource.dart';

class BattleRepositoryImpl implements BattleRepository {
  final BattleDataSource _dataSource;

  BattleRepositoryImpl(this._dataSource);

  @override
  UserEntity? get currentUser {
    final firebaseUser = _dataSource.currentUser;
    if (firebaseUser == null) return null;
    
    return UserEntity(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
      isAnonymous: firebaseUser.isAnonymous,
    );
  }

  @override
  Future<List<HeroCardEntity>> fetchAllHeroes() {
    return _dataSource.fetchAllHeroes();
  }

  @override
  Future<List<HeroCardEntity>> fetchUserHeroes(String userId) {
    return _dataSource.fetchUserHeroes(userId);
  }

  @override
  Future<void> updateHeroXp(String userId, String userHeroDocId, int xpGain) {
    return _dataSource.updateHeroXp(userId, userHeroDocId, xpGain);
  }
}
