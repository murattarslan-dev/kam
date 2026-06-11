import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/di/injection.dart';
import '../../data/datasources/battle_engine_datasource.dart';
import '../../data/mappers/battle_doc_mapper.dart';
import '../../domain/entities/buff_entities.dart';
import '../../domain/entities/hero_entities.dart';
import '../../domain/repository/battle_repository.dart';
import '../../domain/usecases/use_skill_usecase.dart';
import 'battle_state.dart';

/// Tek savaş cubit'i. PvE / PvP fark etmez.
///
/// Cubit ince bir köprüdür:
/// - UI'dan gelen intent'i (saldır, skill, swap) engine'e iletir.
/// - Engine'in Firestore yazımları snapshot stream'i üzerinden geri akar.
/// - Burada yalnız perspektif (mySide) ve UI-yerel seçim durumu tutulur.
class BattleCubit extends Cubit<BattleState> {
  final BattleEngineDataSource _engine;
  final BattleRepository _repo;
  final UseSkillUseCase _useSkillUseCase;

  BattleCubit(this._engine, this._repo, this._useSkillUseCase)
      : super(const BattleInitial());

  String _battleId = '';
  String _myId = '';
  String _mySide = '';
  String _mode = '';
  List<BuffEntity> _allBuffs = const [];

  int _lastEmittedSeq = -1;
  int? _selectedHeroIndex;
  int? _selectedTargetIndex;

  // Animasyon kuyruğu: animasyon oynarken gelen snapshot'lar burada bekler.
  final List<Map<String, dynamic>> _pending = [];
  bool _animating = false;

  StreamSubscription<Map<String, dynamic>?>? _sub;
  Timer? _heartbeat;

  // ── Açılış ─────────────────────────────────────────────────────────────

  /// PvE: yeni bir bot savaşı yarat ve dinlemeye başla.
  Future<void> startPveBattle({
    required String myId,
    List<HeroCardEntity>? playerTeam,
    List<HeroCardEntity>? benchHeroes,
  }) async {
    emit(const BattleLoading(message: 'Savaş hazırlanıyor...'));
    _myId = myId;
    _mySide = 'host';
    try {
      _allBuffs = await _repo.fetchAllBuffs();
      List<HeroCardEntity> team = playerTeam ?? const [];
      List<HeroCardEntity> bench = benchHeroes ?? const [];
      if (team.isEmpty) {
        // Takım hazırlama atlandıysa fallback: kullanıcının kahramanlarından ilk 3
        final all = await _repo.fetchUserHeroes(myId);
        if (all.isEmpty) {
          emit(const BattleError('Kullanıcıya ait kahraman bulunamadı'));
          return;
        }
        team = all.take(3).toList();
        bench = all.length > 3 ? all.sublist(3) : const [];
      }
      _battleId = await _engine.createPveBattle(
        hostId: myId,
        hostName: sl<AuthService>().displayName,
        playerTeam: team,
        bench: bench,
      );
      _mode = 'pve';
      _startWatch();
    } catch (e) {
      emit(BattleError('Savaş başlatılamadı: $e'));
    }
  }

  /// Var olan bir savaşa (PvP lobi/PvP maç/PvE devam) bağlan.
  Future<void> openExistingBattle(String battleId, String myId) async {
    emit(const BattleLoading(message: 'Savaş yükleniyor...'));
    _battleId = battleId;
    _myId = myId;
    try {
      _allBuffs = await _repo.fetchAllBuffs();
      _startWatch();
    } catch (e) {
      emit(BattleError('Savaş açılamadı: $e'));
    }
  }

  void _startWatch() {
    _sub?.cancel();
    _sub = _engine.watch(_battleId).listen(_onSnapshot);
  }

  void _onSnapshot(Map<String, dynamic>? data) {
    if (data == null || isClosed) return;

    // Animasyon oynuyorsa snapshot'ı kuyruğa al. status==finished/aborted gibi
    // kritik geçişler de kuyruğa girer ki sıra bozulmasın.
    if (_animating) {
      _pending.add(data);
      return;
    }
    _process(data);
  }

  void _process(Map<String, dynamic> data) {
    if (isClosed) return;

    // Taraf belirleme.
    _mode = (data['mode'] as String?) ?? _mode;
    final hostId = data['hostId'] as String?;
    final guestId = data['guestId'] as String?;
    if (_myId == hostId) {
      _mySide = 'host';
    } else if (_myId == guestId) {
      _mySide = 'guest';
    }
    if (_mySide.isEmpty) {
      emit(const BattleLoading(message: 'Tarafın atanması bekleniyor...'));
      _drainPending();
      return;
    }

    final status = data['status'] as String?;
    if (status == 'lobby') {
      emit(const BattleLoading(message: 'Rakip bekleniyor...'));
      _ensureHeartbeat();
      _drainPending();
      return;
    }
    if (status == 'aborted') {
      emit(const BattleError('Savaş iptal edildi.'));
      return;
    }
    if (status == 'finished') {
      // Sadece kendi tarafımıza XP yansıt (idempotent, engine guard'lı).
      _engine.grantOwnSideXp(battleId: _battleId, mySide: _mySide);
      _stopHeartbeat();
      _sub?.cancel();
      _sub = null;
      emit(BattleFinished(battleId: _battleId, mySide: _mySide));
      return;
    }
    if (status != 'in_progress') {
      _drainPending();
      return;
    }

    _ensureHeartbeat();

    final seq = (data['seq'] as num?)?.toInt() ?? 0;
    var st = BattleDocMapper.buildPerspective(
      doc: data,
      mySide: _mySide,
      allBuffs: _allBuffs,
      battleId: _battleId,
    );

    // Aynı seq tekrar gelirse (heartbeat vb.) animasyon/floating tekrar oynamasın.
    final isFreshAction = seq > _lastEmittedSeq;
    if (!isFreshAction) {
      st = st.copyWith(clearAction: true, clearFloatingDeltas: true);
    } else {
      _lastEmittedSeq = seq;
    }

    st = _withLocalSelection(st);
    emit(st);

    // Yeni saldırı animasyonu varsa kuyruğa geç; yoksa floating animasyonu
    // kısa sürede biteceğinden bir sonraki snapshot'ı hemen işle.
    if (isFreshAction && st.currentAction != null) {
      _animating = true; // attack animation in progress
    } else if (isFreshAction && st.floatingDeltas.isNotEmpty) {
      // Sadece floating var (skill heal vb.) — kart üstünde 1.2 sn oynayacak.
      _animating = true;
      Future.delayed(const Duration(milliseconds: 1200), _finishAnimation);
    } else {
      _drainPending();
    }
  }

  void _finishAnimation() {
    if (isClosed) return;
    _animating = false;
    _drainPending();
  }

  void _drainPending() {
    if (_pending.isEmpty) return;
    final next = _pending.removeAt(0);
    _process(next);
  }

  BattleInProgress _withLocalSelection(BattleInProgress st) {
    var out = st;
    if (_selectedHeroIndex == null) {
      out = out.copyWith(clearSelection: true);
    } else {
      // Seçili hero hâlâ playerTeam'de mi? (swap sonrası kayabilir.)
      if (_selectedHeroIndex! >= out.playerTeam.length) {
        _selectedHeroIndex = null;
        out = out.copyWith(clearSelection: true);
      } else {
        out = out.copyWith(selectedHeroIndex: _selectedHeroIndex);
        if (_selectedTargetIndex == null) {
          out = out.copyWith(clearTarget: true);
        } else if (_selectedTargetIndex! >= out.enemyTeam.length) {
          _selectedTargetIndex = null;
          out = out.copyWith(clearTarget: true);
        } else {
          out = out.copyWith(selectedTargetIndex: _selectedTargetIndex);
        }
      }
    }
    return out;
  }

  // ── UI intent'leri ─────────────────────────────────────────────────────

  void selectHero(int index, bool isEnemy) {
    final s = state;
    if (s is! BattleInProgress) return;
    if (!s.isPlayerTurn) return;
    if (isEnemy) {
      if (_selectedHeroIndex == null) return;
      if (!s.enemyTeam[index].isAlive) return;
      _selectedTargetIndex = _selectedTargetIndex == index ? null : index;
    } else {
      final hero = s.playerTeam[index];
      if (!hero.isAlive || s.actedHeroIds.contains(hero.id)) return;
      if (_selectedHeroIndex == index) {
        _selectedHeroIndex = null;
        _selectedTargetIndex = null;
      } else {
        _selectedHeroIndex = index;
        _selectedTargetIndex = null;
      }
    }
    emit(_withLocalSelection(s));
  }

  void executePlayerAttack() {
    final s = state;
    if (s is! BattleInProgress) return;
    if (!s.isPlayerTurn) return;
    final hIdx = _selectedHeroIndex;
    final tIdx = _selectedTargetIndex;
    if (hIdx == null || tIdx == null) return;
    final attacker = s.playerTeam[hIdx];
    final target = s.enemyTeam[tIdx];
    _selectedHeroIndex = null;
    _selectedTargetIndex = null;
    _engine.submitAttack(
      battleId: _battleId,
      mySide: _mySide,
      actorInstanceId: attacker.id,
      targetInstanceId: target.id,
    );
  }

  void onAnimationComplete() {
    final s = state;
    if (s is! BattleInProgress) return;
    if (s.currentAction == null) return;
    // Saldırı animasyonu bitti. currentAction'ı temizleyip floating sayıları
    // bırakıyoruz; floating widget'ı 1.2 sn oynayacak, ardından sıradakine.
    emit(s.copyWith(clearAction: true));
    Future.delayed(const Duration(milliseconds: 1200), _finishAnimation);
  }

  void swapHero(int fieldIndex, int benchIndex) {
    final s = state;
    if (s is! BattleInProgress) return;
    if (!s.isPlayerTurn) return;
    _selectedHeroIndex = null;
    _selectedTargetIndex = null;
    _engine.submitSwap(
      battleId: _battleId,
      mySide: _mySide,
      fieldIndex: fieldIndex,
      benchIndex: benchIndex,
    );
  }

  void useSkill(int heroIndex, SkillEntity skill) {
    final s = state;
    if (s is! BattleInProgress) return;
    if (!s.isPlayerTurn) return;
    final hero = s.playerTeam[heroIndex];
    _engine.submitSkill(
      battleId: _battleId,
      mySide: _mySide,
      actorInstanceId: hero.id,
      skillId: skill.id,
    );
  }

  bool isSkillPrerequisiteMet(HeroCardEntity hero, SkillEntity skill) {
    final s = state;
    if (s is! BattleInProgress) return false;
    return _useSkillUseCase.isSkillPrerequisiteMet(s, hero, skill);
  }

  // ── Heartbeat (sadece PvP'de anlamlı) ──────────────────────────────────

  void _ensureHeartbeat() {
    if (_mode != 'pvp' || _heartbeat != null || _mySide.isEmpty) return;
    _heartbeat = Timer.periodic(const Duration(seconds: 8), (_) {
      _engine.heartbeat(battleId: _battleId, mySide: _mySide);
    });
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  @override
  Future<void> close() {
    _stopHeartbeat();
    _sub?.cancel();
    return super.close();
  }
}
