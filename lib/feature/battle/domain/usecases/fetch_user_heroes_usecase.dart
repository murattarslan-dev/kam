import '../entities/hero_entities.dart';
import '../repository/battle_repository.dart';

class FetchUserHeroesUseCase {
  final BattleRepository _repository;

  FetchUserHeroesUseCase(this._repository);

  Future<List<HeroCardEntity>> execute() async {
    final user = _repository.currentUser;
    if (user == null) return const [];
    return _repository.fetchUserHeroes(user.uid);
  }
}
