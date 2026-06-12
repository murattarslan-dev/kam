import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/hero_entities.dart';
import '../../domain/entities/arena_entities.dart';
import '../../domain/repository/battle_repository.dart';
import '../../domain/usecases/fetch_user_heroes_usecase.dart';
import '../widgets/card_widget.dart';
import '../widgets/hero_detail_dialog.dart';
import 'package:kam/core/auth/auth_service.dart';
import 'package:kam/core/di/injection.dart';
import 'package:kam/core/util/responsive_helper.dart';
import 'package:kam/core/util/player_id.dart';
import 'package:kam/feature/battle/data/datasources/battle_engine_datasource.dart';

class TeamSetupScreen extends StatefulWidget {
  /// Davet linkiyle gelindiğinde dolu olur (`?match=<id>`); bu durumda oyuncu
  /// guest olarak katılır ve maça yönlendirilir.
  final String? inviteMatchId;

  const TeamSetupScreen({super.key, this.inviteMatchId});

  @override
  State<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends State<TeamSetupScreen> {
  bool _isLoading = true;
  String? _error;
  List<HeroCardEntity> _allHeroes = [];
  List<ArenaEntity> _arenas = const [];
  ArenaEntity? _selectedArena;

  // 5 yuva: 0-1-2 as takımı, 3-4 yedek kadro
  final List<HeroCardEntity?> _slots = List.filled(5, null);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final heroes = await sl<FetchUserHeroesUseCase>().execute();
      final arenas = await sl<BattleRepository>().fetchAllArenas();
      arenas.sort((a, b) => a.name.compareTo(b.name));

      // Guest: host'un seçtiği arenayı lobi dokümanından oku ve kilitli göster.
      ArenaEntity? initialArena = arenas.isNotEmpty ? arenas.first : null;
      final mid = widget.inviteMatchId;
      if (mid != null) {
        final lobby = await sl<BattleEngineDataSource>().get(mid);
        final hostArenaId = lobby?['arenaId'] as String?;
        if (hostArenaId != null) {
          final match =
              arenas.where((a) => a.id == hostArenaId).firstOrNull;
          if (match != null) initialArena = match;
        }
      }

      if (!mounted) return;
      setState(() {
        _allHeroes = heroes;
        _arenas = arenas;
        _selectedArena = initialArena;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Veriler yüklenemedi: $e';
        _isLoading = false;
      });
    }
  }

  Set<String> get _heroIdsInSlots =>
      _slots.whereType<HeroCardEntity>().map((h) => h.id).toSet();

  List<HeroCardEntity> get _availableHeroes =>
      _allHeroes.where((h) => !_heroIdsInSlots.contains(h.id)).toList();

  bool get _allSlotsFull => _slots.every((s) => s != null);

  bool get _canStart => _slots.sublist(0, 3).any((s) => s != null);

  void _tapAvailableHero(HeroCardEntity hero) {
    final nextEmpty = _slots.indexWhere((s) => s == null);
    if (nextEmpty == -1) return;
    setState(() => _slots[nextEmpty] = hero);
  }

  void _removeFromSlot(int index) {
    setState(() => _slots[index] = null);
  }

  void _swapSlots(int from, int to) {
    if (from == to) return;
    setState(() {
      final temp = _slots[from];
      _slots[from] = _slots[to];
      _slots[to] = temp;
    });
  }

  bool get _isGuest => widget.inviteMatchId != null;
  bool _busy = false;

  ({List<HeroCardEntity> team, List<HeroCardEntity> bench})? _collectTeam() {
    final team = _slots.sublist(0, 3).whereType<HeroCardEntity>().toList();
    if (team.isEmpty) return null;
    final bench = _slots.sublist(3, 5).whereType<HeroCardEntity>().toList();
    return (team: team, bench: bench);
  }

  void _startBattle() {
    final picked = _collectTeam();
    if (picked == null) return;
    context.go('/battle', extra: {
      'playerTeam': picked.team,
      'benchHeroes': picked.bench,
      'arenaId': _selectedArena?.id,
    });
  }

  /// Host: yeni maç lobisi açar ve paylaşılabilir davet kodunu gösterir.
  Future<void> _invite() async {
    final picked = _collectTeam();
    if (picked == null || _busy) return;
    setState(() => _busy = true);
    try {
      final lobby = await sl<BattleEngineDataSource>().createPvpLobby(
        hostId: getPlayerId(),
        hostName: sl<AuthService>().displayName,
        hostTeam: picked.team,
        hostBench: picked.bench,
        arenaId: _selectedArena?.id,
      );
      if (!mounted) return;
      await _showInviteDialog(lobby.inviteCode, lobby.battleId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maç oluşturulamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Davet kodu ile gelen ikinci oyuncu maça katılır ve savaşa geçer.
  Future<void> _joinAsGuest() async {
    final picked = _collectTeam();
    final matchId = widget.inviteMatchId;
    if (picked == null || matchId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await sl<BattleEngineDataSource>().joinPvpLobby(
        battleId: matchId,
        guestId: getPlayerId(),
        guestName: sl<AuthService>().displayName,
        guestTeam: picked.team,
        guestBench: picked.bench,
      );
      if (!mounted) return;
      context.go('/battle?match=$matchId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maça katılınamadı: $e')),
        );
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showInviteDialog(String code, String matchId) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Davet Kodu',
            style: TextStyle(color: Colors.tealAccent, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Bu kodu rakibine ver. O ana ekrandaki "Oyuna Katıl"a tıklayıp kodu girdiğinde savaş başlar.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (dContext.mounted) {
                  ScaffoldMessenger.of(dContext).showSnackBar(
                    const SnackBar(content: Text('Kod kopyalandı')),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 16, color: Colors.tealAccent),
              label: const Text('Kodu Kopyala',
                  style: TextStyle(color: Colors.tealAccent)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dContext),
            child: const Text('İPTAL'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
            onPressed: () {
              Navigator.pop(dContext);
              context.go('/battle?match=$matchId');
            },
            icon: const Icon(Icons.login, size: 16, color: Colors.black),
            label: const Text('LOBİYE GEÇ',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── kart genişliğini ekran genişliğinden hesapla ─────────────────────────
  // 3 kart yan yana, 12px yatay padding, kartın kendi 4px marjini dahil
  double _cardWidth(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    // As takımı 3 yuva yan yana — mobilde min 70, tablette üst sınır artar.
    final cols = 3;
    final available = screenW - 32; // sayfa kenar boşlukları
    final raw = (available / cols) - 8; // kart marjını çıkar
    final maxW = context.responsive<double>(120, tablet: 140, desktop: 160);
    final minW = context.isSmallPhone ? 64.0 : 72.0;
    return raw.clamp(minW, maxW);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
              fontFamily: 'Serif',
            ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF020617),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.deepPurple))
              : _error != null
                  ? _buildError()
                  : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadAll();
              },
              child: const Text('TEKRAR DENE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final cardW = _cardWidth(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildSlotGroup(
                  label: 'AS TAKIM',
                  accentColor: Colors.tealAccent,
                  indices: const [0, 1, 2],
                  cardWidth: cardW,
                ),
                const SizedBox(height: 6),
                _buildSlotGroup(
                  label: 'YEDEK KADRO',
                  accentColor: Colors.orangeAccent,
                  indices: const [3, 4],
                  cardWidth: cardW,
                ),
                const SizedBox(height: 10),
                _buildArenaPicker(),
                const Divider(color: Colors.white10, height: 1),
                _buildAvailableSection(),
              ],
            ),
          ),
        ),
        _buildConfirmBar(),
      ],
    );
  }

  // ── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.pagePadding + 4, 12, context.pagePadding + 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TAKIM HAZIRLA',
            style: TextStyle(
              color: Colors.white,
              fontSize: context.titleFont,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tıkla → ekle/çıkar  ·  Sürükle → sırala  ·  ℹ️ veya uzun bas → detay',
            style: TextStyle(color: Colors.white38, fontSize: context.labelFont - 1),
          ),
        ],
      ),
    );
  }

  // ── SLOT GRUBU ────────────────────────────────────────────────────────────

  Widget _buildSlotGroup({
    required String label,
    required Color accentColor,
    required List<int> indices,
    required double cardWidth,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              Expanded(
                child: Divider(
                  color: accentColor.withValues(alpha: 0.3),
                  indent: 8,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: indices
                .map((i) => _buildSlotCell(i, accentColor, cardWidth))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotCell(int index, Color accentColor, double cardWidth) {
    final hero = _slots[index];

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => _swapSlots(details.data, index),
      builder: (_, candidateData, __) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHovered
                  ? Colors.white
                  : (hero != null
                      ? accentColor.withValues(alpha: 0.5)
                      : Colors.transparent),
              width: isHovered ? 2 : 1,
            ),
            color: isHovered
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: hero != null
              ? _buildFilledSlot(index, hero, cardWidth)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEmptySlot(index, cardWidth),
                    const SizedBox(height: 22), // stats strip ile hizalama
                  ],
                ),
        );
      },
    );
  }

  Widget _buildFilledSlot(int index, HeroCardEntity hero, double cardWidth) {
    return Draggable<int>(
      data: index,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: KamCardWidget(
            card: hero,
            isSelected: false,
            isEnemy: false,
            onTap: () {},
            overrideWidth: cardWidth,
          ),
        ),
      ),
      childWhenDragging: _buildEmptySlot(index, cardWidth, isDragging: true),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onLongPress: () => HeroDetailDialog.show(context, hero),
                child: KamCardWidget(
                  card: hero,
                  isSelected: false,
                  isEnemy: false,
                  onTap: () => _removeFromSlot(index),
                  overrideWidth: cardWidth,
                ),
              ),
              Positioned(
                top: 14,
                right: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _removeFromSlot(index),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child:
                        const Icon(Icons.close, size: 11, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 6,
                child: _infoButton(hero),
              ),
            ],
          ),
          _buildStatsStrip(hero, cardWidth),
        ],
      ),
    );
  }

  Widget _infoButton(HeroCardEntity hero) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => HeroDetailDialog.show(context, hero),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.7)),
        ),
        child: const Icon(Icons.info_outline,
            size: 12, color: Colors.tealAccent),
      ),
    );
  }

  /// Kartın altında ATK/DEF/CP/Lv kompakt göstergesi + XP barı.
  Widget _buildStatsStrip(HeroCardEntity hero, double cardWidth) {
    return SizedBox(
      width: cardWidth + 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniStat(
                    Icons.flash_on, '${hero.currentAttackPower}', Colors.orangeAccent),
                _miniStat(
                    Icons.security, '${hero.currentDefensePower}', Colors.blueAccent),
                _miniStat(
                    Icons.favorite, '${hero.currentCp}', Colors.redAccent),
                _miniStat(Icons.star, '${hero.level}', Colors.purpleAccent),
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: hero.xpProgress,
                minHeight: 2,
                backgroundColor: Colors.white12,
                color: Colors.purpleAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 9, color: color),
        const SizedBox(width: 1),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptySlot(int index, double cardWidth,
      {bool isDragging = false}) {
    final isMain = index < 3;
    final cardH = cardWidth * 1.6;
    return SizedBox(
      width: cardWidth + 8, // kart marjını hesaba kat
      height: cardH + 16,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline,
              color: isDragging
                  ? Colors.white38
                  : (isMain
                      ? Colors.tealAccent.withValues(alpha: 0.25)
                      : Colors.orangeAccent.withValues(alpha: 0.25)),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              isMain ? 'AS ${index + 1}' : 'YDK ${index - 2}',
              style: TextStyle(
                color: isDragging ? Colors.white38 : Colors.white24,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ARENA SEÇİCİ ──────────────────────────────────────────────────────────

  Widget _buildArenaPicker() {
    if (_arenas.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: context.pagePadding, vertical: 8),
        child: const Text(
          'Arena yok — admin panelinden eklenebilir.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(
              children: [
                Text(
                  _isGuest ? 'ARENA (EV SAHİBİ SEÇTİ)' : 'ARENA',
                  style: const TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                if (_isGuest) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.lock_outline,
                      size: 12, color: Colors.lightBlueAccent),
                ],
                Expanded(
                  child: Divider(
                    color: Colors.lightBlueAccent.withValues(alpha: 0.3),
                    indent: 8,
                  ),
                ),
                if (_selectedArena != null)
                  Text(
                    _selectedArena!.name,
                    style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 96,
            child: Builder(
              builder: (_) {
                // Guest: yalnız host'un seçtiği arenayı göster, taplanmaz.
                final list = _isGuest && _selectedArena != null
                    ? <ArenaEntity>[_selectedArena!]
                    : _arenas;
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _buildArenaTile(list[i]),
                );
              },
            ),
          ),
          if (_selectedArena != null)
            Padding(
              padding: EdgeInsets.fromLTRB(context.pagePadding, 6, context.pagePadding, 0),
              child: _buildArenaEffectsBar(_selectedArena!),
            ),
        ],
      ),
    );
  }

  Widget _buildArenaTile(ArenaEntity arena) {
    final isSelected = _selectedArena?.id == arena.id;
    return GestureDetector(
      onTap: _isGuest ? null : () => setState(() => _selectedArena = arena),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.lightBlueAccent
                : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (arena.thumbnailUrl.isNotEmpty)
                Image.network(
                  arena.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.black54),
                )
              else
                Container(color: Colors.black54),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Text(
                  arena.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.lightBlueAccent : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArenaEffectsBar(ArenaEntity arena) {
    final entries = arena.elementEffects.entries
        .where((e) => e.value != 1.0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return const Text(
        'Tüm elementler nötr',
        style: TextStyle(color: Colors.white38, fontSize: 10),
      );
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: entries.map((e) {
        final isBuff = e.value > 1.0;
        final color = isBuff ? Colors.tealAccent : Colors.redAccent;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            '${_elementEmoji(e.key)} ${e.value.toStringAsFixed(2)}x',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _elementEmoji(HeroElement element) => switch (element) {
        HeroElement.fire => '🔥',
        HeroElement.water => '💧',
        HeroElement.wind => '🌬️',
        HeroElement.steppe => '🌾',
        HeroElement.forest => '🌲',
        HeroElement.dark => '🌑',
      };

  // ── AVAILABLE HEROES ──────────────────────────────────────────────────────

  Widget _buildAvailableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              const Text(
                'KAHRAMANLAR',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_availableHeroes.length} seçilebilir',
                style:
                    const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ),
        _buildHeroGrid(),
      ],
    );
  }

  Widget _buildHeroGrid() {
    if (_availableHeroes.isEmpty && _allHeroes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('Kahraman bulunamadı',
              style: TextStyle(color: Colors.white24, fontSize: 13)),
        ),
      );
    }
    if (_availableHeroes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('Tüm kahramanlar yerleştirildi ✓',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.isSmallPhone
            ? 2
            : context.responsive<int>(3, tablet: 4, desktop: 5),
        childAspectRatio: 1 / 1.95, // kart + stat strip için pay
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
      ),
      itemCount: _availableHeroes.length,
      itemBuilder: (_, index) {
        final hero = _availableHeroes[index];
        final blocked = _allSlotsFull;
        return LayoutBuilder(
          builder: (ctx, constraints) {
            // Hücre genişliğinden kart iç marjını çıkar
            final w = (constraints.maxWidth - 8).clamp(60.0, 200.0);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    GestureDetector(
                      onLongPress: () =>
                          HeroDetailDialog.show(context, hero),
                      child: KamCardWidget(
                        card: hero,
                        isSelected: false,
                        isEnemy: false,
                        onTap: blocked ? () {} : () => _tapAvailableHero(hero),
                        overrideWidth: w,
                      ),
                    ),
                    Positioned(
                      top: 14,
                      left: 10,
                      child: _infoButton(hero),
                    ),
                    if (blocked)
                      Positioned.fill(
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text('DOLU',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                          ),
                        ),
                      ),
                  ],
                ),
                _buildStatsStrip(hero, w),
              ],
            );
          },
        );
      },
    );
  }

  // ── CONFIRM BAR ───────────────────────────────────────────────────────────

  Widget _buildConfirmBar() {
    final mainCount =
        _slots.sublist(0, 3).whereType<HeroCardEntity>().length;
    final benchCount =
        _slots.sublist(3, 5).whereType<HeroCardEntity>().length;

    return Container(
      padding: EdgeInsets.fromLTRB(context.pagePadding + 4, 10, context.pagePadding + 4, 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$mainCount/3 as  ·  $benchCount/2 yedek',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (!_canStart)
                const Text(
                  'En az 1 as kahraman seç',
                  style:
                      TextStyle(color: Colors.redAccent, fontSize: 10),
                ),
            ],
          ),
          const Spacer(),
          if (_isGuest)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _canStart && !_busy ? 1.0 : 0.4,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _canStart && !_busy ? _joinAsGuest : null,
                icon: _busy
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.login, color: Colors.black, size: 16),
                label: const Text(
                  'MAÇA KATIL',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 12),
                ),
              ),
            )
          else ...[
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _canStart && !_busy ? 1.0 : 0.4,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.tealAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _canStart && !_busy ? _invite : null,
                icon: _busy
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent))
                    : const Icon(Icons.group_add, color: Colors.tealAccent, size: 16),
                label: const Text(
                  'DAVET ET',
                  style: TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _canStart ? 1.0 : 0.4,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _canStart ? _startBattle : null,
                icon: const Icon(Icons.flash_on, color: Colors.white, size: 16),
                label: const Text(
                  'SAVAŞA BAŞLA',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
