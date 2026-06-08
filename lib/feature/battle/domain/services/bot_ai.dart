import 'dart:math';
import '../../presentation/manager/battle_state.dart';

/// Bot tarafının tek seferlik karar mantığı. Datasource her tur sırası
/// bot'a geçtiğinde bunu çağırır ve dönen [BotMove]'u submitAttack ile
/// yine Firestore'a yazar. Tüm "oyun mantığı" motorun içinde kalır.
///
/// Bu sınıf sadece HEDEF SEÇİMİ yapar; hasarı uygulamaz.
class BotAi {
  final Random _random;
  BotAi({Random? random}) : _random = random ?? Random();

  /// [state]: bot perspektifinden BattleInProgress (playerTeam = bot,
  /// enemyTeam = karşı oyuncu). `actedHeroIds` bot'un bu turda hamle
  /// yapmış kahramanlarını tutar.
  BotMove? nextMove(BattleInProgress state) {
    final myAlive = state.playerTeam
        .where((h) => h.isAlive && !state.actedHeroIds.contains(h.id))
        .toList();
    final foeAlive = state.enemyTeam.where((e) => e.isAlive).toList();
    if (myAlive.isEmpty || foeAlive.isEmpty) return null;

    final attacker = myAlive.first; // ilk sırada bekleyenden başla
    final target = foeAlive[_random.nextInt(foeAlive.length)];
    return BotMove(actorInstanceId: attacker.id, targetInstanceId: target.id);
  }
}

class BotMove {
  final String actorInstanceId;
  final String targetInstanceId;
  const BotMove({required this.actorInstanceId, required this.targetInstanceId});
}
