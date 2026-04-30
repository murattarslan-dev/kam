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

    int earnedKut = 0;
    if (newHealth <= 0) {
      earnedKut = 2; // Düşman öldürülürse +2 Kut
    }

    // Düşman takımını güncelle
    final updatedEnemyTeam = List<HeroCardEntity>.from(currentState.enemyTeam);
    updatedEnemyTeam[currentState.selectedTargetIndex!] = target.copyWith(health: newHealth.toInt());

    // Oyuncu takımını güncelle (Kut için)
    final updatedPlayerTeam = List<HeroCardEntity>.from(currentState.playerTeam);
    if (earnedKut > 0) {
       updatedPlayerTeam[currentState.selectedHeroIndex!] = attacker.copyWith(kut: attacker.kut + earnedKut);
    }

    // Log ve İstatistikler
    final newLog = "${attacker.name}, ${target.name} birimine $damage hasar verdi!" + (earnedKut > 0 ? " (+2 Kut kazandı!)" : "");
    final updatedLogs = List<String>.from(currentState.battleLogs)..insert(0, newLog);

    final updatedDamageMap = Map<String, double>.from(currentState.totalDamageDealt);
    updatedDamageMap[attacker.id] = (updatedDamageMap[attacker.id] ?? 0) + damage;

    // Hamle yapanları güncelle
    final updatedActedIds = List<String>.from(currentState.actedHeroIds)..add(attacker.id);

    final nextState = currentState.copyWith(
      playerTeam: updatedPlayerTeam,
      enemyTeam: updatedEnemyTeam,
      battleLogs: updatedLogs,
      actedHeroIds: updatedActedIds,
      totalDamageDealt: updatedDamageMap,
      clearSelection: true,
    );

    _processTurnEnd(nextState);
  }

  /// Seçilen kahraman için Töz kartı kullan
  void useToz(int heroIndex, TozEntity toz) {
    if (state is! BattleInProgress) return;
    final currentState = state as BattleInProgress;
    
    // Sıra oyuncuda değilse seçim yapılamaz
    if (!currentState.isPlayerTurn) return;
    
    // Zaten kullanıldı mı kontrolü
    if (currentState.usedTozIds.contains(toz.id)) return;
    
    final hero = currentState.playerTeam[heroIndex];
    if (!hero.isAlive) return;
    
    // Kut yeterli mi kontrolü
    if (hero.kut < toz.cost) return;
    
    // Töz etkisini uygula
    HeroCardEntity updatedHero = hero.copyWith(kut: hero.kut - toz.cost);
    String logMsg = "";
    
    switch (toz.type) {
      case TozType.heal:
        final newHealth = (updatedHero.health + toz.value).clamp(0, updatedHero.currentCp);
        updatedHero = updatedHero.copyWith(health: newHealth.toInt());
        logMsg = "${hero.name}, ${toz.name} kullandı! ${toz.value} Can yeniledi.";
        break;
      case TozType.attackBuff:
        updatedHero = updatedHero.copyWith(bonusAttack: updatedHero.bonusAttack + toz.value);
        logMsg = "${hero.name}, ${toz.name} kullandı! Saldırı gücü ${toz.value} arttı.";
        break;
      case TozType.defenseBuff:
        updatedHero = updatedHero.copyWith(bonusDefense: updatedHero.bonusDefense + toz.value);
        logMsg = "${hero.name}, ${toz.name} kullandı! Savunma gücü ${toz.value} arttı.";
        break;
    }
    
    final updatedPlayerTeam = List<HeroCardEntity>.from(currentState.playerTeam);
    updatedPlayerTeam[heroIndex] = updatedHero;
    
    final updatedUsedTozIds = List<String>.from(currentState.usedTozIds)..add(toz.id);
    final updatedLogs = List<String>.from(currentState.battleLogs)..insert(0, logMsg);
    
    emit(currentState.copyWith(
      playerTeam: updatedPlayerTeam,
      usedTozIds: updatedUsedTozIds,
      battleLogs: updatedLogs,
    ));
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
      var current = state as BattleInProgress;
      // Yeni turda oyuncunun yaşayan karakterlerine +1 Kut
      final updatedPlayerTeam = current.playerTeam.map((p) {
        if (p.isAlive) {
          return p.copyWith(kut: p.kut + 1);
        }
        return p;
      }).toList();

      final nextTurnState = current.copyWith(
        playerTeam: updatedPlayerTeam,
        isPlayerTurn: true,
        currentTurn: current.currentTurn + 1,
        actedHeroIds: [],
        battleLogs: ["Yeni Tur başladı (${current.currentTurn + 1}). Tüm canlı kahramanlar +1 Kut kazandı!", ...current.battleLogs],
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
      _buildCard(id++, "Ateş Başkanı", HeroElement.fire, HeroRole.warrior, 38, 12, 145),
      _buildCard(id++, "Ateş Aslanı", HeroElement.fire, HeroRole.warrior, 36, 12, 142),
      _buildCard(id++, "Ateş Sipahi", HeroElement.fire, HeroRole.tank, 18, 20, 148),
      _buildCard(id++, "Ateş Koruma", HeroElement.fire, HeroRole.tank, 16, 22, 150),
      _buildCard(id++, "Ateş Şamani", HeroElement.fire, HeroRole.support, 14, 10, 165),
    ]);

    // Water (Su) - 5 kart
    cards.addAll([
      _buildCard(id++, "Su Cini", HeroElement.water, HeroRole.warrior, 38, 12, 145),
      _buildCard(id++, "Balık Prens", HeroElement.water, HeroRole.warrior, 36, 12, 142),
      _buildCard(id++, "Su Sipahi", HeroElement.water, HeroRole.tank, 18, 20, 148),
      _buildCard(id++, "Su Perisi", HeroElement.water, HeroRole.tank, 16, 22, 150),
      _buildCard(id++, "Su Şamani", HeroElement.water, HeroRole.support, 14, 10, 165),
    ]);

    // Wind (Rüzgar) - 5 kart
    cards.addAll([
      _buildCard(id++, "Rüzgar Şahı", HeroElement.wind, HeroRole.warrior, 38, 12, 145),
      _buildCard(id++, "Fırtına Cini", HeroElement.wind, HeroRole.warrior, 36, 12, 142),
      _buildCard(id++, "Hava Sipahi", HeroElement.wind, HeroRole.tank, 18, 20, 148),
      _buildCard(id++, "Hava Koruma", HeroElement.wind, HeroRole.tank, 16, 22, 150),
      _buildCard(id++, "Hava Şamani", HeroElement.wind, HeroRole.support, 14, 10, 165),
    ]);

    // Forest (Orman) - 5 kart
    cards.addAll([
      _buildCard(id++, "Orman Cini", HeroElement.forest, HeroRole.warrior, 38, 12, 145),
      _buildCard(id++, "Ağaç Satırı", HeroElement.forest, HeroRole.warrior, 36, 12, 142),
      _buildCard(id++, "Orman Sipahi", HeroElement.forest, HeroRole.tank, 18, 20, 148),
      _buildCard(id++, "Ağaç Perisi", HeroElement.forest, HeroRole.tank, 16, 22, 150),
      _buildCard(id++, "Orman Şamani", HeroElement.forest, HeroRole.support, 14, 10, 165),
    ]);

    // Dark (Karanlık) - 5 kart
    cards.addAll([
      _buildCard(id++, "Karanlık Savaşçı", HeroElement.dark, HeroRole.warrior, 38, 12, 145),
      _buildCard(id++, "Gölge Alp", HeroElement.dark, HeroRole.warrior, 36, 12, 142),
      _buildCard(id++, "Gölge Sipahi", HeroElement.dark, HeroRole.tank, 18, 20, 148),
      _buildCard(id++, "Karanlık Koruma", HeroElement.dark, HeroRole.tank, 16, 22, 150),
      _buildCard(id++, "Karanlık Şamani", HeroElement.dark, HeroRole.support, 14, 10, 165),
    ]);

    // Steppe (Bozkır) - 5 kart
    cards.addAll([
      _buildCard(id++, "Bozkır Savaşçı", HeroElement.steppe, HeroRole.warrior, 38, 12, 145),
      _buildCard(id++, "Steppe Cini", HeroElement.steppe, HeroRole.warrior, 36, 12, 142),
      _buildCard(id++, "Bozkır Sipahi", HeroElement.steppe, HeroRole.tank, 18, 20, 148),
      _buildCard(id++, "Steppe Koruma", HeroElement.steppe, HeroRole.tank, 16, 22, 150),
      _buildCard(id++, "Bozkır Şamani", HeroElement.steppe, HeroRole.support, 14, 10, 165),
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

    // Rastgele Töz kartları ata
    final randomToz = [
      TozEntity(id: "toz_heal_$id", name: "Kut Şifası", description: "50 Can yeniler", cost: 1, type: TozType.heal, value: 50),
      TozEntity(id: "toz_atk_$id", name: "Savaş Çığlığı", description: "Saldırı gücünü artırır (+10)", cost: 2, type: TozType.attackBuff, value: 10),
      TozEntity(id: "toz_def_$id", name: "Demir Beden", description: "Savunmayı artırır (+10)", cost: 1, type: TozType.defenseBuff, value: 10),
      TozEntity(id: "toz_heal2_$id", name: "Büyük Şifa", description: "100 Can yeniler", cost: 3, type: TozType.heal, value: 100),
      TozEntity(id: "toz_atk2_$id", name: "Kanlı Hiddet", description: "Saldırı gücünü çok artırır (+25)", cost: 3, type: TozType.attackBuff, value: 25),
    ];
    randomToz.shuffle();

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
      kut: 0,
      tozCards: randomToz.take(2).toList(),
    );
  }}