import 'package:flutter/foundation.dart';

enum BuffType {
  statChange,
  dot, // Damage over time
  hot, // Heal over time
  damageSoak, // Absorbs a percent of incoming damage for teammates
  arenaImmunity, // Sahibini arena element çarpanından muaf tutar
  dispel, // Anlık: rakip takımdan rastgele bir kahramanın N buff'ını siler
  damageRedirect, // Sahibinin aldığı hasarın value%'unu rakip takıma eşit yansıtır
}

enum StatType {
  attack,
  defense,
  maxHealth,
  currentHealth,
}

/// `value` alanının yorumlanma biçimi.
/// - absolute: doğrudan sayı (ör. +15 saldırı).
/// - percent: temel statın yüzdesi (ör. +10 → temel saldırının %10'u).
enum ValueMode {
  absolute,
  percent;

  static ValueMode fromString(String? value) {
    return ValueMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ValueMode.absolute,
    );
  }
}

enum BuffTargetType {
  self,
  singleTeammate,
  allTeammates,
  singleEnemy,
  allEnemies,
}

enum BuffTriggerCondition {
  manual,
  onBattleStart,
  onTurnStart,
  onTurnEnd,
  onHpBelowPercent,
  onTeammateHpBelowPercent, // Buff sahibinin takım arkadaşlarından biri HP eşiğini geçince
  onTeammateDefeated,       // Buff sahibinin takım arkadaşlarından biri bayılınca
  onEnemyDefeated,          // Buff sahibinin karşı takımındaki bir düşman bayılınca
  onSkillUsed,              // Buff sahibinin takımında bir skill kullanılınca
  onDamageTaken,            // Buff sahibi hasar alınca
  passive, // Always active while prerequisites are met; re-evaluated every turn
}

enum BuffPrerequisiteType {
  none,
  heroElementIs,
  heroRoleIs,
  heroIdIs,           // kahramanın kendi ID'si eşleşmeli
  heroIdIn,           // kahramanın ID'si listede olmalı (virgülle ayrılmış değer)
  heroHpBelowPercent, // kahramanın HP'si verilen yüzdenin altında olmalı (value: "5", "10" vb.)
  hasTeammateWithElement,
  hasTeammateWithRole,
  hasTeammateWithId,  // belirli ID'ye sahip kahraman takımda olmalı
  hasEnemyWithElement,
  hasEnemyWithRole,
}

@immutable
class BuffPrerequisite {
  final BuffPrerequisiteType type;
  final String value;

  const BuffPrerequisite({required this.type, required this.value});

  static const none = BuffPrerequisite(type: BuffPrerequisiteType.none, value: '');

  factory BuffPrerequisite.fromMap(Map<String, dynamic> map) {
    return BuffPrerequisite(
      type: BuffPrerequisiteType.values.firstWhere(
        (e) => e.name == (map['type'] as String? ?? 'none'),
        orElse: () => BuffPrerequisiteType.none,
      ),
      value: map['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'value': value,
    };
  }
}

@immutable
class BuffEntity {
  final String id;
  final String name;
  final String description;
  final BuffType type;
  final StatType? statType;
  final int value;
  final ValueMode valueMode;
  final int duration; // -1 for entire battle, >0 for specific turns
  final BuffTargetType targetType;

  /// Hedefi belirledikten sonra uygulanacak ek filtre.
  /// Passive/auto buff'lar bunu kullanır (ör. "sadece ateş elementli olanlara").
  final List<BuffPrerequisite> targetFilter;

  final BuffTriggerCondition triggerCondition;
  final double? triggerValue; // e.g., 0.5 for 50% HP

  /// Sadece [triggerCondition] == manual iken anlamlıdır.
  /// Kahraman bu buff'ı manuel tetiklerken ödediği Kut maliyeti.
  final int? cost;

  /// Sadece [triggerCondition] == manual iken anlamlıdır.
  /// Buff'ı manuel kullanmadan önce takım kompozisyonu üzerinden kontrol edilir.
  final List<BuffPrerequisite> useRequirements;

  const BuffEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.statType,
    required this.value,
    this.valueMode = ValueMode.absolute,
    required this.duration,
    required this.targetType,
    this.targetFilter = const [],
    this.triggerCondition = BuffTriggerCondition.manual,
    this.triggerValue,
    this.cost,
    this.useRequirements = const [],
  });

  bool get isDebuff => value < 0;
  bool get isManual => triggerCondition == BuffTriggerCondition.manual;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'statType': statType?.name,
      'value': value,
      'valueMode': valueMode.name,
      'duration': duration,
      'targetType': targetType.name,
      'targetFilter': targetFilter.map((p) => p.toMap()).toList(),
      'triggerCondition': triggerCondition.name,
      'triggerValue': triggerValue,
      'cost': cost,
      'useRequirements': useRequirements.map((p) => p.toMap()).toList(),
    };
  }

  factory BuffEntity.fromMap(Map<String, dynamic> map) {
    // Geriye dönük: eski dokümanlarda `prerequisites` alanı targetFilter rolünü
    // üstleniyordu. Yeni alan yoksa eskisine düş.
    final rawTargetFilter =
        (map['targetFilter'] ?? map['prerequisites']) as List<dynamic>? ?? const [];

    return BuffEntity(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      type: BuffType.values.firstWhere(
        (e) => e.name == (map['type'] as String? ?? ''),
        orElse: () => BuffType.statChange,
      ),
      statType: map['statType'] != null
          ? StatType.values.firstWhere(
              (e) => e.name == map['statType'],
              orElse: () => StatType.attack,
            )
          : null,
      value: map['value'] as int? ?? 0,
      valueMode: ValueMode.fromString(map['valueMode'] as String?),
      duration: map['duration'] as int? ?? -1,
      targetType: BuffTargetType.values.firstWhere(
        (e) => e.name == (map['targetType'] as String? ?? ''),
        orElse: () => BuffTargetType.allTeammates,
      ),
      targetFilter: rawTargetFilter
          .map((p) => BuffPrerequisite.fromMap(p as Map<String, dynamic>))
          .toList(),
      triggerCondition: BuffTriggerCondition.values.firstWhere(
        (e) => e.name == (map['triggerCondition'] as String? ?? 'manual'),
        orElse: () => BuffTriggerCondition.manual,
      ),
      triggerValue: (map['triggerValue'] as num?)?.toDouble(),
      cost: map['cost'] as int?,
      useRequirements: (map['useRequirements'] as List<dynamic>? ?? const [])
          .map((p) => BuffPrerequisite.fromMap(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

@immutable
class ActiveBuff {
  final String buffId;
  final String targetHeroId;
  final int remainingTurns;

  const ActiveBuff({
    required this.buffId,
    required this.targetHeroId,
    required this.remainingTurns,
  });

  ActiveBuff copyWith({int? remainingTurns}) {
    return ActiveBuff(
      buffId: buffId,
      targetHeroId: targetHeroId,
      remainingTurns: remainingTurns ?? this.remainingTurns,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'buffId': buffId,
      'targetHeroId': targetHeroId,
      'remainingTurns': remainingTurns,
    };
  }

  factory ActiveBuff.fromMap(Map<String, dynamic> map) {
    return ActiveBuff(
      buffId: map['buffId'] as String,
      targetHeroId: map['targetHeroId'] as String,
      remainingTurns: map['remainingTurns'] as int,
    );
  }
}
