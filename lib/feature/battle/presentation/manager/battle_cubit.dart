import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../battle/domain/entities/hero_entities.dart';
import 'battle_state.dart';

class BattleCubit extends Cubit<BattleState> {
  BattleCubit() : super(const BattleInitial());

  /// 3v3 Savaşı başlatan fonksiyon
  void startBattle() {
    emit(const BattleLoading());

    // Kart havuzundan random takımları oluştur
    final allCards = _getHeroCardPool();
    allCards.shuffle();

    final playerTeam = allCards.skip(0).take(3).toList();
    final enemyTeam = allCards.skip(3).take(3).toList();

    emit(BattleInProgress(
      playerTeam: playerTeam,
      enemyTeam: enemyTeam,
      battleLogs: ["Savaş başladı! Kut seninle olsun."],
    ));
  }

  /// Bir kahramanı seçme veya hedef belirleme
  void selectHero(int index, bool isEnemy) {
    if (state is! BattleInProgress) return;
    final currentState = state as BattleInProgress;

    // Sıra oyuncuda değilse seçim yapılamaz
    if (!currentState.isPlayerTurn) return;

    if (isEnemy) {
      // Düşman kartına tıklandı: Hedef seçimi
      if (currentState.enemyTeam[index].isAlive) {
        emit(currentState.copyWith(selectedTargetIndex: index));
        _tryPerformAttack();
      }
    } else {
      // Oyuncu kartına tıklandı: Saldırgan seçimi
      final hero = currentState.playerTeam[index];
      // Kart yaşıyorsa ve bu tur hamle yapmadıysa seçilebilir
      if (hero.isAlive && !currentState.actedHeroIds.contains(hero.id)) {
        if (currentState.selectedHeroIndex == index) {
          emit(currentState.copyWith(clearSelection: true));
        } else {
          emit(currentState.copyWith(selectedHeroIndex: index));
          _tryPerformAttack();
        }
      }
    }
  }

  /// Eğer hem saldırgan hem hedef seçiliyse saldırıyı gerçekleştir
  void _tryPerformAttack() {
    final currentState = state as BattleInProgress;
    if (currentState.selectedHeroIndex != null && currentState.selectedTargetIndex != null) {
      executePlayerAttack();
    }
  }

  /// Oyuncu saldırısını gerçekleştirir
  void executePlayerAttack() {
    if (state is! BattleInProgress) return;
    final currentState = state as BattleInProgress;

    final attacker = currentState.playerTeam[currentState.selectedHeroIndex!];
    final target = currentState.enemyTeam[currentState.selectedTargetIndex!];

    // Hasar hesaplama (XP / seviye etkisini dahil ediyoruz)
    final rawDamage = (attacker.currentAttackPower * attacker.element.getDamageMultiplier(target.element)).round();
    final defenseReduction = (target.currentDefensePower).round();
    final damage = max(1, rawDamage - defenseReduction);
    final newHealth = (target.health - damage).clamp(0, target.currentCp).toDouble();

    // Düşman takımını güncelle
    final updatedEnemyTeam = List<HeroCardEntity>.from(currentState.enemyTeam);
    updatedEnemyTeam[currentState.selectedTargetIndex!] = target.copyWith(health: newHealth.toInt());

    // Log ve İstatistikler
    final newLog = "${attacker.name}, ${target.name} birimine $damage hasar verdi!";
    final updatedLogs = List<String>.from(currentState.battleLogs)..insert(0, newLog);

    final updatedDamageMap = Map<String, double>.from(currentState.totalDamageDealt);
    updatedDamageMap[attacker.id] = (updatedDamageMap[attacker.id] ?? 0) + damage;

    // Hamle yapanları güncelle
    final updatedActedIds = List<String>.from(currentState.actedHeroIds)..add(attacker.id);

    final nextState = currentState.copyWith(
      enemyTeam: updatedEnemyTeam,
      battleLogs: updatedLogs,
      actedHeroIds: updatedActedIds,
      totalDamageDealt: updatedDamageMap,
      clearSelection: true,
    );

    _processTurnEnd(nextState);
  }

  /// Tur sonu kontrollerini yapar (Kazanma/Sıra Değişimi)
  void _processTurnEnd(BattleInProgress nextState) {
    // 1. Kazanma Kontrolü
    if (nextState.enemyTeam.every((e) => !e.isAlive)) {
      emit(BattleResult(
        message: "ZAFER! Karanlık ordu bozguna uğratıldı.",
        isVictory: true,
        rewards: ["100 Altın", "Kadim Ruh Parçası"],
      ));
      return;
    }

    // 2. Sıra Değişim Kontrolü (Tüm yaşayan oyuncular hamle yaptı mı?)
    final alivePlayerCount = nextState.playerTeam.where((p) => p.isAlive).length;
    if (nextState.actedHeroIds.length >= alivePlayerCount) {
      // Oyuncu turu bitti, düşman turuna geç
      final enemyTurnState = nextState.copyWith(
        isPlayerTurn: false,
        actedHeroIds: [], // Düşman için hamle listesini temizle (veya ayrı takip et)
        battleLogs: ["Sıra düşmanda! Savunmaya geç!", ...nextState.battleLogs],
      );
      emit(enemyTurnState);
      _executeEnemyTurn();
    } else {
      emit(nextState);
    }
  }

  /// Düşman Yapay Zekası
  Future<void> _executeEnemyTurn() async {
    await Future.delayed(const Duration(seconds: 1));

    if (state is! BattleInProgress) return;
    var currentState = state as BattleInProgress;

    final aliveEnemies = currentState.enemyTeam.where((e) => e.isAlive).toList();

    for (var enemy in aliveEnemies) {
      // Her düşman saldırısı arasında kısa bir bekletme (Görsel akış için)
      await Future.delayed(const Duration(milliseconds: 800));

      // Mevcut durumu tekrar al (Canlar güncellenmiş olabilir)
      if (state is! BattleInProgress) return;
      currentState = state as BattleInProgress;

      final alivePlayers = currentState.playerTeam.where((p) => p.isAlive).toList();
      if (alivePlayers.isEmpty) break;

      // Rastgele bir hedef seç
      final target = alivePlayers[Random().nextInt(alivePlayers.length)];
      final rawDamage = (enemy.currentAttackPower * enemy.element.getDamageMultiplier(target.element)).round();
      final defenseReduction = (target.currentDefensePower * 0.2).round();
      final damage = max(1, rawDamage - defenseReduction);

      final updatedPlayerTeam = currentState.playerTeam.map((p) {
        if (p.id == target.id) {
          return p.copyWith(health: (p.health - damage).clamp(0, p.currentCp).toInt());
        }
        return p;
      }).toList();

      final log = "${enemy.name} hiddetle saldırdı: ${target.name} $damage hasar aldı!";

      currentState = currentState.copyWith(
        playerTeam: updatedPlayerTeam,
        battleLogs: [log, ...currentState.battleLogs],
      );

      emit(currentState);

      // Kaybetme Kontrolü
      if (updatedPlayerTeam.every((p) => !p.isAlive)) {
        emit(const BattleResult(message: "MAĞLUBİYET... Kut elimizden kayıp gitti.", isVictory: false));
        return;
      }
    }

    // Düşman turu bitti, yeni tura geç ve oyuncuya ver
    await Future.delayed(const Duration(milliseconds: 500));
    if (state is BattleInProgress) {
      final nextTurnState = (state as BattleInProgress).copyWith(
        isPlayerTurn: true,
        currentTurn: (state as BattleInProgress).currentTurn + 1,
        actedHeroIds: [],
        battleLogs: ["Yeni Tur başladı (${(state as BattleInProgress).currentTurn + 1})", ...(state as BattleInProgress).battleLogs],
      );
      emit(nextTurnState);
    }
  }

  /// 30 karakterlik mock kart havuzu
  List<HeroCardEntity> _getHeroCardPool() {
    List<HeroCardEntity> cards = [];
    int id = 0;

    // Fire (Ateş) - 5 kart
    cards.addAll([
      _buildCard(id++, "Ateş Başkanı", HeroElement.fire, HeroRole.warrior, 38, 12, 245),
      _buildCard(id++, "Ateş Aslanı", HeroElement.fire, HeroRole.warrior, 36, 12, 242),
      _buildCard(id++, "Ateş Sipahi", HeroElement.fire, HeroRole.tank, 18, 20, 248),
      _buildCard(id++, "Ateş Koruma", HeroElement.fire, HeroRole.tank, 16, 22, 250),
      _buildCard(id++, "Ateş Şamani", HeroElement.fire, HeroRole.support, 14, 10, 265),
    ]);

    // Water (Su) - 5 kart
    cards.addAll([
      _buildCard(id++, "Su Cini", HeroElement.water, HeroRole.warrior, 38, 12, 245),
      _buildCard(id++, "Balık Prens", HeroElement.water, HeroRole.warrior, 36, 12, 242),
      _buildCard(id++, "Su Sipahi", HeroElement.water, HeroRole.tank, 18, 20, 248),
      _buildCard(id++, "Su Perisi", HeroElement.water, HeroRole.tank, 16, 22, 250),
      _buildCard(id++, "Su Şamani", HeroElement.water, HeroRole.support, 14, 10, 265),
    ]);

    // Wind (Rüzgar) - 5 kart
    cards.addAll([
      _buildCard(id++, "Rüzgar Şahı", HeroElement.wind, HeroRole.warrior, 38, 12, 245),
      _buildCard(id++, "Fırtına Cini", HeroElement.wind, HeroRole.warrior, 36, 12, 242),
      _buildCard(id++, "Hava Sipahi", HeroElement.wind, HeroRole.tank, 18, 20, 248),
      _buildCard(id++, "Hava Koruma", HeroElement.wind, HeroRole.tank, 16, 22, 250),
      _buildCard(id++, "Hava Şamani", HeroElement.wind, HeroRole.support, 14, 10, 265),
    ]);

    // Forest (Orman) - 5 kart
    cards.addAll([
      _buildCard(id++, "Orman Cini", HeroElement.forest, HeroRole.warrior, 38, 12, 245),
      _buildCard(id++, "Ağaç Satırı", HeroElement.forest, HeroRole.warrior, 36, 12, 242),
      _buildCard(id++, "Orman Sipahi", HeroElement.forest, HeroRole.tank, 18, 20, 248),
      _buildCard(id++, "Ağaç Perisi", HeroElement.forest, HeroRole.tank, 16, 22, 250),
      _buildCard(id++, "Orman Şamani", HeroElement.forest, HeroRole.support, 14, 10, 265),
    ]);

    // Dark (Karanlık) - 5 kart
    cards.addAll([
      _buildCard(id++, "Karanlık Savaşçı", HeroElement.dark, HeroRole.warrior, 38, 12, 245),
      _buildCard(id++, "Gölge Alp", HeroElement.dark, HeroRole.warrior, 36, 12, 242),
      _buildCard(id++, "Gölge Sipahi", HeroElement.dark, HeroRole.tank, 18, 20, 248),
      _buildCard(id++, "Karanlık Koruma", HeroElement.dark, HeroRole.tank, 16, 22, 250),
      _buildCard(id++, "Karanlık Şamani", HeroElement.dark, HeroRole.support, 14, 10, 265),
    ]);

    // Steppe (Bozkır) - 5 kart
    cards.addAll([
      _buildCard(id++, "Bozkır Savaşçı", HeroElement.steppe, HeroRole.warrior, 38, 12, 245),
      _buildCard(id++, "Steppe Cini", HeroElement.steppe, HeroRole.warrior, 36, 12, 242),
      _buildCard(id++, "Bozkır Sipahi", HeroElement.steppe, HeroRole.tank, 18, 20, 248),
      _buildCard(id++, "Steppe Koruma", HeroElement.steppe, HeroRole.tank, 16, 22, 250),
      _buildCard(id++, "Bozkır Şamani", HeroElement.steppe, HeroRole.support, 14, 10, 265),
    ]);

    return cards;
  }

  /// Kart inşa yardımcısı
  HeroCardEntity _buildCard(
    int id,
    String name,
    HeroElement element,
    HeroRole role,
    int attackPower,
    int defensePower,
    int baseCp,
  ) {
    final xp = Random().nextInt(5000);
    final level = 1 + (xp ~/ 1000);
    final levelMultiplier = 1 + level * 0.1;
    final startingHealth = (baseCp * levelMultiplier).round();

    return HeroCardEntity(
      id: "card_$id",
      name: name,
      description: "Türk mitolojisinin efsanevi kahramanı.",
      element: element,
      role: role,
      xp: xp,
      cp: baseCp,
      health: startingHealth,
      attackPower: attackPower,
      defensePower: defensePower,
      imageUrl: "🎴",
    );
  }}