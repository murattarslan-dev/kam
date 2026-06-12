import 'package:flutter/foundation.dart';
import 'hero_entities.dart';

/// Bir arenanın element-bazlı hasar çarpanlarını ve sahne görsellerini taşır.
/// Nötr elementler için çarpan 1.0; >1.0 avantaj, <1.0 dezavantaj.
@immutable
class ArenaEntity {
  final String id;
  final String name;
  final String description;
  final String backgroundUrl;
  final String thumbnailUrl;
  final Map<HeroElement, double> elementEffects;

  const ArenaEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.backgroundUrl,
    required this.thumbnailUrl,
    required this.elementEffects,
  });

  double multiplierFor(HeroElement element) =>
      elementEffects[element] ?? 1.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'backgroundUrl': backgroundUrl,
      'thumbnailUrl': thumbnailUrl,
      'elementEffects': {
        for (final e in elementEffects.entries) e.key.name: e.value,
      },
    };
  }

  factory ArenaEntity.fromMap(Map<String, dynamic> map) {
    final raw = (map['elementEffects'] as Map?) ?? const {};
    final effects = <HeroElement, double>{};
    raw.forEach((k, v) {
      final el = HeroElement.values.where((e) => e.name == k).firstOrNull;
      if (el != null && v is num) effects[el] = v.toDouble();
    });
    return ArenaEntity(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      backgroundUrl: map['backgroundUrl'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
      elementEffects: effects,
    );
  }

  ArenaEntity copyWith({
    String? name,
    String? description,
    String? backgroundUrl,
    String? thumbnailUrl,
    Map<HeroElement, double>? elementEffects,
  }) {
    return ArenaEntity(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      elementEffects: elementEffects ?? this.elementEffects,
    );
  }
}
