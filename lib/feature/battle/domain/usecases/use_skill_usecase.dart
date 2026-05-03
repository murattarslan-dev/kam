import '../entities/hero_entities.dart';
import '../entities/buff_entities.dart';
import '../../presentation/manager/battle_state.dart';
import 'handle_buffs_usecase.dart';

class UseSkillUseCase {
  final HandleBuffsUseCase _handleBuffsUseCase;

  UseSkillUseCase(this._handleBuffsUseCase);

  BattleState execute(BattleInProgress currentState, int heroIndex, SkillEntity skill) {
    // Sıra oyuncuda değilse seçim yapılamaz
    if (!currentState.isPlayerTurn) return currentState;

    // Zaten kullanıldı mı kontrolü
    if (currentState.usedSkillIds.contains(skill.id)) return currentState;

    final hero = currentState.playerTeam[heroIndex];
    if (!hero.isAlive) return currentState;

    // Kut yeterli mi kontrolü
    if (hero.kut < skill.cost) return currentState;

    // Önkoşul kontrolü
    if (!isSkillPrerequisiteMet(currentState, hero, skill)) return currentState;

    // Önce Kut'u düş.
    final heroAfterCost = hero.copyWith(kut: hero.kut - skill.cost);
    final teamAfterCost = List<HeroCardEntity>.from(currentState.playerTeam);
    teamAfterCost[heroIndex] = heroAfterCost;
    BattleInProgress state = currentState.copyWith(playerTeam: teamAfterCost);

    String logMsg;

    switch (skill.type) {
      case SkillType.heal:
        // Anlık etki — buff sistemine gerek yok.
        final newHealth = (heroAfterCost.health + skill.value).clamp(0, heroAfterCost.currentCp);
        final healed = heroAfterCost.copyWith(health: newHealth.toInt());
        final updatedTeam = List<HeroCardEntity>.from(state.playerTeam);
        updatedTeam[heroIndex] = healed;
        state = state.copyWith(playerTeam: updatedTeam);
        logMsg = "${hero.name}, ${skill.name} kullandı! ${skill.value} Can yeniledi.";
        break;
      case SkillType.attackBuff:
        state = _applySkillStatBuff(state, heroAfterCost, skill, StatType.attack);
        logMsg = "${hero.name}, ${skill.name} kullandı! Saldırı gücü ${skill.value} arttı.";
        break;
      case SkillType.defenseBuff:
        state = _applySkillStatBuff(state, heroAfterCost, skill, StatType.defense);
        logMsg = "${hero.name}, ${skill.name} kullandı! Savunma gücü ${skill.value} arttı.";
        break;
    }

    final updatedUsedSkillIds = List<String>.from(state.usedSkillIds)..add(skill.id);
    final updatedLogs = List<String>.from(state.battleLogs)..insert(0, logMsg);

    return state.copyWith(
      usedSkillIds: updatedUsedSkillIds,
      battleLogs: updatedLogs,
    );
  }

  /// Skill kaynaklı stat-buff'ı buff sistemine kanalize eder. Bu sayede
  /// `recalculateAllHeroStats` çağrıldığında bonusAttack/bonusDefense
  /// silinmez; çünkü etki [BattleInProgress.activeBuffs] üzerinden tutulur.
  // TODO: SkillEntity'ye duration alanı eklenince -1 yerine skill.duration kullan.
  BattleInProgress _applySkillStatBuff(
    BattleInProgress state,
    HeroCardEntity hero,
    SkillEntity skill,
    StatType statType,
  ) {
    final syntheticId = 'skill_${skill.id}';

    // Sentetik buff'ı allBuffs'a kaydet (lookup için gerekli).
    List<BuffEntity> allBuffs = state.allBuffs;
    if (!allBuffs.any((b) => b.id == syntheticId)) {
      final synthetic = BuffEntity(
        id: syntheticId,
        name: skill.name,
        description: skill.description,
        type: BuffType.statChange,
        statType: statType,
        value: skill.value,
        duration: -1, // Savaş sonuna kadar
        targetType: BuffTargetType.self,
        triggerCondition: BuffTriggerCondition.manual,
      );
      allBuffs = [...allBuffs, synthetic];
      state = state.copyWith(allBuffs: allBuffs);
    }

    return _handleBuffsUseCase.applyBuff(state, syntheticId, hero.id);
  }

  bool isSkillPrerequisiteMet(BattleInProgress currentState, HeroCardEntity hero, SkillEntity skill) {
    final prerequisite = skill.prerequisite;
    if (prerequisite == null) return true;

    final targetTeam = prerequisite.target == PrerequisiteTarget.teammate
        ? currentState.playerTeam
        : currentState.enemyTeam;

    int count = 0;
    for (var member in targetTeam) {
      if (prerequisite.target == PrerequisiteTarget.teammate && member.id == hero.id) continue;

      if (member.isAlive && prerequisite.requiredElements.contains(member.element)) {
        count++;
      }
    }

    return count >= prerequisite.minCount;
  }
}
