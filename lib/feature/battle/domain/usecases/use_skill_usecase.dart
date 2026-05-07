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

    // Yeni yol: skill önceden tanımlı bir buff'ı tetikliyorsa, [SkillType]
    // mantığını atla ve buff'ı doğrudan uygula. Hedef ve süre buff'tan gelir.
    if (skill.triggersBuffId != null && skill.triggersBuffId!.isNotEmpty) {
      state = _applyTriggeredBuff(state, heroAfterCost, skill.triggersBuffId!);
      logMsg = "${hero.name}, ${skill.name} kullandı!";
    } else {
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
    }

    final updatedUsedSkillIds = List<String>.from(state.usedSkillIds)..add(skill.id);
    final updatedLogs = List<String>.from(state.battleLogs)..insert(0, logMsg);

    state = state.copyWith(
      usedSkillIds: updatedUsedSkillIds,
      battleLogs: updatedLogs,
    );

    // Olay-bazlı tetik: skill kullanıldı.
    return _handleBuffsUseCase.checkSkillUsedTriggers(state, hero.id);
  }

  /// Skill'in `triggersBuffId` alanına göre `state.allBuffs` içinden buff'ı
  /// bulup hedeflerine uygular. Hedef seçimi buff'ın `targetType`'ına göredir.
  BattleInProgress _applyTriggeredBuff(
    BattleInProgress state,
    HeroCardEntity caster,
    String buffId,
  ) {
    final buffIndex = state.allBuffs.indexWhere((b) => b.id == buffId);
    if (buffIndex == -1) return state; // Buff bulunamazsa sessizce geç.
    final buff = state.allBuffs[buffIndex];

    final isCasterPlayer = state.playerTeam.any((h) => h.id == caster.id);
    final ownTeam = isCasterPlayer ? state.playerTeam : state.enemyTeam;
    final foeTeam = isCasterPlayer ? state.enemyTeam : state.playerTeam;

    List<String> targetIds;
    switch (buff.targetType) {
      case BuffTargetType.self:
        targetIds = [caster.id];
        break;
      case BuffTargetType.singleTeammate:
        // İlk yaşayan, casterdan farklı takım arkadaşı.
        final t = ownTeam.firstWhere(
          (h) => h.isAlive && h.id != caster.id,
          orElse: () => caster, // Yoksa kendine uygula.
        );
        targetIds = [t.id];
        break;
      case BuffTargetType.allTeammates:
        targetIds = ownTeam.where((h) => h.isAlive).map((h) => h.id).toList();
        break;
      case BuffTargetType.singleEnemy:
        final alive = foeTeam.where((h) => h.isAlive).toList();
        if (alive.isEmpty) return state;
        targetIds = [alive.first.id];
        break;
      case BuffTargetType.allEnemies:
        targetIds = foeTeam.where((h) => h.isAlive).map((h) => h.id).toList();
        break;
    }

    BattleInProgress newState = state;
    for (final id in targetIds) {
      newState = _handleBuffsUseCase.applyBuff(newState, buffId, id);
    }
    return newState;
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

      if (!member.isAlive) continue;

      final elementMatch = prerequisite.requiredElements.isEmpty ||
          prerequisite.requiredElements.contains(member.element);
      final roleMatch = prerequisite.requiredRoles.isEmpty ||
          prerequisite.requiredRoles.contains(member.role);
      if (elementMatch && roleMatch) count++;
    }

    return count >= prerequisite.minCount;
  }
}
