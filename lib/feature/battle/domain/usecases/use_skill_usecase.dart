import '../entities/hero_entities.dart';
import '../../presentation/manager/battle_state.dart';

class UseSkillUseCase {
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
    
    // Töz etkisini uygula
    HeroCardEntity updatedHero = hero.copyWith(kut: hero.kut - skill.cost);
    String logMsg = "";
    
    switch (skill.type) {
      case SkillType.heal:
        final newHealth = (updatedHero.health + skill.value).clamp(0, updatedHero.currentCp);
        updatedHero = updatedHero.copyWith(health: newHealth.toInt());
        logMsg = "${hero.name}, ${skill.name} kullandı! ${skill.value} Can yeniledi.";
        break;
      case SkillType.attackBuff:
        updatedHero = updatedHero.copyWith(bonusAttack: updatedHero.bonusAttack + skill.value);
        logMsg = "${hero.name}, ${skill.name} kullandı! Saldırı gücü ${skill.value} arttı.";
        break;
      case SkillType.defenseBuff:
        updatedHero = updatedHero.copyWith(bonusDefense: updatedHero.bonusDefense + skill.value);
        logMsg = "${hero.name}, ${skill.name} kullandı! Savunma gücü ${skill.value} arttı.";
        break;
    }
    
    final updatedPlayerTeam = List<HeroCardEntity>.from(currentState.playerTeam);
    updatedPlayerTeam[heroIndex] = updatedHero;
    
    final updatedUsedSkillIds = List<String>.from(currentState.usedSkillIds)..add(skill.id);
    final updatedLogs = List<String>.from(currentState.battleLogs)..insert(0, logMsg);
    
    return currentState.copyWith(
      playerTeam: updatedPlayerTeam,
      usedSkillIds: updatedUsedSkillIds,
      battleLogs: updatedLogs,
    );
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
