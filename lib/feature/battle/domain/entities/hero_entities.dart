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

/// HeroCardEntity represents a hero card in the "Kam: Kut'un Doğuşu" universe.
@immutable
class HeroCardEntity {
  final String id;
  final String name;
  final String description;
  final HeroElement element;
  final HeroRole role;
  final int level;
  final int health;
  final int healthPower;
  final int attackPower;
  final int defensePower;
  final String imageUrl;

  const HeroCardEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.element,
    required this.role,
    required this.level,
    required this.health,
    required this.healthPower,
    required this.attackPower,
    required this.defensePower,
    required this.imageUrl,
  });

  /// Returns true if the hero is still able to fight.
  bool get isAlive => health > 0;

  /// Calculates the potential damage output against a target,
  /// considering only the elemental multiplier and base attack.
  /// Defense and Buffs should be handled in a UseCase or Service.
  int calculatePotentialDamage(HeroCardEntity opponent) {
    final multiplier = element.getDamageMultiplier(opponent.element);
    return (attackPower * multiplier).round();
  }

  /// Creates a copy of the entity with updated fields for state management.
  HeroCardEntity copyWith({
    int? health,
    int? healthPower,
    int? attackPower,
    int? defensePower,
  }) {
    return HeroCardEntity(
      id: id,
      name: name,
      description: description,
      element: element,
      role: role,
      level: level,
      health: health ?? this.health,
      healthPower: healthPower ?? this.healthPower,
      attackPower: attackPower ?? this.attackPower,
      defensePower: defensePower ?? this.defensePower,
      imageUrl: imageUrl,
    );
  }
}