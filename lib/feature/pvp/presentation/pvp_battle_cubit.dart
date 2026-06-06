import 'dart:async';
import '../../battle/presentation/manager/battle_cubit_base.dart';
import '../../battle/presentation/manager/battle_state.dart';
import '../../battle/domain/entities/hero_entities.dart';
import '../../battle/domain/entities/buff_entities.dart';
import '../../battle/domain/repository/battle_repository.dart';
import '../../battle/domain/usecases/select_hero_usecase.dart';
import '../../battle/domain/usecases/execute_player_attack_usecase.dart';
import '../../battle/domain/usecases/apply_player_attack_usecase.dart';
import '../../battle/domain/usecases/use_skill_usecase.dart';
import '../../battle/domain/usecases/swap_hero_usecase.dart';
import '../../battle/domain/usecases/handle_buffs_usecase.dart';
import '../data/match_service.dart';
import '../data/match_mapper.dart';
import '../../battle/domain/usecases/log_battle_event_usecase.dart';

/// PvP savaş yöneticisi. Mevcut PvE savaş motorunu (usecase'ler) yeniden
/// kullanır ama düşman AI'ı (ExecuteEnemyTurnUseCase) ÇAĞIRMAZ; rakip hamleleri
/// Firestore stream'inden gelir.
///
/// Yetkili (authoritative) tam-durum senkronu: sırası gelen oyuncu hamlesini
/// lokal motorla hesaplar, ardından her iki takımın tam anlık görüntüsünü
/// matches/{id} dokümanına yazar. Rakip istemci durumu okuyup kendi
/// perspektifinden (kendi tarafı = playerTeam) yeniden kurar.
class PvpBattleCubit extends BattleCubitBase {
  final MatchService _svc;
  final BattleRepository _repo;
  final SelectHeroUseCase _selectHero;
  final ExecutePlayerAttackUseCase _executeAttack;
  final ApplyPlayerAttackUseCase _applyAttack;
  final UseSkillUseCase _useSkill;
  final SwapHeroUseCase _swapHero;
  final HandleBuffsUseCase _handleBuffs;
  final LogBattleEventUseCase _log;

  PvpBattleCubit(
    this._svc,
    this._repo,
    this._selectHero,
    this._executeAttack,
    this._applyAttack,
    this._useSkill,
    this._swapHero,
    this._handleBuffs,
    this._log,
  ) : super(const BattleLoading());

  late String _matchId;
  late String _myId;
  String? _mySide; // 'host' | 'guest'
  List<BuffEntity> _allBuffs = const [];

  StreamSubscription<Map<String, dynamic>?>? _sub;
  Timer? _heartbeat;

  bool _hostInitDone = false;
  int _currentTurnNumber = 0;
  int _appliedTurn = -1; // doc'tan uygulanmış (veya kendi yazdığımız) son tur

  String get _otherSide => _mySide == 'host' ? 'guest' : 'host';
  bool get _isHost => _mySide == 'host';

  Future<void> start(String matchId, String myId) async {
    _matchId = matchId;
    _myId = myId;
    try {
      _allBuffs = await _repo.fetchAllBuffs();
    } catch (_) {
      _allBuffs = const [];
    }
    _sub = _svc.watch(matchId).listen(_onSnapshot);
    _heartbeat = Timer.periodic(const Duration(seconds: 8), (_) => _writeHeartbeat());
  }

  // ── Snapshot işleme ────────────────────────────────────────────────────────

  void _onSnapshot(Map<String, dynamic>? data) {
    if (data == null || isClosed) return;

    final hostId = data['hostId'] as String?;
    final guestId = data['guestId'] as String?;
    if (_myId == hostId) {
      _mySide = 'host';
    } else if (_myId == guestId) {
      _mySide = 'guest';
    }
    if (_mySide == null) return; // henüz taraf belli değil

    final status = data['status'] as String?;
    if (status == 'aborted') {
      emit(const BattleError('Rakip oyundan ayrıldı. Maç iptal edildi.'));
      return;
    }
    if (status == 'finished') {
      emit(_buildResult(data));
      return;
    }

    // Rakip terk kontrolü (heartbeat bayatladıysa)
    if (_isOpponentStale(data)) {
      _svc.abort(_matchId);
      return;
    }

    final live = data['live'] == true;
    if (!live) {
      // Host yalnızca her iki taraf da hazır olduğunda (in_progress) savaşı
      // başlatır; lobby aşamasında guest takımı henüz null olduğundan beklenir.
      if (_isHost && !_hostInitDone && status == 'in_progress') {
        _hostInit(data);
      } else {
        final guestId = data['guestId'] as String?;
        final message = guestId == null
            ? 'Rakip bekleniyor...'
            : 'Rakip hazır oluyor...';
        emit(BattleLoading(message: message));
      }
      return;
    }

    final turn = (data['turnNumber'] as num?)?.toInt() ?? 0;
    if (turn <= _appliedTurn) return; // kendi echo'muz ya da heartbeat-yazımı

    _appliedTurn = turn;
    _currentTurnNumber = turn;
    final st = _buildFromDoc(data);
    // Rakip hamlesini görmek için önce emit et (animasyon tetiklensin)
    emit(st);
    // Eğer rakip hamlesiyse, kısa bir delay sonra animasyonu temizle
    // (bu otomatik onAnimationComplete tetiklemez, fakat state güncel kalır)
    if (st.currentAction != null && !st.currentAction!.isPlayerAttacking) {
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!isClosed && state == st) {
          emit(st.copyWith(currentAction: null));
        }
      });
    }
  }

  /// Host, savaş in_progress'e geçtiğinde ilk yetkili durumu üretir:
  /// onBattleStart + passive buff'ları uygular ve canlı durumu yazar.
  void _hostInit(Map<String, dynamic> data) {
    _hostInitDone = true;
    final host = MatchMapper.teamFromList(data['hostTeam'], 'h:');
    final guest = MatchMapper.teamFromList(data['guestTeam'], 'g:');
    final hostBench = MatchMapper.teamFromList(data['hostBench'], 'hb:');

    var st = BattleInProgress(
      playerTeam: host,
      enemyTeam: guest,
      benchHeroes: hostBench,
      allBuffs: _allBuffs,
      isPlayerTurn: true,
      battleLogs: const ['Savaş başladı! Rakibini yen.'],
    );
    st = _handleBuffs.checkAutoBuffs(st, BuffTriggerCondition.onBattleStart);
    st = _handleBuffs.checkPassiveBuffs(st);

    _currentTurnNumber = 0; // _pushLive ++ ile 1 olacak
    emit(st);
    _pushLive(st);
  }

  BattleInProgress _buildFromDoc(Map<String, dynamic> data) {
    final host = MatchMapper.teamFromList(data['hostTeam'], 'h:');
    final guest = MatchMapper.teamFromList(data['guestTeam'], 'g:');
    final hostBench = MatchMapper.teamFromList(data['hostBench'], 'hb:');
    final guestBench = MatchMapper.teamFromList(data['guestBench'], 'gb:');

    final activeBuffs = (data['activeBuffs'] as List<dynamic>? ?? [])
        .map((b) => ActiveBuff.fromMap(Map<String, dynamic>.from(b as Map)))
        .toList();
    final tdd = <String, double>{};
    (data['totalDamageDealt'] as Map<dynamic, dynamic>? ?? {}).forEach((k, v) {
      tdd[k as String] = (v as num).toDouble();
    });

    // Rakip hamlesini canlı olarak render et (lastAction varsa)
    BattleAction? currentAction;
    final lastActionData = data['lastAction'] as Map<dynamic, dynamic>?;
    if (lastActionData != null) {
      final actorInstanceId = lastActionData['actorInstanceId'] as String?;
      final targetInstanceId = lastActionData['targetInstanceId'] as String?;
      final allTeams = [...host, ...guest, ...hostBench, ...guestBench];
      final actor = allTeams.where((h) => h.id == actorInstanceId).firstOrNull;
      final target = allTeams.where((h) => h.id == targetInstanceId).firstOrNull;
      if (actor != null && target != null) {
        // Kendi perspektifimizden: rakip saldırırsa, bu "player attacking" (bizim ekranımızdan gözüküyor)
        final actorIsHost = actor.id.startsWith('h') || actor.id.startsWith('hb');
        currentAction = BattleAction(
          attacker: actor,
          target: target,
          isPlayerAttacking: actorIsHost == _isHost, // aynı tarafsa playerAttacking
        );
      }
    }

    final st = BattleInProgress(
      playerTeam: _isHost ? host : guest,
      enemyTeam: _isHost ? guest : host,
      benchHeroes: _isHost ? hostBench : guestBench,
      allBuffs: _allBuffs,
      activeBuffs: activeBuffs,
      isPlayerTurn: data['turnOwner'] == _mySide,
      currentTurn: (data['displayTurn'] as num?)?.toInt() ?? 1,
      totalDamageDealt: tdd,
      battleLogs: (data['battleLogs'] as List<dynamic>? ?? const ['Savaş başladı!'])
          .map((e) => e.toString())
          .toList(),
      currentAction: currentAction,
    );
    return _handleBuffs.recalculateAllHeroStats(st);
  }

  BattleResult _buildResult(Map<String, dynamic> data) {
    final winnerSide = (data['result'] as Map<dynamic, dynamic>?)?['winnerSide'];
    final isVictory = winnerSide == _mySide;
    final host = MatchMapper.teamFromList(data['hostTeam'], 'h:');
    final guest = MatchMapper.teamFromList(data['guestTeam'], 'g:');
    final hostBench = MatchMapper.teamFromList(data['hostBench'], 'hb:');
    final guestBench = MatchMapper.teamFromList(data['guestBench'], 'gb:');
    final tdd = <String, double>{};
    (data['totalDamageDealt'] as Map<dynamic, dynamic>? ?? {}).forEach((k, v) {
      tdd[k as String] = (v as num).toDouble();
    });

    return BattleResult(
      message: isVictory
          ? 'Rakip ordusunu bozguna uğrattın!'
          : 'Rakip seni alt etti.',
      isVictory: isVictory,
      playerTeam: _isHost ? host : guest,
      benchHeroes: _isHost ? hostBench : guestBench,
      totalDamageDealt: tdd,
      allBuffs: _allBuffs,
    );
  }

  // ── Yazma ──────────────────────────────────────────────────────────────────

  void _pushLive(BattleInProgress st, {bool finished = false, String? winnerSide}) {
    final myField = _isHost ? 'host' : 'guest';
    final oppField = _isHost ? 'guest' : 'host';
    final newTurn = ++_currentTurnNumber;
    _appliedTurn = newTurn;

    final payload = <String, dynamic>{
      'live': true,
      'turnNumber': newTurn,
      'turnOwner': st.isPlayerTurn ? _mySide : _otherSide,
      'displayTurn': st.currentTurn,
      'activeBuffs': st.activeBuffs.map((b) => b.toMap()).toList(),
      'battleLogs': st.battleLogs.take(60).toList(),
      'totalDamageDealt': st.totalDamageDealt,
      'status': finished ? 'finished' : 'in_progress',
      '${myField}Team': MatchMapper.teamToList(st.playerTeam),
      '${myField}Bench': MatchMapper.teamToList(st.benchHeroes),
      '${oppField}Team': MatchMapper.teamToList(st.enemyTeam),
    };
    // Rakip oyuncu canlı olarak animasyonu görebilsin diye hamleyi yaz
    if (st.currentAction != null) {
      payload['lastAction'] = {
        'actorInstanceId': st.currentAction!.attacker.id,
        'targetInstanceId': st.currentAction!.target.id,
      };
    }
    if (finished) payload['result'] = {'winnerSide': winnerSide};
    _svc.push(_matchId, payload);
  }

  void _writeHeartbeat() {
    if (isClosed || _mySide == null) return;
    final field = _isHost ? 'hostHeartbeat' : 'guestHeartbeat';
    _svc.push(_matchId, {field: DateTime.now().millisecondsSinceEpoch});
  }

  bool _isOpponentStale(Map<String, dynamic> data) {
    final field = _isHost ? 'guestHeartbeat' : 'hostHeartbeat';
    final last = (data[field] as num?)?.toInt();
    if (last == null) return false; // rakip henüz heartbeat yazmadı
    return DateTime.now().millisecondsSinceEpoch - last > 30000;
  }

  // ── BattleCubitBase API ─────────────────────────────────────────────────────

  @override
  void selectHero(int index, bool isEnemy) {
    final s = state;
    if (s is! BattleInProgress) return;
    final next = _selectHero.execute(s, index, isEnemy);
    if (next is BattleInProgress) emit(next);
  }

  @override
  void executePlayerAttack() {
    final s = state;
    if (s is! BattleInProgress) return;
    if (!s.isPlayerTurn) return;
    final next = _executeAttack.execute(s);
    if (next is BattleInProgress) emit(next);
  }

  @override
  void onAnimationComplete() {
    final s = state;
    if (s is! BattleInProgress) return;
    final action = s.currentAction;
    if (action == null) return;

    if (action.isPlayerAttacking) {
      // Kendi saldırımız: hasar uygula ve gönder
      final next = _applyAttack.execute(s, action);
      if (next is BattleInProgress) {
        emit(next);
        _pushLive(next);
      } else if (next is BattleResult) {
        final deadEnemies = s.enemyTeam.map((e) => e.copyWith(health: 0)).toList();
        final synthetic = BattleInProgress(
          playerTeam: next.playerTeam,
          enemyTeam: deadEnemies,
          benchHeroes: next.benchHeroes,
          allBuffs: _allBuffs,
          activeBuffs: next.activeBuffs,
          totalDamageDealt: next.totalDamageDealt,
          isPlayerTurn: false,
          currentTurn: s.currentTurn,
          battleLogs: ['Zafer! ${next.message}', ...s.battleLogs],
        );
        emit(next);
      _pushLive(synthetic, finished: true, winnerSide: _mySide);
      }
    } else {
      // Rakip saldırısı: animasyon bitince currentAction'ı kaldır
      emit(s.copyWith(currentAction: null));
    }
  }

  @override
  void swapHero(int fieldIndex, int benchIndex) {
    final s = state;
    if (s is! BattleInProgress) return;
    if (!s.isPlayerTurn) return;
    final next = _swapHero.execute(s, fieldIndex, benchIndex);
    if (next is BattleInProgress) {
      emit(next);
      _pushLive(next);
    }
  }

  @override
  void useSkill(int heroIndex, SkillEntity skill) {
    final s = state;
    if (s is! BattleInProgress) return;
    if (!s.isPlayerTurn) return;
    final before = s;
    final next = _useSkill.execute(s, heroIndex, skill);
    if (next is BattleInProgress &&
        next.usedSkillIds.contains(skill.id) &&
        !before.usedSkillIds.contains(skill.id)) {
      emit(next);
      _pushLive(next);
    } else if (next is BattleInProgress) {
      emit(next);
    }
  }

  @override
  bool isSkillPrerequisiteMet(HeroCardEntity hero, SkillEntity skill) {
    final s = state;
    if (s is! BattleInProgress) return false;
    return _useSkill.isSkillPrerequisiteMet(s, hero, skill);
  }

  @override
  Future<void> close() {
    _heartbeat?.cancel();
    _sub?.cancel();
    return super.close();
  }
}
