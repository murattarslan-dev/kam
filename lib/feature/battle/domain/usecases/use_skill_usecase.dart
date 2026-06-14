import '../entities/hero_entities.dart';
import '../entities/buff_entities.dart';
import '../../presentation/manager/battle_state.dart';
import 'handle_buffs_usecase.dart';

/// Bir kahramanın sahip olduğu bir Töz'ü (buff referansı) tetiklemek için
/// merkezi kullanım noktası.
///
/// `useSkill` adı UI/Engine tarafında korunmuş olabilir; davranış tamamen
/// buff sistemi üzerinden yürür: maliyet, kullanım koşulu ve etki buff
/// dokümanından okunur, hedef seçimi `buff.targetType`'a göre yapılır.
class UseTozUseCase {
  final HandleBuffsUseCase _handleBuffsUseCase;

  UseTozUseCase(this._handleBuffsUseCase);

  /// [buffId] kahramanın `tozler` listesinde olmalı.
  BattleState execute(BattleInProgress currentState, int heroIndex, String buffId) {
    if (!currentState.isPlayerTurn) return currentState;

    final hero = currentState.playerTeam[heroIndex];
    if (!hero.isAlive) return currentState;
    if (!hero.tozler.contains(buffId)) return currentState;

    // Buff zaten kullanıldı mı? (per-hero × per-buff once-per-battle)
    final alreadyUsed =
        (currentState.usedTozIdsByHero[hero.id] ?? const []).contains(buffId);
    if (alreadyUsed) return currentState;

    final buff = currentState.allBuffs.where((b) => b.id == buffId).firstOrNull;
    if (buff == null) return currentState;

    // Sadece manuel tetiklemeyle çalışan buff'lar Töz olabilir.
    if (!buff.isManual) return currentState;

    // Kut maliyeti.
    final cost = buff.cost ?? 0;
    if (hero.kut < cost) return currentState;

    // Kullanım koşulu (takım kompozisyonu üzerinden).
    if (!isUsable(currentState, hero, buff)) return currentState;

    // 1) Kut'u düş.
    final heroAfterCost = hero.copyWith(kut: hero.kut - cost);
    final teamAfterCost = List<HeroCardEntity>.from(currentState.playerTeam);
    teamAfterCost[heroIndex] = heroAfterCost;
    BattleInProgress state = currentState.copyWith(playerTeam: teamAfterCost);

    // 2) Buff'ı uygula.
    state = _applyTozBuff(state, heroAfterCost, buff);

    // 3) Log üret.
    final actor = currentState.playerName ?? 'Sen';
    final header =
        "[$actor] TÖZ · ${hero.name} → ${buff.name} (-$cost Kut, kalan ${heroAfterCost.kut})";
    final detail = buff.description;
    final updatedLogs = List<String>.from(state.battleLogs)..insert(0, "$header\n$detail");

    // 4) Kullanım listesine ekle.
    final updatedUsed = Map<String, List<String>>.from(state.usedTozIdsByHero);
    final heroList = List<String>.from(updatedUsed[hero.id] ?? const [])..add(buffId);
    updatedUsed[hero.id] = heroList;

    state = state.copyWith(
      usedTozIdsByHero: updatedUsed,
      battleLogs: updatedLogs,
    );

    // 5) Olay-bazlı tetik: skill kullanıldı.
    return _handleBuffsUseCase.checkSkillUsedTriggers(state, hero.id);
  }

  /// Buff'ın `targetType`'ına göre hedefleri belirleyip `applyBuff` çağırır.
  BattleInProgress _applyTozBuff(
    BattleInProgress state,
    HeroCardEntity caster,
    BuffEntity buff,
  ) {
    final isCasterPlayer = state.playerTeam.any((h) => h.id == caster.id);
    final ownTeam = isCasterPlayer ? state.playerTeam : state.enemyTeam;
    final foeTeam = isCasterPlayer ? state.enemyTeam : state.playerTeam;

    List<String> targetIds;
    switch (buff.targetType) {
      case BuffTargetType.self:
        targetIds = [caster.id];
        break;
      case BuffTargetType.singleTeammate:
        final t = ownTeam.firstWhere(
          (h) => h.isAlive && h.id != caster.id,
          orElse: () => caster,
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
      newState = _handleBuffsUseCase.applyBuff(newState, buff.id, id);
    }
    return newState;
  }

  /// Kullanım koşulu (`buff.useRequirements`) takım kompozisyonu üzerinden
  /// değerlendirilir. UI buton aktiflik kararı için bunu çağırır.
  bool isUsable(BattleInProgress state, HeroCardEntity hero, BuffEntity buff) {
    if (buff.useRequirements.isEmpty) return true;
    final isPlayer = state.playerTeam.any((h) => h.id == hero.id);
    return buff.useRequirements
        .every((p) => _isUseReqMet(state, hero, isPlayer, p));
  }

  bool _isUseReqMet(
    BattleInProgress state,
    HeroCardEntity hero,
    bool isPlayer,
    BuffPrerequisite p,
  ) {
    switch (p.type) {
      case BuffPrerequisiteType.none:
        return true;
      case BuffPrerequisiteType.heroElementIs:
        return hero.element.name == p.value;
      case BuffPrerequisiteType.heroRoleIs:
        return hero.role.name == p.value;
      case BuffPrerequisiteType.heroIdIs:
        return hero.id == p.value;
      case BuffPrerequisiteType.heroHpBelowPercent:
        final pct = double.tryParse(p.value);
        if (pct == null || hero.currentCp <= 0) return false;
        return (hero.health / hero.currentCp) * 100 <= pct;
      case BuffPrerequisiteType.heroIdIn:
        return p.value
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .contains(hero.id);
      case BuffPrerequisiteType.hasTeammateWithElement:
        final team = isPlayer ? state.playerTeam : state.enemyTeam;
        return team.any((h) => h.id != hero.id && h.isAlive && h.element.name == p.value);
      case BuffPrerequisiteType.hasTeammateWithRole:
        final team = isPlayer ? state.playerTeam : state.enemyTeam;
        return team.any((h) => h.id != hero.id && h.isAlive && h.role.name == p.value);
      case BuffPrerequisiteType.hasTeammateWithId:
        final team = isPlayer ? state.playerTeam : state.enemyTeam;
        return team.any((h) => h.id != hero.id && h.isAlive && h.id == p.value);
      case BuffPrerequisiteType.hasEnemyWithElement:
        final opp = isPlayer ? state.enemyTeam : state.playerTeam;
        return opp.any((h) => h.isAlive && h.element.name == p.value);
      case BuffPrerequisiteType.hasEnemyWithRole:
        final opp = isPlayer ? state.enemyTeam : state.playerTeam;
        return opp.any((h) => h.isAlive && h.role.name == p.value);
    }
  }
}
