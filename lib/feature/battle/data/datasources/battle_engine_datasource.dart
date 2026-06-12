import '../../domain/entities/hero_entities.dart';

/// Birleşik savaş motoru arayüzü. PvE ve PvP tek pipeline'dan akar.
///
/// Sözleşme:
/// - Tüm kural/hesap motorun içinde olur. UI/Cubit yalnızca intent gönderir
///   ve doc snapshot'ını dinler.
/// - Bir intent gönderildiğinde motor:
///   1) mevcut doc'u okur, 2) kuralı uygular (hasar, buff, tur değişimi,
///   bitiş kontrolü), 3) yeni state'i Firestore'a yazar.
/// - PvE modunda sıra bot'a geçtiğinde motor lokal BotAi ile bot'un
///   hamlesini de aynı borudan üretip yine Firestore'a yazar.
/// - PvP modunda sıra rakipte ise motor bir şey yapmaz; karşı taraf
///   kendi cihazında yazar, snapshot listener bizim ekranı günceller.
class PvpLobby {
  final String battleId;
  final String inviteCode;
  const PvpLobby({required this.battleId, required this.inviteCode});
}

abstract class BattleEngineDataSource {
  // ── Oluşturma ────────────────────────────────────────────────────────────

  /// Bot'a karşı yeni bir savaş başlatır. Düşman takımı rastgele kurulur.
  Future<String> createPveBattle({
    required String hostId,
    String? hostName,
    required List<HeroCardEntity> playerTeam,
    required List<HeroCardEntity> bench,
    String? arenaId,
  });

  /// PvP için yeni bir lobi oluşturur. İkinci oyuncu gelene kadar
  /// `status='lobby'`. Dönen kod ekranda gösterilir; rakip ana ekrandaki
  /// "Oyuna Katıl" akışıyla bu kodu girerek dahil olur.
  Future<PvpLobby> createPvpLobby({
    required String hostId,
    String? hostName,
    required List<HeroCardEntity> hostTeam,
    required List<HeroCardEntity> hostBench,
    String? arenaId,
  });

  /// Davet kodundan lobi (battleId) bul. Yoksa null.
  Future<String?> findLobbyByCode(String code);

  /// Kod gerektirmeden lobiye katılır ve savaş `in_progress`'e geçer.
  Future<void> joinPvpLobby({
    required String battleId,
    required String guestId,
    String? guestName,
    required List<HeroCardEntity> guestTeam,
    required List<HeroCardEntity> guestBench,
  });

  // ── Dinleme ─────────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>?> watch(String battleId);
  Future<Map<String, dynamic>?> get(String battleId);

  // ── Komutlar ────────────────────────────────────────────────────────────

  Future<void> submitAttack({
    required String battleId,
    required String mySide, // 'host' | 'guest'
    required String actorInstanceId,
    required String targetInstanceId,
  });

  Future<void> submitSkill({
    required String battleId,
    required String mySide,
    required String actorInstanceId,
    required String skillId,
  });

  Future<void> submitSwap({
    required String battleId,
    required String mySide,
    required int fieldIndex,
    required int benchIndex,
  });

  Future<void> abort(String battleId);

  /// Tur süresi dolan tarafın savaşı terk etmiş sayılması. Yalnız PvP'de
  /// anlamlı; status=='in_progress' ve turnOwner==mySide ise çalışır.
  /// Karşı taraf kazanan olur ve XP'sini normal akıştan alır;
  /// terk eden taraf hiç XP almaz (result.forfeitedSide ile guard'lanır).
  Future<void> forfeitByTimeout({
    required String battleId,
    required String mySide,
  });

  /// Heartbeat — sadece PvP'de anlamlı; karşı tarafın online olduğunu işaret eder.
  Future<void> heartbeat({required String battleId, required String mySide});

  /// Savaş 'finished' olduktan sonra çağrılır: bu client'in kendi tarafındaki
  /// kahramanlara XP yansıtır. Idempotent (UID bazlı guard).
  Future<void> grantOwnSideXp({
    required String battleId,
    required String mySide,
  });
}
