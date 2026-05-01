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
}

/// HeroRole defines the class and primary function of the hero.
enum HeroRole {
  warrior,
  support,
  mage,
  tank;

  String get label => name[0].toUpperCase() + name.substring(1);
}

/// Töz Type defines what kind of effect the skill card will have.
enum SkillType {
  heal,
  attackBuff,
  defenseBuff,
}

/// PrerequisiteTarget defines who to check for elemental requirements.
enum PrerequisiteTarget {
  teammate,
  opponent,
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
}