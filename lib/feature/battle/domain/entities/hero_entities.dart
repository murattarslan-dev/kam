import 'package:flutter/foundation.dart';
import 'dart:math';
/// HeroElement represents the elemental affinity of a hero.
enum HeroElement {
  fire,
  dark,
  wind,
  steppe,
  water,
  forest;

  /// Returns the damage multiplier based on elemental matchups.
  /// Used to scale base damage before defense calculations.
  double getDamageMultiplier(HeroElement target) {
    return switch (this) {
      HeroElement.fire => switch (target) {
        HeroElement.forest => 1.5, // Strong against forest
        HeroElement.water => 0.7,  // Weak against water
        HeroElement.steppe => 1.2, // Bonus in the dry steppe
        _ => 1.0,
      },
      HeroElement.dark => switch (target) {
        HeroElement.forest => 1.2,
        HeroElement.steppe => 1.1,
        _ => 1.0,
      },
      HeroElement.wind => switch (target) {
        HeroElement.steppe => 1.5,
        HeroElement.fire => 1.2,
        HeroElement.forest => 0.8,
        _ => 1.0,
      },
      HeroElement.steppe => switch (target) {
        HeroElement.water => 1.3,
        HeroElement.wind => 0.7,
        _ => 1.0,
      },
      HeroElement.water => switch (target) {
        HeroElement.fire => 1.5,
        HeroElement.forest => 1.2,
        HeroElement.steppe => 0.7,
        _ => 1.0,
      },
      HeroElement.forest => switch (target) {
        HeroElement.wind => 1.4,
        HeroElement.fire => 0.6,
        _ => 1.0,
      },
    };
  }

  String get label => name[0].toUpperCase() + name.substring(1);

  static HeroElement fromString(String value) {
    return HeroElement.values.firstWhere(
      (e) => e.name == value,
      orElse: () => HeroElement.steppe,
    );
  }
}

/// HeroRole defines the class and primary function of the hero.
enum HeroRole {
  warrior,
  support,
  mage,
  tank;

  String get label => name[0].toUpperCase() + name.substring(1);

  static HeroRole fromString(String value) {
    return HeroRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => HeroRole.warrior,
    );
  }
}

/// HeroCardEntity represents a hero card in the "Kam: Kut'un Doğuşu" universe.
@immutable
class HeroCardEntity {
  final String id;
  final String name;
  final String description;
  final HeroElement element;
  final HeroRole role;
  final int xp;
  final int cp;
  final int health;
  final int attackPower;
  final int defensePower;
  final String imageUrl;
  final int kut;
  final int bonusAttack;
  final int bonusDefense;
  final int bonusMaxHealth;
  /// Kahramanın sahip olduğu Tözler — `buffs/{id}` referansları.
  /// Töz tetiklendiğinde buff doğrudan uygulanır; maliyet ve kullanım
  /// koşulu buff'ın kendisinden okunur.
  final List<String> tozler;
  /// users/{uid}/heroes/{userHeroDocId} — XP güncellemesi için saklanır.
  /// Global heroes koleksiyonundan yüklenen kahramanlarda boş kalır.
  final String userHeroDocId;

  const HeroCardEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.element,
    required this.role,
    required this.xp,
    required this.cp,
    required this.health,
    required this.attackPower,
    required this.defensePower,
    required this.imageUrl,
    this.kut = 0,
    this.bonusAttack = 0,
    this.bonusDefense = 0,
    this.bonusMaxHealth = 0,
    this.tozler = const [],
    this.userHeroDocId = '',
  });

  /// Returns true if the hero is still able to fight.
  bool get isAlive => health > 0;

  /// Current hero level derived from experience.
  int get level {
    int lvl = 1;
    while (250 * lvl * (lvl + 1) <= xp) {
      lvl++;
    }
    return lvl;
  }

  /// The multiplier applied on base stats for the current level.
  double get levelMultiplier => 1 + level * 0.2;

  /// Seviye çarpanı uygulanmış temel statlar (bonus dahil değil).
  /// Yüzdesel buff hesabı bu değerler üzerinden yapılır.
  int get baseAttackScaled => (attackPower * levelMultiplier).round();
  int get baseDefenseScaled => (defensePower * levelMultiplier).round();
  int get baseMaxHealthScaled => (cp * levelMultiplier).round();

  /// Current attack value used in battle and UI display.
  int get currentAttackPower => baseAttackScaled + bonusAttack;

  /// Current defense value used in battle and UI display.
  int get currentDefensePower => baseDefenseScaled + bonusDefense;

  /// Current maximum health pool derived from CP and level (+ bonus).
  int get currentCp => baseMaxHealthScaled + bonusMaxHealth;

  /// Current health remaining during battle.
  int get currentHealth => health;

  /// Remaining XP until the next level.
  int get xpToNextLevel {
  final nextThreshold = 250 * level * (level + 1);
  return nextThreshold - xp;
}

/// Progress to next level as a fraction.
double get xpProgress {
  final currentThreshold = 250 * (level - 1) * level;
  final nextThreshold = 250 * level * (level + 1);
  final span = nextThreshold - currentThreshold;
  return span == 0 ? 0 : (xp - currentThreshold) / span;
}

  /// Calculates the potential damage output against a target,
  /// considering elemental matchup and the current attack value.
  int calculatePotentialDamage(HeroCardEntity opponent) {
    final multiplier = element.getDamageMultiplier(opponent.element);
    return (currentAttackPower * multiplier).round();
  }

  /// Creates a copy of the entity with updated fields for state management.
  HeroCardEntity copyWith({
    int? xp,
    int? cp,
    int? health,
    int? attackPower,
    int? defensePower,
    int? kut,
    int? bonusAttack,
    int? bonusDefense,
    int? bonusMaxHealth,
    List<String>? tozler,
  }) {
    return HeroCardEntity(
      id: id,
      name: name,
      description: description,
      element: element,
      role: role,
      xp: xp ?? this.xp,
      cp: cp ?? this.cp,
      health: health ?? this.health,
      attackPower: attackPower ?? this.attackPower,
      defensePower: defensePower ?? this.defensePower,
      imageUrl: imageUrl,
      kut: kut ?? this.kut,
      bonusAttack: bonusAttack ?? this.bonusAttack,
      bonusDefense: bonusDefense ?? this.bonusDefense,
      bonusMaxHealth: bonusMaxHealth ?? this.bonusMaxHealth,
      tozler: tozler ?? this.tozler,
      userHeroDocId: userHeroDocId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'element': element.name,
      'role': role.name,
      'hp': cp, // UI holds cp as max health
      'atk': attackPower,
      'def': defensePower,
      'imageUrl': imageUrl,
      'tozler': tozler,
    };
  }

  factory HeroCardEntity.fromMap(Map<String, dynamic> map) {
    final xp = map['xp'] as int? ?? Random().nextInt(10000);
    final hp = map['hp'] as int? ?? 100; // Yeni yapı: hp

    // Mevcut seviyeye göre maksimum canı hesapla
    int level = 1;
    while (250 * level * (level + 1) <= xp) {
      level++;
    }
    final levelMultiplier = 1 + level * 0.2;
    final maxHealth = (hp * levelMultiplier).round();

    return HeroCardEntity(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Adsız Kahraman',
      description: map['description'] as String? ?? '',
      element: HeroElement.fromString(map['element'] as String? ?? 'steppe'),
      role: HeroRole.fromString(map['role'] as String? ?? 'warrior'),
      xp: xp,
      cp: hp,
      health: maxHealth,
      attackPower: map['atk'] as int? ?? 10,
      defensePower: map['def'] as int? ?? 5,
      imageUrl: map['imageUrl'] as String? ?? '',
      kut: 0,
      bonusAttack: 0,
      bonusDefense: 0,
      tozler: ((map['tozler'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      userHeroDocId: map['userHeroDocId'] as String? ?? '',
    );
  }
}
