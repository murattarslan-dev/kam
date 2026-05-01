import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../battle/domain/entities/hero_entities.dart';
import 'battle_state.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/firebase/firebase_service.dart';

class BattleCubit extends Cubit<BattleState> {
  final FirebaseService _firebaseService = sl<FirebaseService>();

  BattleCubit() : super(const BattleInitial());

  /// Firestore'dan verileri çeker ve savaşı başlatır
  Future<void> startBattle() async {
    emit(const BattleLoading());

    try {
      final user = _firebaseService.currentUser;
      if (user == null) {
        emit(const BattleError("Oturum açılmış bir kullanıcı bulunamadı!"));
        return;
      }

      // 1. Oyuncunun kahramanlarını getir
      final playerHeroes = await _firebaseService.fetchUserHeroes(user.uid);
      if (playerHeroes.isEmpty) {
        emit(const BattleError("Kullanıcıya ait kahraman bulunamadı!"));
        return;
      }

      // 2. Düşman için tüm kahramanları getir ve rastgele 3 tane seç
      final allGlobalHeroes = await _firebaseService.fetchHeroes();
      if (allGlobalHeroes.length < 3) {
        emit(const BattleError("Savaş için yeterli küresel kahraman bulunamadı!"));
        return;
      }

      final random = Random();
      final List<HeroCardEntity> enemyTeam = [];
      final List<HeroCardEntity> pool = List.from(allGlobalHeroes)..shuffle(random);
      
      for (var i = 0; i < 3; i++) {
        // Düşman kahramanlarının XP'sini 2364 yap (Statları buna göre hesaplanacak)
        final baseHero = pool[i];
        final enemyHero = HeroCardEntity.fromMap(
          baseHero.toMap()..['xp'] = 2364, 
          skills: baseHero.skillCards,
        );
        enemyTeam.add(enemyHero);
      }

      final playerTeam = playerHeroes.take(3).toList();

      emit(BattleInProgress(
        playerTeam: playerTeam,
        enemyTeam: enemyTeam,
        battleLogs: ["Savaş başladı! Oyuncu ve düşman takımları hazır."],
      ));
    } catch (e) {
      print("Start Battle Error: $e");
      emit(BattleError("Savaş başlatılamadı: $e"));
    }
  }

  /// Bir kahramanı seçme veya hedef belirleme
  void selectHero(int index, bool isEnemy) {
    if (state is! BattleInProgress) return;
    final currentState = state as BattleInProgress;

    // Sıra oyuncuda değilse seçim yapılamaz
    if (!currentState.isPlayerTurn) return;

    if (isEnemy) {
      // Oyuncu kartı seçilmeden düşman seçilemez
      if (currentState.selectedHeroIndex == null) return;
      
      // Düşman kartına tıklandı: Hedef seçimi
      if (currentState.enemyTeam[index].isAlive) {
        if (currentState.selectedTargetIndex == index) {
          emit(currentState.copyWith(clearTarget: true));
        } else {
          emit(currentState.copyWith(selectedTargetIndex: index));
        }
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
        }
      }
    }
  }

  /// Oyuncu saldırısını başlatır (Animasyonu tetikler)
  void executePlayerAttack() {
    if (state is! BattleInProgress) return;
    final currentState = state as BattleInProgress;

    if (currentState.selectedHeroIndex == null || currentState.selectedTargetIndex == null) return;

    final attacker = currentState.playerTeam[currentState.selectedHeroIndex!];
    final target = currentState.enemyTeam[currentState.selectedTargetIndex!];

    emit(currentState.copyWith(
      currentAction: BattleAction(
        attacker: attacker,
        target: target,
        isPlayerAttacking: true,
      ),
    ));
  }

  /// Animasyon tamamlandığında hasarı uygular
  void onAnimationComplete() {
    if (state is! BattleInProgress) return;
    final currentState = state as BattleInProgress;
    final action = currentState.currentAction;
    if (action == null) return;

    if (action.isPlayerAttacking) {
      _applyPlayerAttack(currentState, action);
    } else {
      // Düşman saldırısı zaten döngü içinde yönetiliyor, 
      // ama animasyon bitişini beklemek için bir sinyal verebiliriz.
      _enemyAnimationCompleter?.complete();
    }
  }

  Completer<void>? _enemyAnimationCompleter;

  void _applyPlayerAttack(BattleInProgress currentState, BattleAction action) {
    final attacker = action.attacker;
    final target = action.target;

    // Hasar hesaplama
    final rawDamage = (attacker.currentAttackPower * attacker.element.getDamageMultiplier(target.element)).round();
    final defenseReduction = (target.currentDefensePower).round();
    final damage = max(1, rawDamage - defenseReduction);
    final newHealth = (target.health - damage).clamp(0, target.currentCp).toDouble();

    int earnedKut = 0;
    if (newHealth <= 0) {
      earnedKut = 2;
    }

    // Düşman takımını güncelle
    final updatedEnemyTeam = List<HeroCardEntity>.from(currentState.enemyTeam);
    final targetIndex = updatedEnemyTeam.indexWhere((e) => e.id == target.id);
    if (targetIndex != -1) {
      updatedEnemyTeam[targetIndex] = target.copyWith(health: newHealth.toInt());
    }

    // Oyuncu takımını güncelle
    final updatedPlayerTeam = List<HeroCardEntity>.from(currentState.playerTeam);
    final attackerIndex = updatedPlayerTeam.indexWhere((p) => p.id == attacker.id);
    if (attackerIndex != -1) {
       updatedPlayerTeam[attackerIndex] = attacker.copyWith(kut: attacker.kut + earnedKut);
    }

    final newLog = "${attacker.name}, ${target.name} birimine $damage hasar verdi!${earnedKut > 0 ? " (+2 Kut kazandı!)" : ""}";
    final updatedLogs = List<String>.from(currentState.battleLogs)..insert(0, newLog);

    final updatedDamageMap = Map<String, double>.from(currentState.totalDamageDealt);
    updatedDamageMap[attacker.id] = (updatedDamageMap[attacker.id] ?? 0) + damage;

    final updatedActedIds = List<String>.from(currentState.actedHeroIds)..add(attacker.id);

    final nextState = currentState.copyWith(
      playerTeam: updatedPlayerTeam,
      enemyTeam: updatedEnemyTeam,
      battleLogs: updatedLogs,
      actedHeroIds: updatedActedIds,
      totalDamageDealt: updatedDamageMap,
      clearSelection: true,
      clearAction: true,
    );

    _processTurnEnd(nextState);
  }

  /// Seçilen kahraman için Töz kartı kullan
  void useSkill(int heroIndex, SkillEntity skill) {
    if (state is! BattleInProgress) return;
    final currentState = state as BattleInProgress;
    
    // Sıra oyuncuda değilse seçim yapılamaz
    if (!currentState.isPlayerTurn) return;
    
    // Zaten kullanıldı mı kontrolü
    if (currentState.usedSkillIds.contains(skill.id)) return;
    
    final hero = currentState.playerTeam[heroIndex];
    if (!hero.isAlive) return;
    
    // Kut yeterli mi kontrolü
    if (hero.kut < skill.cost) return;
    
    // Önkoşul kontrolü
    if (!isSkillPrerequisiteMet(hero, skill)) return;
    
    // Töz etkisini uygula
    HeroCardEntity updatedHero = hero.copyWith(kut: hero.kut - skill.cost);
    String logMsg = "";
    
    switch (skill.type) {
      case SkillType.heal:
        final newHealth = (updatedHero.health + skill.value).clamp(0, updatedHero.currentCp);
        updatedHero = updatedHero.copyWith(health: newHealth.toInt());
        logMsg = "${hero.name}, ${skill.name} kullandı! ${skill.value} Can yeniledi.";
        break;
      case SkillType.attackBuff:
        updatedHero = updatedHero.copyWith(bonusAttack: updatedHero.bonusAttack + skill.value);
        logMsg = "${hero.name}, ${skill.name} kullandı! Saldırı gücü ${skill.value} arttı.";
        break;
      case SkillType.defenseBuff:
        updatedHero = updatedHero.copyWith(bonusDefense: updatedHero.bonusDefense + skill.value);
        logMsg = "${hero.name}, ${skill.name} kullandı! Savunma gücü ${skill.value} arttı.";
        break;
    }
    
    final updatedPlayerTeam = List<HeroCardEntity>.from(currentState.playerTeam);
    updatedPlayerTeam[heroIndex] = updatedHero;
    
    final updatedUsedSkillIds = List<String>.from(currentState.usedSkillIds)..add(skill.id);
    final updatedLogs = List<String>.from(currentState.battleLogs)..insert(0, logMsg);
    
    emit(currentState.copyWith(
      playerTeam: updatedPlayerTeam,
      usedSkillIds: updatedUsedSkillIds,
      battleLogs: updatedLogs,
    ));
  }

  /// Töz kartının önkoşullarının sağlanıp sağlanmadığını kontrol eder
  bool isSkillPrerequisiteMet(HeroCardEntity hero, SkillEntity skill) {
    final prerequisite = skill.prerequisite;
    if (prerequisite == null) return true;

    if (state is! BattleInProgress) return false;
    final currentState = state as BattleInProgress;

    final targetTeam = prerequisite.target == PrerequisiteTarget.teammate
        ? currentState.playerTeam
        : currentState.enemyTeam;

    int count = 0;
    for (var member in targetTeam) {
      // Kendini takım arkadaşı olarak sayma (isteğe bağlı, genelde "arkadaş" dendiğinde başkası kastedilir)
      if (prerequisite.target == PrerequisiteTarget.teammate && member.id == hero.id) continue;
      
      if (member.isAlive && prerequisite.requiredElements.contains(member.element)) {
        count++;
      }
    }

    return count >= prerequisite.minCount;
  }

  /// Tur sonu kontrollerini yapar (Kazanma/Sıra Değişimi)
  void _processTurnEnd(BattleInProgress nextState) {
    // 1. Kazanma Kontrolü
    if (nextState.enemyTeam.every((e) => !e.isAlive)) {
      _finalizeXp(isVictory: true);
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
      
      // Animasyonu başlat
      _enemyAnimationCompleter = Completer<void>();
      emit(currentState.copyWith(
        currentAction: BattleAction(
          attacker: enemy,
          target: target,
          isPlayerAttacking: false,
        ),
      ));

      // Animasyonun bitmesini bekle
      await _enemyAnimationCompleter!.future;
      _enemyAnimationCompleter = null;

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
        clearAction: true,
      );

      emit(currentState);

      // Kaybetme Kontrolü
      if (updatedPlayerTeam.every((p) => !p.isAlive)) {
        _finalizeXp(isVictory: false);
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

  /// Savaş sonunda kahramanlara XP'lerini dağıtır
  Future<void> _finalizeXp({required bool isVictory}) async {
    if (state is! BattleInProgress) return;
    final currentState = state as BattleInProgress;
    final user = _firebaseService.currentUser;
    if (user == null) return;

    for (var hero in currentState.playerTeam) {
      // 1. Verdiği hasar kadar XP
      int damageXp = (currentState.totalDamageDealt[hero.id] ?? 0).round();
      
      // 2. Zafer bonusu
      int victoryXp = isVictory ? 300 : 0;
      
      int totalGain = damageXp + victoryXp;
      
      if (totalGain > 0) {
        // Firestore'u güncelle
        await _firebaseService.updateHeroXp(user.uid, hero.id, totalGain);
      }
    }
  }
}