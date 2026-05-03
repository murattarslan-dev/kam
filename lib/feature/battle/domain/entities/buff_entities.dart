import 'package:flutter/foundation.dart';

enum BuffType {
  statChange,
  dot, // Damage over time
  hot, // Heal over time
}

enum StatType {
  attack,
  defense,
  maxHealth,
  currentHealth,
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
}

@immutable
class BuffEntity {
  final String id;
  final String name;
  final String description;
  final BuffType type;
  final StatType? statType;
  final int value;
  final int duration; // -1 for entire battle, >0 for specific turns
  final BuffTargetType targetType;
  final BuffTriggerCondition triggerCondition;
  final double? triggerValue; // e.g., 0.5 for 50% HP

  const BuffEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.statType,
    required this.value,
    required this.duration,
    required this.targetType,
    this.triggerCondition = BuffTriggerCondition.manual,
    this.triggerValue,
  });

  bool get isDebuff => value < 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'statType': statType?.name,
      'value': value,
      'duration': duration,
      'targetType': targetType.name,
      'triggerCondition': triggerCondition.name,
      'triggerValue': triggerValue,
    };
  }

  factory BuffEntity.fromMap(Map<String, dynamic> map) {
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
      duration: map['duration'] as int? ?? -1,
      targetType: BuffTargetType.values.firstWhere(
        (e) => e.name == (map['targetType'] as String? ?? ''),
        orElse: () => BuffTargetType.allTeammates,
      ),
      triggerCondition: BuffTriggerCondition.values.firstWhere(
        (e) => e.name == (map['triggerCondition'] as String? ?? 'manual'),
        orElse: () => BuffTriggerCondition.manual,
      ),
      triggerValue: (map['triggerValue'] as num?)?.toDouble(),
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
