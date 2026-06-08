import 'package:flutter/foundation.dart';
import '../../../battle/domain/entities/hero_entities.dart';
import '../../domain/entities/buff_entities.dart';

@immutable
sealed class BattleState {
  const BattleState();
}

/// Savaş sırasında gerçekleşen bir aksiyonu (saldırı animasyonu vb.) temsil eder
final class BattleAction {
  final HeroCardEntity attacker;
  final HeroCardEntity target;
  final bool isPlayerAttacking;

  const BattleAction({
    required this.attacker,
    required this.target,
    required this.isPlayerAttacking,
  });
}

final class BattleInitial extends BattleState {
  const BattleInitial();
}

final class BattleLoading extends BattleState {
  final String? message;
  const BattleLoading({this.message});
}

/// Savaşın devam ettiği, tüm saha verilerini içeren ana durum
final class BattleInProgress extends BattleState {
  // Takımlar
  final List<HeroCardEntity> playerTeam;
  final List<HeroCardEntity> enemyTeam;

  // Sıra ve Tur Yönetimi
  final int currentTurn;          // Toplam kaçıncı turdayız
  final bool isPlayerTurn;        // Sıra oyuncuda mı yoksa düşmanda mı?

  // Aksiyon Takibi
  final List<String> actedHeroIds; // Bu tur içerisinde hamle yapmış kahramanların ID listesi
  final int? selectedHeroIndex;    // Oyuncunun o an tıkladığı/seçtiği kartın indeksi
  final int? selectedTargetIndex;  // Hedef olarak seçilen düşman kartının indeksi

  // Loglama ve Geçmiş
  final List<String> battleLogs;   // Savaş sırasında gerçekleşen olayların metin listesi

  // İstatistik Takibi (Opsiyonel Detaylar)
  final Map<String, double> totalDamageDealt;    // Kahraman ID bazlı toplam verilen hasar
  final Map<String, double> totalDamageReceived; // Kahraman ID bazlı toplam alınan hasar
  final Map<String, int> turnsSinceEffect;        // Buff/Debuff süre takibi için
  
  // Yetenek Takibi
  final List<String> usedSkillIds; // Bu savaş boyunca kullanılmış Töz kartlarının ID'leri

  // Mevcut Animasyon
  final BattleAction? currentAction; // O an oynatılan bir animasyon varsa

  // Buff/Debuff Yönetimi
  final List<BuffEntity> allBuffs;    // Firestore'dan çekilen tüm buff listesi
  final List<ActiveBuff> activeBuffs; // O an aktif olan buff'lar

  // Yedek Kadro
  final List<HeroCardEntity> benchHeroes; // Sahada olmayan, değiştirilebilir kahramanlar

  // Firestore battle log doc id (aktif savaş kaydı)
  final String? battleId;

  // Floating sayı animasyonu için son komutun HP delta'ları
  // (heroId → değer; negatif = hasar, pozitif = iyileşme).
  final Map<String, int> floatingDeltas;
  final int? lastActionSeq;

  // Perspektife göre oyuncu adları (arena ve loglarda gösterim için).
  final String? playerName;
  final String? enemyName;

  const BattleInProgress({
    required this.playerTeam,
    required this.enemyTeam,
    this.currentTurn = 1,
    this.isPlayerTurn = true,
    this.actedHeroIds = const [],
    this.selectedHeroIndex,
    this.selectedTargetIndex,
    this.battleLogs = const ["Savaş başladı!"],
    this.totalDamageDealt = const {},
    this.totalDamageReceived = const {},
    this.turnsSinceEffect = const {},
    this.usedSkillIds = const [],
    this.currentAction,
    this.allBuffs = const [],
    this.activeBuffs = const [],
    this.benchHeroes = const [],
    this.battleId,
    this.floatingDeltas = const {},
    this.lastActionSeq,
    this.playerName,
    this.enemyName,
  });

  /// State'i güncellerken değişmeyen alanları korumamızı sağlayan yardımcı metod
  BattleInProgress copyWith({
    List<HeroCardEntity>? playerTeam,
    List<HeroCardEntity>? enemyTeam,
    int? currentTurn,
    bool? isPlayerTurn,
    List<String>? actedHeroIds,
    int? selectedHeroIndex,
    int? selectedTargetIndex,
    List<String>? battleLogs,
    Map<String, double>? totalDamageDealt,
    Map<String, double>? totalDamageReceived,
    Map<String, int>? turnsSinceEffect,
    List<String>? usedSkillIds,
    BattleAction? currentAction,
    List<BuffEntity>? allBuffs,
    List<ActiveBuff>? activeBuffs,
    List<HeroCardEntity>? benchHeroes,
    String? battleId,
    Map<String, int>? floatingDeltas,
    int? lastActionSeq,
    String? playerName,
    String? enemyName,
    bool clearSelection = false,
    bool clearTarget = false,
    bool clearAction = false,
    bool clearFloatingDeltas = false,
  }) {
    return BattleInProgress(
      playerTeam: playerTeam ?? this.playerTeam,
      enemyTeam: enemyTeam ?? this.enemyTeam,
      currentTurn: currentTurn ?? this.currentTurn,
      isPlayerTurn: isPlayerTurn ?? this.isPlayerTurn,
      actedHeroIds: actedHeroIds ?? this.actedHeroIds,
      selectedHeroIndex: clearSelection ? null : (selectedHeroIndex ?? this.selectedHeroIndex),
      selectedTargetIndex: (clearSelection || clearTarget) ? null : (selectedTargetIndex ?? this.selectedTargetIndex),
      battleLogs: battleLogs ?? this.battleLogs,
      totalDamageDealt: totalDamageDealt ?? this.totalDamageDealt,
      totalDamageReceived: totalDamageReceived ?? this.totalDamageReceived,
      turnsSinceEffect: turnsSinceEffect ?? this.turnsSinceEffect,
      usedSkillIds: usedSkillIds ?? this.usedSkillIds,
      currentAction: clearAction ? null : (currentAction ?? this.currentAction),
      allBuffs: allBuffs ?? this.allBuffs,
      activeBuffs: activeBuffs ?? this.activeBuffs,
      benchHeroes: benchHeroes ?? this.benchHeroes,
      battleId: battleId ?? this.battleId,
      floatingDeltas: clearFloatingDeltas ? const {} : (floatingDeltas ?? this.floatingDeltas),
      lastActionSeq: lastActionSeq ?? this.lastActionSeq,
      playerName: playerName ?? this.playerName,
      enemyName: enemyName ?? this.enemyName,
    );
  }

  // Yardımcı Getter'lar
  bool get canEndTurn => actedHeroIds.length == playerTeam.where((h) => h.isAlive).length;
}

final class BattleResult extends BattleState {
  final String message;
  final bool isVictory;
  final List<String> rewards;

  // Özet ekranı için savaş istatistikleri
  final List<HeroCardEntity> playerTeam;
  final List<HeroCardEntity> benchHeroes;
  final Map<String, double> totalDamageDealt;
  final Map<String, double> totalDamageReceived;
  final Map<String, int> heroXpGained; // heroId → kazanılan XP
  final List<ActiveBuff> activeBuffs;
  final List<BuffEntity> allBuffs;

  const BattleResult({
    required this.message,
    required this.isVictory,
    this.rewards = const [],
    this.playerTeam = const [],
    this.benchHeroes = const [],
    this.totalDamageDealt = const {},
    this.totalDamageReceived = const {},
    this.heroXpGained = const {},
    this.activeBuffs = const [],
    this.allBuffs = const [],
  });
}

final class BattleError extends BattleState {
  final String errorMessage;
  const BattleError(this.errorMessage);
}