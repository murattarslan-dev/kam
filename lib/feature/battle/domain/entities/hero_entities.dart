import 'package:flutter/foundation.dart';

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

/// Töz Type defines what kind of effect the skill card will have.
enum SkillType {
  heal,
  attackBuff,
  defenseBuff;

  static SkillType fromString(String value) {
    return SkillType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SkillType.attackBuff,
    );
  }
}

/// PrerequisiteTarget defines who to check for elemental requirements.
enum PrerequisiteTarget {
  teammate,
  opponent;

  static PrerequisiteTarget fromString(String value) {
    return PrerequisiteTarget.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PrerequisiteTarget.teammate,
    );
  }
}

/// SkillPrerequisite represents the elemental requirements for a skill.
@immutable
class SkillPrerequisite {
  final PrerequisiteTarget target;
  final List<HeroElement> requiredElements;
  final int minCount;

  const SkillPrerequisite({
    required this.target,
    required this.requiredElements,
    this.minCount = 1,
  });

  String getDescription() {
    final elementNames = requiredElements.map((e) => e.label).join(", ");
    final targetName = target == PrerequisiteTarget.teammate ? "Takım Arkadaşı" : "Rakip";
    return "Gereksinim: $elementNames ($targetName)";
  }

  Map<String, dynamic> toMap() {
    return {
      'target': target.name,
      'requiredElements': requiredElements.map((e) => e.name).toList(),
      'minCount': minCount,
    };
  }

  factory SkillPrerequisite.fromMap(Map<String, dynamic> map) {
    return SkillPrerequisite(
      target: PrerequisiteTarget.fromString(map['target'] as String),
      requiredElements: (map['requiredElements'] as List<dynamic>)
          .map((e) => HeroElement.fromString(e as String))
          .toList(),
      minCount: map['minCount'] as int,
    );
  }
}

/// SkillEntity represents a skill card (Töz) in the game.
@immutable
class SkillEntity {
  final String id;
  final String name;
  final String description;
  final int cost; // Required Kut to use
  final SkillType type;
  final int value; // Heal amount, Attack Buff amount, etc.
  final SkillPrerequisite? prerequisite;

  const SkillEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.type,
    required this.value,
    this.prerequisite,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cost': cost,
      'type': type.name,
      'value': value,
      'prerequisite': prerequisite?.toMap(),
    };
  }

  factory SkillEntity.fromMap(Map<String, dynamic> map) {
    return SkillEntity(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      cost: map['cost'] as int,
      type: SkillType.fromString(map['type'] as String),
      value: map['value'] as int,
      prerequisite: map['prerequisite'] != null
          ? SkillPrerequisite.fromMap(map['prerequisite'] as Map<String, dynamic>)
          : null,
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
  final List<SkillEntity> skillCards;

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
    this.skillCards = const [],
  });

  /// Returns true if the hero is still able to fight.
  bool get isAlive => health > 0;

  /// Current hero level derived from experience.
  int get level => 1 + (xp ~/ 1000);

  /// The multiplier applied on base stats for the current level.
  double get levelMultiplier => 1 + level * 0.1;

  /// Current attack value used in battle and UI display.
  int get currentAttackPower => (attackPower * levelMultiplier).round() + bonusAttack;

  /// Current defense value used in battle and UI display.
  int get currentDefensePower => (defensePower * levelMultiplier).round() + bonusDefense;

  /// Current maximum health pool derived from CP and level.
  int get currentCp => (cp * levelMultiplier).round();

  /// Current health remaining during battle.
  int get currentHealth => health;

  /// Remaining XP until the next level.
  int get xpToNextLevel => level * 1000 - xp;

  /// Progress to next level as a fraction.
  double get xpProgress => (xp % 1000) / 1000;

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
    List<SkillEntity>? skillCards,
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
      skillCards: skillCards ?? this.skillCards,
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
    };
  }

  factory HeroCardEntity.fromMap(Map<String, dynamic> map, {List<SkillEntity> skills = const []}) {
    final xp = Random().nextInt(10000);
    final hp = map['hp'] as int? ?? 100; // Yeni yapı: hp
    
    // Mevcut seviyeye göre maksimum canı hesapla
    final level = 1 + (xp ~/ 1000);
    final levelMultiplier = 1 + level * 0.1;
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
      attackPower: map['atk'] as int? ?? 10, // Yeni yapı: atk
      defensePower: map['def'] as int? ?? 5,  // Yeni yapı: def
      imageUrl: map['imageUrl'] as String? ?? '🎴',
      kut: 0,
      bonusAttack: 0,
      bonusDefense: 0,
      skillCards: skills,
    );
  }
}