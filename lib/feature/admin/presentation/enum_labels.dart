import '../../battle/domain/entities/buff_entities.dart';
import '../../battle/domain/entities/hero_entities.dart';

/// Tüm admin formlarında kullanılan ortak Türkçe etiketler.
/// `name — açıklama` formatında dropdown gösterimi için.
class EnumLabels {
  static const buffType = <BuffType, String>{
    BuffType.statChange: 'Stat değiştir',
    BuffType.dot: 'Tur sonu hasar (DoT)',
    BuffType.hot: 'Tur sonu iyileşme (HoT)',
    BuffType.damageSoak: 'Hasar emme (% takım arkadaşı)',
  };

  static const statType = <StatType, String>{
    StatType.attack: 'Saldırı',
    StatType.defense: 'Savunma',
    StatType.maxHealth: 'Maks. can',
    StatType.currentHealth: 'Anlık can',
  };

  static const targetType = <BuffTargetType, String>{
    BuffTargetType.self: 'Kendisi',
    BuffTargetType.singleTeammate: 'Tek müttefik',
    BuffTargetType.allTeammates: 'Tüm takım',
    BuffTargetType.singleEnemy: 'Tek düşman',
    BuffTargetType.allEnemies: 'Tüm düşmanlar',
  };

  static const triggerCondition = <BuffTriggerCondition, String>{
    BuffTriggerCondition.manual: 'Elle (skill ile)',
    BuffTriggerCondition.onBattleStart: 'Savaş başında',
    BuffTriggerCondition.onTurnStart: 'Tur başında',
    BuffTriggerCondition.onTurnEnd: 'Tur sonunda',
    BuffTriggerCondition.onHpBelowPercent: 'HP eşik altına düşünce',
    BuffTriggerCondition.onTeammateHpBelowPercent: 'Müttefik HP eşik altına düşünce',
    BuffTriggerCondition.onTeammateDefeated: 'Müttefik bayılınca',
    BuffTriggerCondition.onEnemyDefeated: 'Düşman bayılınca',
    BuffTriggerCondition.onSkillUsed: 'Skill kullanılınca',
    BuffTriggerCondition.onDamageTaken: 'Hasar alınca',
    BuffTriggerCondition.passive: 'Pasif (sürekli)',
  };

  static const prerequisiteType = <BuffPrerequisiteType, String>{
    BuffPrerequisiteType.none: 'Koşul yok',
    BuffPrerequisiteType.heroElementIs: 'Kahramanın elementi',
    BuffPrerequisiteType.heroRoleIs: 'Kahramanın rolü',
    BuffPrerequisiteType.heroIdIs: 'Kahraman ID',
    BuffPrerequisiteType.heroIdIn: 'Kahramanlardan biri (VEYA)',
    BuffPrerequisiteType.hasTeammateWithElement: 'Takımda elementli müttefik',
    BuffPrerequisiteType.hasTeammateWithRole: 'Takımda rollü müttefik',
    BuffPrerequisiteType.hasTeammateWithId: 'Takımda belirli kahraman',
    BuffPrerequisiteType.hasEnemyWithElement: 'Rakipte elementli düşman',
    BuffPrerequisiteType.hasEnemyWithRole: 'Rakipte rollü düşman',
  };

  static const heroElement = <HeroElement, String>{
    HeroElement.fire: 'Ateş',
    HeroElement.dark: 'Karanlık',
    HeroElement.wind: 'Rüzgar',
    HeroElement.steppe: 'Bozkır',
    HeroElement.water: 'Su',
    HeroElement.forest: 'Orman',
  };

  static const heroRole = <HeroRole, String>{
    HeroRole.warrior: 'Savaşçı',
    HeroRole.support: 'Destek',
    HeroRole.mage: 'Büyücü/Lider',
    HeroRole.tank: 'Tank/Savunma',
  };

  static const skillType = <SkillType, String>{
    SkillType.heal: 'İyileştirme',
    SkillType.attackBuff: 'Saldırı arttır',
    SkillType.defenseBuff: 'Savunma arttır',
  };

  /// `name — açıklama` formatında etiket üretir.
  static String fmt<T extends Enum>(T value, Map<T, String> map) {
    final desc = map[value];
    return desc == null ? value.name : '${value.name} — $desc';
  }
}
