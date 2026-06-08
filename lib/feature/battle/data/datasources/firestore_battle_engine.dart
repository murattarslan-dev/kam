import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/hero_entities.dart';
import '../../domain/entities/buff_entities.dart';
import '../../domain/repository/battle_repository.dart';
import '../../domain/services/bot_ai.dart';
import '../../domain/usecases/use_skill_usecase.dart';
import '../../domain/usecases/swap_hero_usecase.dart';
import '../../domain/usecases/handle_buffs_usecase.dart';
import '../../presentation/manager/battle_state.dart';
import '../mappers/battle_doc_mapper.dart';
import 'battle_engine_datasource.dart';

/// Tek pipeline savaş motoru. Tüm hesap burada yapılır; client yalnız okur.
///
/// İç sözleşme:
/// - State doc'ta nötr (host/guest) tutulur.
/// - Komut işlenirken aktörün perspektifinde [BattleInProgress] kurulur
///   (playerTeam=actorSide, enemyTeam=karşı taraf).
/// - Komut sonrası state geri host/guest alanlarına yazılır.
class FirestoreBattleEngine implements BattleEngineDataSource {
  final FirebaseFirestore _fs;
  final BattleRepository _repo;
  final HandleBuffsUseCase _buffs;
  final UseSkillUseCase _useSkill;
  final SwapHeroUseCase _swap;
  final BotAi _bot;
  final Random _rng = Random();

  // Aynı battle için aynı anda iki bot job'ı çalışmasın.
  final Set<String> _activeBotJobs = {};

  FirestoreBattleEngine({
    FirebaseFirestore? firestore,
    required BattleRepository repository,
    required HandleBuffsUseCase buffs,
    required UseSkillUseCase useSkill,
    required SwapHeroUseCase swap,
    required BotAi bot,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _repo = repository,
        _buffs = buffs,
        _useSkill = useSkill,
        _swap = swap,
        _bot = bot;

  CollectionReference<Map<String, dynamic>> get _col => _fs.collection('battles');

  // ── Oluşturma ────────────────────────────────────────────────────────────

  @override
  Future<String> createPveBattle({
    required String hostId,
    String? hostName,
    required List<HeroCardEntity> playerTeam,
    required List<HeroCardEntity> bench,
  }) async {
    final all = await _repo.fetchAllHeroes();
    if (all.length < 3) {
      throw StateError('Düşman takımı için yeterli kahraman yok');
    }
    final pool = List<HeroCardEntity>.from(all)..shuffle(_rng);
    final enemies = pool.take(3).map((h) {
      return HeroCardEntity.fromMap(
        h.toMap()..['xp'] = 2364,
        skills: h.skillCards,
      );
    }).toList();

    final hostTeam = BattleDocMapper.assignInstanceIds(playerTeam, 'h');
    final hostBench = BattleDocMapper.assignInstanceIds(bench, 'hb');
    final guestTeam = BattleDocMapper.assignInstanceIds(enemies, 'g');

    final allBuffs = await _repo.fetchAllBuffs();

    var st = BattleInProgress(
      playerTeam: hostTeam,
      enemyTeam: guestTeam,
      benchHeroes: hostBench,
      allBuffs: allBuffs,
      isPlayerTurn: true,
      battleLogs: const ['Savaş başladı! Düşman takımı belirlendi.'],
    );
    st = _buffs.checkAutoBuffs(st, BuffTriggerCondition.onBattleStart);
    st = _buffs.checkPassiveBuffs(st);

    final doc = _col.doc();
    await doc.set({
      'mode': 'pve',
      'status': 'in_progress',
      'hostId': hostId,
      'guestId': 'bot',
      'hostName': hostName ?? 'Oyuncu',
      'guestName': 'YZ',
      'hostReady': true,
      'guestReady': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'currentTurn': 1,
      'turnOwner': 'host',
      'seq': 0,
      'actedHeroIds': const <String>[],
      'usedSkillIds': const <String>[],
      'activeBuffs':
          st.activeBuffs.map(BattleDocMapper.activeBuffToDoc).toList(),
      'totalDamageDealt': const <String, dynamic>{},
      'totalDamageReceived': const <String, dynamic>{},
      'battleLogs': st.battleLogs.take(60).toList(),
      'hostTeam': BattleDocMapper.teamToDoc(st.playerTeam),
      'hostBench': BattleDocMapper.teamToDoc(st.benchHeroes),
      'guestTeam': BattleDocMapper.teamToDoc(st.enemyTeam),
      'guestBench': const <Map<String, dynamic>>[],
      'lastAction': null,
      'result': null,
    });
    return doc.id;
  }

  @override
  Future<PvpLobby> createPvpLobby({
    required String hostId,
    String? hostName,
    required List<HeroCardEntity> hostTeam,
    required List<HeroCardEntity> hostBench,
  }) async {
    final assignedTeam = BattleDocMapper.assignInstanceIds(hostTeam, 'h');
    final assignedBench = BattleDocMapper.assignInstanceIds(hostBench, 'hb');
    final doc = _col.doc();
    final code = await _generateUniqueCode();
    await doc.set({
      'mode': 'pvp',
      'status': 'lobby',
      'hostId': hostId,
      'hostName': hostName ?? 'Oyuncu',
      'guestId': null,
      'guestName': null,
      'hostReady': true,
      'guestReady': false,
      'inviteCode': code,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'currentTurn': 1,
      'turnOwner': 'host',
      'seq': 0,
      'actedHeroIds': const <String>[],
      'usedSkillIds': const <String>[],
      'activeBuffs': const <Map<String, dynamic>>[],
      'totalDamageDealt': const <String, dynamic>{},
      'totalDamageReceived': const <String, dynamic>{},
      'battleLogs': const <String>['Rakip bekleniyor...'],
      'hostTeam': BattleDocMapper.teamToDoc(assignedTeam),
      'hostBench': BattleDocMapper.teamToDoc(assignedBench),
      'guestTeam': const <Map<String, dynamic>>[],
      'guestBench': const <Map<String, dynamic>>[],
      'lastAction': null,
      'result': null,
    });
    return PvpLobby(battleId: doc.id, inviteCode: code);
  }

  @override
  Future<String?> findLobbyByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final q = await _col
        .where('inviteCode', isEqualTo: normalized)
        .where('status', isEqualTo: 'lobby')
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.id;
  }

  /// Karışan karakterleri (0,O,1,I,L) hariç tutan 6 haneli kod üretir.
  /// Çakışma durumunda 3 kez yeniden dener (pratikte ~milyarda 1).
  Future<String> _generateUniqueCode() async {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    for (var attempt = 0; attempt < 3; attempt++) {
      final code = List.generate(6, (_) => chars[_rng.nextInt(chars.length)]).join();
      final existing = await findLobbyByCode(code);
      if (existing == null) return code;
    }
    // Son çare: timestamp suffix
    return List.generate(4, (_) => chars[_rng.nextInt(chars.length)]).join() +
        (DateTime.now().millisecondsSinceEpoch % 100).toString().padLeft(2, '0');
  }

  @override
  Future<void> joinPvpLobby({
    required String battleId,
    required String guestId,
    String? guestName,
    required List<HeroCardEntity> guestTeam,
    required List<HeroCardEntity> guestBench,
  }) async {
    final assignedTeam = BattleDocMapper.assignInstanceIds(guestTeam, 'g');
    final assignedBench = BattleDocMapper.assignInstanceIds(guestBench, 'gb');
    final snap = await _col.doc(battleId).get();
    final data = snap.data();
    if (data == null) throw StateError('Lobi bulunamadı');

    final allBuffs = await _repo.fetchAllBuffs();
    final hostTeam = BattleDocMapper.teamFromDoc(data['hostTeam']);
    final hostBench = BattleDocMapper.teamFromDoc(data['hostBench']);

    var st = BattleInProgress(
      playerTeam: hostTeam,
      enemyTeam: assignedTeam,
      benchHeroes: hostBench,
      allBuffs: allBuffs,
      isPlayerTurn: true,
      battleLogs: const ['Savaş başladı! Rakibini yen.'],
    );
    st = _buffs.checkAutoBuffs(st, BuffTriggerCondition.onBattleStart);
    st = _buffs.checkPassiveBuffs(st);

    await _col.doc(battleId).update({
      'status': 'in_progress',
      'updatedAt': FieldValue.serverTimestamp(),
      'guestId': guestId,
      'guestName': guestName ?? 'Rakip',
      'guestReady': true,
      'guestTeam': BattleDocMapper.teamToDoc(st.enemyTeam),
      'guestBench': BattleDocMapper.teamToDoc(assignedBench),
      'hostTeam': BattleDocMapper.teamToDoc(st.playerTeam),
      'hostBench': BattleDocMapper.teamToDoc(st.benchHeroes),
      'activeBuffs':
          st.activeBuffs.map(BattleDocMapper.activeBuffToDoc).toList(),
      'battleLogs': st.battleLogs.take(60).toList(),
    });
  }

  // ── Dinleme ─────────────────────────────────────────────────────────────

  @override
  Stream<Map<String, dynamic>?> watch(String battleId) =>
      _col.doc(battleId).snapshots().map((s) => s.data());

  @override
  Future<Map<String, dynamic>?> get(String battleId) async =>
      (await _col.doc(battleId).get()).data();

  // ── Komutlar ────────────────────────────────────────────────────────────

  @override
  Future<void> submitAttack({
    required String battleId,
    required String mySide,
    required String actorInstanceId,
    required String targetInstanceId,
  }) async {
    final data = await get(battleId);
    if (!_canAct(data, mySide)) return;

    final allBuffs = await _repo.fetchAllBuffs();
    final state = _buildActorState(data!, mySide, allBuffs);

    final attacker =
        state.playerTeam.where((h) => h.id == actorInstanceId).firstOrNull;
    final target =
        state.enemyTeam.where((h) => h.id == targetInstanceId).firstOrNull;
    if (attacker == null || target == null) return;
    if (!attacker.isAlive || !target.isAlive) return;
    if (state.actedHeroIds.contains(attacker.id)) return;

    final actorPlayerName = (mySide == 'host'
            ? data['hostName']
            : data['guestName']) as String? ??
        'Oyuncu';
    final next = _applyAttack(state, attacker, target, actorPlayerName);
    final deltas = _diffHpDeltas(state, next);

    final seq = ((data['seq'] as num?)?.toInt() ?? 0) + 1;
    final lastAction = <String, dynamic>{
      'seq': seq,
      'type': 'attack',
      'actorInstanceId': attacker.id,
      'targetInstanceId': target.id,
      'actorSide': mySide,
      'finalDamage': next.totalDamageDealt[attacker.id]?.toInt() ?? 0,
      'deltas': deltas,
      'message': '${attacker.name} → ${target.name}',
    };

    await _finalizeOrWrite(
      battleId: battleId,
      priorDoc: data,
      next: next,
      actorSide: mySide,
      lastAction: lastAction,
      seq: seq,
    );
    _maybeScheduleBot(battleId, data['mode'] as String?);
  }

  @override
  Future<void> submitSkill({
    required String battleId,
    required String mySide,
    required String actorInstanceId,
    required String skillId,
  }) async {
    final data = await get(battleId);
    if (!_canAct(data, mySide)) return;

    final allBuffs = await _repo.fetchAllBuffs();
    final state = _buildActorState(data!, mySide, allBuffs);
    final idx = state.playerTeam.indexWhere((h) => h.id == actorInstanceId);
    if (idx == -1) return;
    final hero = state.playerTeam[idx];
    final skill = hero.skillCards.where((s) => s.id == skillId).firstOrNull;
    if (skill == null) return;

    final raw = _useSkill.execute(state, idx, skill);
    if (raw is! BattleInProgress) return;
    if (!raw.usedSkillIds.contains(skill.id) ||
        state.usedSkillIds.contains(skill.id)) {
      return; // skill koşulu sağlanmadıysa state değişmedi
    }

    final deltas = _diffHpDeltas(state, raw);
    final seq = ((data['seq'] as num?)?.toInt() ?? 0) + 1;
    final lastAction = <String, dynamic>{
      'seq': seq,
      'type': 'skill',
      'actorInstanceId': hero.id,
      'actorSide': mySide,
      'skillId': skill.id,
      'skillName': skill.name,
      'deltas': deltas,
      'message': '${hero.name} ${skill.name} kullandı',
    };

    await _finalizeOrWrite(
      battleId: battleId,
      priorDoc: data,
      next: raw,
      actorSide: mySide,
      lastAction: lastAction,
      seq: seq,
    );
  }

  @override
  Future<void> submitSwap({
    required String battleId,
    required String mySide,
    required int fieldIndex,
    required int benchIndex,
  }) async {
    final data = await get(battleId);
    if (!_canAct(data, mySide)) return;

    final allBuffs = await _repo.fetchAllBuffs();
    final state = _buildActorState(data!, mySide, allBuffs);

    if (fieldIndex < 0 ||
        fieldIndex >= state.playerTeam.length ||
        benchIndex < 0 ||
        benchIndex >= state.benchHeroes.length) {
      return;
    }
    final outHero = state.playerTeam[fieldIndex];
    final inHero = state.benchHeroes[benchIndex];

    final raw = _swap.execute(state, fieldIndex, benchIndex);
    if (raw is! BattleInProgress) return;

    final seq = ((data['seq'] as num?)?.toInt() ?? 0) + 1;
    final lastAction = <String, dynamic>{
      'seq': seq,
      'type': 'swap',
      'actorInstanceId': inHero.id,
      'targetInstanceId': outHero.id,
      'actorSide': mySide,
      'message': '${outHero.name} ↔ ${inHero.name}',
    };

    await _finalizeOrWrite(
      battleId: battleId,
      priorDoc: data,
      next: raw,
      actorSide: mySide,
      lastAction: lastAction,
      seq: seq,
    );
    _maybeScheduleBot(battleId, data['mode'] as String?);
  }

  @override
  Future<void> abort(String battleId) async {
    try {
      await _col.doc(battleId).update({
        'status': 'aborted',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Future<void> heartbeat({
    required String battleId,
    required String mySide,
  }) async {
    try {
      await _col.doc(battleId).update({
        '${mySide}Heartbeat': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  // ── Saldırı uygulama (engine-içi) ───────────────────────────────────────

  /// [state] actor perspektifinde. [attacker] playerTeam'de, [target] enemyTeam'de.
  /// Hasar + soak + tetikler + tur-sonu kontrolünü uygular; tek normal saldırı.
  BattleInProgress _applyAttack(
    BattleInProgress state,
    HeroCardEntity attacker,
    HeroCardEntity target,
    String actorPlayerName,
  ) {
    final elemMult = attacker.element.getDamageMultiplier(target.element);
    final rawDamage = (attacker.currentAttackPower * elemMult).round();
    final defenseReduction = target.currentDefensePower;
    final preSoakDamage = max(1, rawDamage - defenseReduction);

    final soak = _buffs.calculateDamageSoak(state, target.id, preSoakDamage,
        isPlayerTarget: false);
    final finalDamage = soak.remainingDamage;
    final newHealth = (target.health - finalDamage).clamp(0, target.currentCp);
    final killed = newHealth <= 0;

    final updatedEnemy = state.enemyTeam.map((e) {
      if (e.id != target.id) return e;
      return e.copyWith(health: newHealth.toInt());
    }).toList();

    final updatedPlayer = state.playerTeam.map((p) {
      if (p.id != attacker.id) return p;
      return killed ? p.copyWith(kut: p.kut + 2) : p;
    }).toList();

    final dmgMap = Map<String, double>.from(state.totalDamageDealt);
    dmgMap[attacker.id] = (dmgMap[attacker.id] ?? 0) + finalDamage;
    final recvMap = Map<String, double>.from(state.totalDamageReceived);
    recvMap[target.id] = (recvMap[target.id] ?? 0) + finalDamage;

    final acted = [...state.actedHeroIds, attacker.id];

    final logLine = _buildAttackLog(
      actorPlayerName: actorPlayerName,
      attacker: attacker,
      target: target,
      elemMult: elemMult,
      rawDamage: rawDamage,
      preSoakDamage: preSoakDamage,
      finalDamage: finalDamage,
      soakers: soak.soakers,
      allHeroes: [...state.playerTeam, ...state.enemyTeam, ...state.benchHeroes],
      newHealth: newHealth.toInt(),
      killed: killed,
    );

    BattleInProgress next = state.copyWith(
      playerTeam: updatedPlayer,
      enemyTeam: updatedEnemy,
      totalDamageDealt: dmgMap,
      totalDamageReceived: recvMap,
      actedHeroIds: acted,
      battleLogs: [logLine, ...state.battleLogs],
    );

    if (soak.hasSoak) {
      next = _buffs.applySoakDamage(next, soak.soakers);
    }

    next = _buffs.checkDamageTakenTriggers(next, target.id);
    if (killed) next = _buffs.checkDefeatTriggers(next, target.id);
    next = _buffs.checkHpTriggers(next);

    // Tur sonu kontrolü: aktör takımının yaşayan herkesi hamle yaptı mı?
    final aliveActors = next.playerTeam.where((p) => p.isAlive).length;
    if (acted.length >= aliveActors) {
      next = _buffs.checkAutoBuffs(next, BuffTriggerCondition.onTurnEnd);
      next = next.copyWith(isPlayerTurn: false);
    }
    return next;
  }

  // ── Ortak yazma yolu ────────────────────────────────────────────────────

  /// Saldırı için ayrıntılı, çok satırlı log üretir.
  String _buildAttackLog({
    required String actorPlayerName,
    required HeroCardEntity attacker,
    required HeroCardEntity target,
    required double elemMult,
    required int rawDamage,
    required int preSoakDamage,
    required int finalDamage,
    required List soakers,
    required List<HeroCardEntity> allHeroes,
    required int newHealth,
    required bool killed,
  }) {
    String fmtBonus(int v) {
      if (v == 0) return '';
      return v > 0 ? ' +$v(buff)' : ' $v(debuff)';
    }

    String elemArrow() {
      if (elemMult > 1.0) return ' ↑${elemMult.toStringAsFixed(1)}× üstün';
      if (elemMult < 1.0) return ' ↓${elemMult.toStringAsFixed(1)}× zayıf';
      return ' =${elemMult.toStringAsFixed(1)}× nötr';
    }

    final atkPart =
        'Atak ${attacker.attackPower}${fmtBonus(attacker.bonusAttack)} '
        '× element${elemArrow()} = $rawDamage';
    final defPart =
        'Savunma ${target.defensePower}${fmtBonus(target.bonusDefense)} '
        '→ Net $preSoakDamage hasar';

    final lines = <String>[
      '[$actorPlayerName] ${attacker.name} → ${target.name}',
      atkPart,
      defPart,
    ];

    if (soakers.isNotEmpty) {
      final shared = soakers
          .map((s) {
            final name = allHeroes
                .where((h) => h.id == s.heroId)
                .map((h) => h.name)
                .firstOrNull;
            return '${name ?? "?"}: ${s.amount}';
          })
          .join(', ');
      lines.add('Tank emdi: $shared → ${target.name} alan hasar: $finalDamage');
    }

    lines.add('${target.name} HP ${target.health} → $newHealth');
    if (killed) lines.add('${attacker.name} +2 Kut kazandı');

    return lines.join('\n');
  }

  /// HP delta diff'i — sahnedeki ve yedek tüm kahramanlar için.
  Map<String, int> _diffHpDeltas(BattleInProgress before, BattleInProgress after) {
    final out = <String, int>{};
    void diff(List<HeroCardEntity> b, List<HeroCardEntity> a) {
      final byId = {for (final h in b) h.id: h};
      for (final h in a) {
        final old = byId[h.id];
        if (old == null) continue;
        final d = h.health - old.health;
        if (d != 0) out[h.id] = d;
      }
    }
    diff(before.playerTeam, after.playerTeam);
    diff(before.enemyTeam, after.enemyTeam);
    diff(before.benchHeroes, after.benchHeroes);
    return out;
  }

  bool _canAct(Map<String, dynamic>? data, String mySide) {
    if (data == null) return false;
    if (data['status'] != 'in_progress') return false;
    if (data['turnOwner'] != mySide) return false;
    return true;
  }

  BattleInProgress _buildActorState(
    Map<String, dynamic> data,
    String mySide,
    List<BuffEntity> allBuffs,
  ) {
    return BattleDocMapper.buildPerspective(
      doc: data,
      mySide: mySide,
      allBuffs: allBuffs,
      battleId: 'engine',
    ).copyWith(clearAction: true);
  }

  /// Komut sonucunu yaz: tur biti / kazanma kontrolü dahil.
  Future<void> _finalizeOrWrite({
    required String battleId,
    required Map<String, dynamic> priorDoc,
    required BattleInProgress next,
    required String actorSide,
    required Map<String, dynamic> lastAction,
    required int seq,
  }) async {
    BattleInProgress current = next;
    String newTurnOwner = actorSide;

    // Aktörün turu bittiyse, post-turn bloğunu çalıştır + sırayı çevir.
    if (!current.isPlayerTurn) {
      current = _buffs.processTurnEnd(current);
      current = _buffs.checkHpTriggers(current);
      current = _buffs.checkAutoBuffs(current, BuffTriggerCondition.onTurnStart);
      current = _buffs.checkPassiveBuffs(current);
      final updatedNewOwner = current.enemyTeam
          .map((p) => p.isAlive ? p.copyWith(kut: p.kut + 1) : p)
          .toList();
      current = current.copyWith(
        enemyTeam: updatedNewOwner,
        currentTurn: current.currentTurn + 1,
        actedHeroIds: const [],
      );
      newTurnOwner = actorSide == 'host' ? 'guest' : 'host';
    }

    // Kazanma / kaybetme kontrolü
    String? winnerSide;
    if (current.enemyTeam.every((e) => !e.isAlive)) {
      winnerSide = actorSide;
    } else if (current.playerTeam.every((p) => !p.isAlive)) {
      winnerSide = actorSide == 'host' ? 'guest' : 'host';
    }

    if (winnerSide != null) {
      await _writeFinished(
        battleId: battleId,
        priorDoc: priorDoc,
        finalState: current,
        actorSide: actorSide,
        winnerSide: winnerSide,
        lastAction: lastAction,
        seq: seq,
      );
      return;
    }

    final patch = _patchForState(
      priorDoc: priorDoc,
      next: current,
      actorSide: actorSide,
    );
    patch['updatedAt'] = FieldValue.serverTimestamp();
    patch['turnOwner'] = newTurnOwner;
    patch['lastAction'] = lastAction;
    patch['seq'] = seq;

    final ref = _col.doc(battleId);
    final batch = _fs.batch();
    batch.update(ref, patch);
    batch.set(ref.collection('events').doc(), _eventDoc(seq, current.currentTurn, actorSide, lastAction));
    await batch.commit();
  }

  Map<String, dynamic> _eventDoc(
    int seq,
    int turn,
    String actorSide,
    Map<String, dynamic> lastAction,
  ) {
    return {
      'seq': seq,
      'turn': turn,
      'side': actorSide == 'host' ? 'player' : 'enemy',
      'type': lastAction['type'],
      'message': lastAction['message'],
      'actor': {'instanceId': lastAction['actorInstanceId']},
      if (lastAction['targetInstanceId'] != null)
        'target': {'instanceId': lastAction['targetInstanceId']},
      if (lastAction['skillId'] != null)
        'skill': {'id': lastAction['skillId'], 'name': lastAction['skillName']},
      if (lastAction['finalDamage'] != null)
        'damage': {'finalDamage': lastAction['finalDamage']},
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _patchForState({
    required Map<String, dynamic> priorDoc,
    required BattleInProgress next,
    required String actorSide,
  }) {
    final isHostActor = actorSide == 'host';
    final newHostTeam = isHostActor ? next.playerTeam : next.enemyTeam;
    final newGuestTeam = isHostActor ? next.enemyTeam : next.playerTeam;
    final newHostBench = isHostActor
        ? next.benchHeroes
        : BattleDocMapper.teamFromDoc(priorDoc['hostBench']);
    final newGuestBench = isHostActor
        ? BattleDocMapper.teamFromDoc(priorDoc['guestBench'])
        : next.benchHeroes;

    return {
      'currentTurn': next.currentTurn,
      'actedHeroIds': next.actedHeroIds,
      'usedSkillIds': next.usedSkillIds,
      'activeBuffs':
          next.activeBuffs.map(BattleDocMapper.activeBuffToDoc).toList(),
      'totalDamageDealt': next.totalDamageDealt,
      'totalDamageReceived': next.totalDamageReceived,
      'battleLogs': next.battleLogs.take(60).toList(),
      'hostTeam': BattleDocMapper.teamToDoc(newHostTeam),
      'guestTeam': BattleDocMapper.teamToDoc(newGuestTeam),
      'hostBench': BattleDocMapper.teamToDoc(newHostBench),
      'guestBench': BattleDocMapper.teamToDoc(newGuestBench),
    };
  }

  Future<void> _writeFinished({
    required String battleId,
    required Map<String, dynamic> priorDoc,
    required BattleInProgress finalState,
    required String actorSide,
    required String winnerSide,
    required Map<String, dynamic> lastAction,
    required int seq,
  }) async {
    final patch = _patchForState(
      priorDoc: priorDoc,
      next: finalState,
      actorSide: actorSide,
    );

    final hostTeam = BattleDocMapper.teamFromDoc(patch['hostTeam']);
    final guestTeam = BattleDocMapper.teamFromDoc(patch['guestTeam']);
    final hostBench = BattleDocMapper.teamFromDoc(patch['hostBench']);
    final guestBench = BattleDocMapper.teamFromDoc(patch['guestBench']);

    Map<String, double> asDoubleMap(dynamic raw) {
      final out = <String, double>{};
      if (raw is Map) raw.forEach((k, v) => out[k.toString()] = (v as num).toDouble());
      return out;
    }

    final dealt = asDoubleMap(patch['totalDamageDealt']);
    final received = asDoubleMap(patch['totalDamageReceived']);

    final hostBenchIds = hostBench.map((h) => h.id).toSet();
    final guestBenchIds = guestBench.map((h) => h.id).toSet();

    int xpFor(HeroCardEntity h, bool isWinner) {
      final dmg = (dealt[h.id] ?? 0).round();
      return dmg + (isWinner ? 300 : 0);
    }

    final heroStats = <Map<String, dynamic>>[];
    for (final h in [...hostTeam, ...hostBench]) {
      heroStats.add({
        'instanceId': h.id,
        'name': h.name,
        'side': 'host',
        'isBench': hostBenchIds.contains(h.id),
        'damageDealt': (dealt[h.id] ?? 0).round(),
        'damageReceived': (received[h.id] ?? 0).round(),
        'xpGained': xpFor(h, winnerSide == 'host'),
        if (h.userHeroDocId.isNotEmpty) 'userHeroDocId': h.userHeroDocId,
      });
    }
    for (final h in [...guestTeam, ...guestBench]) {
      heroStats.add({
        'instanceId': h.id,
        'name': h.name,
        'side': 'guest',
        'isBench': guestBenchIds.contains(h.id),
        'damageDealt': (dealt[h.id] ?? 0).round(),
        'damageReceived': (received[h.id] ?? 0).round(),
        'xpGained': xpFor(h, winnerSide == 'guest'),
        if (h.userHeroDocId.isNotEmpty) 'userHeroDocId': h.userHeroDocId,
      });
    }

    final message = winnerSide == 'host'
        ? 'ZAFER! Karanlık ordu bozguna uğratıldı.'
        : 'MAĞLUBİYET... Kut elimizden kayıp gitti.';
    const rewards = <String>['100 Altın', 'Kadim Ruh Parçası'];

    patch['updatedAt'] = FieldValue.serverTimestamp();
    patch['turnOwner'] = actorSide;
    patch['lastAction'] = lastAction;
    patch['seq'] = seq;
    patch['status'] = 'finished';
    patch['result'] = {
      'winnerSide': winnerSide,
      'isHostVictory': winnerSide == 'host',
      'message': message,
      'rewards': rewards,
      'heroStats': heroStats,
      'finishedAt': FieldValue.serverTimestamp(),
    };

    final ref = _col.doc(battleId);
    final batch = _fs.batch();
    batch.update(ref, patch);
    batch.set(ref.collection('events').doc(), {
      'seq': seq,
      'turn': finalState.currentTurn,
      'side': 'system',
      'type': 'battle_end',
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    await _grantXp(heroStats);
  }

  /// Kazanan/kaybeden tarafa göre kullanıcının kahramanlarına XP yansıt.
  Future<void> _grantXp(List<Map<String, dynamic>> heroStats) async {
    final user = _repo.currentUser;
    if (user == null) return;
    for (final s in heroStats) {
      final docId = s['userHeroDocId'] as String?;
      if (docId == null || docId.isEmpty) continue;
      final gain = (s['xpGained'] as num?)?.toInt() ?? 0;
      if (gain <= 0) continue;
      try {
        await _repo.updateHeroXp(user.uid, docId, gain);
      } catch (_) {/* gözardı */}
    }
  }

  void _maybeScheduleBot(String battleId, String? mode) {
    if (mode != 'pve') return;
    if (_activeBotJobs.contains(battleId)) return;
    _activeBotJobs.add(battleId);
    Future<void>(() async {
      try {
        await _runBotLoop(battleId);
      } finally {
        _activeBotJobs.remove(battleId);
      }
    });
  }

  Future<void> _runBotLoop(String battleId) async {
    while (true) {
      await Future.delayed(const Duration(milliseconds: 1500));
      final data = await get(battleId);
      if (data == null) return;
      if (data['status'] != 'in_progress') return;
      if (data['mode'] != 'pve') return;
      if (data['turnOwner'] != 'guest') return;

      final allBuffs = await _repo.fetchAllBuffs();
      final st = _buildActorState(data, 'guest', allBuffs);
      final move = _bot.nextMove(st);
      if (move == null) return;

      await submitAttack(
        battleId: battleId,
        mySide: 'guest',
        actorInstanceId: move.actorInstanceId,
        targetInstanceId: move.targetInstanceId,
      );
    }
  }
}
