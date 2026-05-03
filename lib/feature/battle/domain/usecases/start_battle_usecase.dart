import 'dart:math';
import '../entities/hero_entities.dart';
import '../../presentation/manager/battle_state.dart';
import '../repository/battle_repository.dart';

class StartBattleUseCase {
  final BattleRepository _repository;

  StartBattleUseCase(this._repository);

  Future<BattleState> execute() async {
    try {
      final user = _repository.currentUser;
      if (user == null) {
        return const BattleError("Oturum açılmış bir kullanıcı bulunamadı!");
      }

      // 1. Oyuncunun kahramanlarını getir
      final playerHeroes = await _repository.fetchUserHeroes(user.uid);
      if (playerHeroes.isEmpty) {
        return const BattleError("Kullanıcıya ait kahraman bulunamadı!");
      }

      // 2. Düşman için tüm kahramanları getir ve rastgele 3 tane seç
      final allGlobalHeroes = await _repository.fetchAllHeroes();
      if (allGlobalHeroes.length < 3) {
        return const BattleError("Savaş için yeterli küresel kahraman bulunamadı!");
      }

      final random = Random();
      final List<HeroCardEntity> enemyTeam = [];
      final List<HeroCardEntity> pool = List.from(allGlobalHeroes)..shuffle(random);
      
      for (var i = 0; i < 3; i++) {
        final baseHero = pool[i];
        final enemyHero = HeroCardEntity.fromMap(
          baseHero.toMap()..['xp'] = 2364, 
          skills: baseHero.skillCards,
        );
        enemyTeam.add(enemyHero);
      }

      final playerTeam = playerHeroes.take(3).toList();

      // 3. Tüm buff'ları getir
      final allBuffs = await _repository.fetchAllBuffs();

      return BattleInProgress(
        playerTeam: playerTeam,
        enemyTeam: enemyTeam,
        allBuffs: allBuffs,
        battleLogs: const ["Savaş başladı! Oyuncu ve düşman takımları hazır."],
      );
    } catch (e) {
      return BattleError("Savaş başlatılamadı: $e");
    }
  }
}
