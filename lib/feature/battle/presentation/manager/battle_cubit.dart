import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../battle/domain/entities/hero_entities.dart';
import 'battle_state.dart';

class BattleCubit extends Cubit<BattleState> {
  BattleCubit() : super(const BattleInitial());

  /// 3v3 Savaşı başlatan fonksiyon
  void startBattle() {
    emit(const BattleLoading());

    // Örnek Oyuncu Takımı
    final playerTeam = [
      _createHero("p1", "Kam Arat", HeroElement.fire, HeroRole.warrior),
      _createHero("p2", "Gökçe", HeroElement.water, HeroRole.support),
      _createHero("p3", "Demirhan", HeroElement.steppe, HeroRole.tank),
    ];

    // Örnek Düşman Takımı
    final enemyTeam = [
      _createHero("e1", "Erlik Elçisi", HeroElement.dark, HeroRole.mage),
      _createHero("e2", "Gölge Alp", HeroElement.wind, HeroRole.warrior),
      _createHero("e3", "Yeraltı Devi", HeroElement.forest, HeroRole.tank),
    ];

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

    // Hasar hesaplama (Basit mantık, ileride usecase'e taşınabilir)
    final damage = attacker.attackPower;
    final newHealth = (target.health - damage).clamp(0, 100).toDouble();

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
      final damage = enemy.attackPower;

      final updatedPlayerTeam = currentState.playerTeam.map((p) {
        if (p.id == target.id) {
          return p.copyWith(health: (p.health - damage).clamp(0, 100).toInt());
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

  /// Yardımcı kahraman oluşturucu
  HeroCardEntity _createHero(String id, String name, HeroElement element, HeroRole role) {
    int hp = 100 + Random().nextInt(35);
    return HeroCardEntity(
      id: id,
      name: name,
      description: "Kadim bozkırların savaşçısı.",
      element: element,
      role: role,
      level: Random().nextInt(5),
      health: hp,
      healthPower: hp,
      attackPower: 20 + Random().nextInt(15), // 20-35 arası güç
      defensePower: 10,
      imageUrl: "🎴",
    );
  }
}