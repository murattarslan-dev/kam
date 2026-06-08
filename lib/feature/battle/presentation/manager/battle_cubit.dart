import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  int _lastAnimatedSeq = -1;
  int? _selectedHeroIndex;
  int? _selectedTargetIndex;

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

    // Taraf belirleme (lobide host/guest atanmadan oturup beklenebilir).
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
      return;
    }

    final status = data['status'] as String?;
    if (status == 'lobby') {
      emit(const BattleLoading(message: 'Rakip bekleniyor...'));
      _ensureHeartbeat();
      return;
    }
    if (status == 'aborted') {
      emit(const BattleError('Savaş iptal edildi.'));
      return;
    }
    if (status == 'finished') {
      final r = BattleDocMapper.buildResult(
        doc: data,
        mySide: _mySide,
        allBuffs: _allBuffs,
      );
      emit(r);
      _stopHeartbeat();
      return;
    }
    if (status != 'in_progress') return;

    _ensureHeartbeat();

    final seq = (data['seq'] as num?)?.toInt() ?? 0;
    var st = BattleDocMapper.buildPerspective(
      doc: data,
      mySide: _mySide,
      allBuffs: _allBuffs,
      battleId: _battleId,
    );
    // Animasyon yalnız yeni seq için tetiklenir.
    if (seq <= _lastAnimatedSeq) {
      st = st.copyWith(clearAction: true);
    } else if (st.currentAction != null) {
      _lastAnimatedSeq = seq;
    }
    // Yerel seçim durumunu yeniden bindir.
    st = _withLocalSelection(st);
    emit(st);
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
    emit(s.copyWith(clearAction: true));
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
