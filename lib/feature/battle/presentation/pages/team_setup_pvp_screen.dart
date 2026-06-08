import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/hero_entities.dart';
import '../../domain/usecases/fetch_user_heroes_usecase.dart';
import '../widgets/card_widget.dart';
import 'package:kam/core/di/injection.dart';
import 'package:kam/core/util/responsive_helper.dart';
import 'package:kam/core/util/player_id.dart';
import 'package:kam/feature/battle/data/datasources/battle_engine_datasource.dart';

class TeamSetupPvpScreen extends StatefulWidget {
  /// Davet linkiyle gelindiğinde dolu olur (`?match=<id>`); bu durumda oyuncu
  /// guest olarak katılır ve maça yönlendirilir.
  final String? inviteMatchId;

  const TeamSetupPvpScreen({super.key, this.inviteMatchId});

  @override
  State<TeamSetupPvpScreen> createState() => _TeamSetupPvpScreenState();
}

class _TeamSetupPvpScreenState extends State<TeamSetupPvpScreen> {
  bool _isLoading = true;
  String? _error;
  List<HeroCardEntity> _allHeroes = [];
  final List<HeroCardEntity?> _slots = List.filled(5, null);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadHeroes();
  }

  Future<void> _loadHeroes() async {
    try {
      final heroes = await sl<FetchUserHeroesUseCase>().execute();
      if (!mounted) return;
      // PvP'de kahramanları 1-5 arası rastgele seviye + full HP ile hazırla
      final random = Random();
      final boostedHeroes = heroes.map((h) {
        final randomLevel = 1 + random.nextInt(5); // 1-5
        final xpForLevel = (randomLevel - 1) * 1000;
        final levelMultiplier = 1 + randomLevel * 0.1;
        final maxHp = (h.cp * levelMultiplier).round();
        // cp'yi currentCp = (cp * levelMultiplier) = maxHp olacak şekilde ayarla
        final baseCP = (maxHp / levelMultiplier).round();
        return h.copyWith(
          xp: xpForLevel,
          health: maxHp, // full HP
          cp: baseCP,
        );
      }).toList();
      setState(() {
        _allHeroes = boostedHeroes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Kahramanlar yüklenemedi: $e';
        _isLoading = false;
      });
    }
  }

  bool get _isGuest => widget.inviteMatchId != null;

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

  Future<void> _invite() async {
    final team = _slots.sublist(0, 3).whereType<HeroCardEntity>().toList();
    if (team.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final bench = _slots.sublist(3, 5).whereType<HeroCardEntity>().toList();
      final matchId = await sl<BattleEngineDataSource>().createPvpLobby(
        hostId: getPlayerId(),
        hostTeam: team,
        hostBench: bench,
      );
      if (!mounted) return;
      final base = Uri.base.removeFragment();
      final link = '$base#/team-setup-pvp?match=$matchId';
      await _showInviteDialog(link, matchId);
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

  Future<void> _joinAsGuest() async {
    final matchId = widget.inviteMatchId;
    if (matchId == null) return;
    final team = _slots.sublist(0, 3).whereType<HeroCardEntity>().toList();
    if (team.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final bench = _slots.sublist(3, 5).whereType<HeroCardEntity>().toList();
      await sl<BattleEngineDataSource>().joinPvpLobby(
        battleId: matchId,
        guestId: getPlayerId(),
        guestTeam: team,
        guestBench: bench,
      );
      if (!mounted) return;
      context.go('/pvp-battle?match=$matchId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maça katılınamadı: $e')),
        );
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showInviteDialog(String link, String matchId) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Rakip Davet Et',
            style: TextStyle(color: Colors.tealAccent, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bu linki rakibine gönder. O takımını seçip katıldığında savaş başlar.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Future.delayed(const Duration(milliseconds: 500)); // linter geçişi
                },
                icon: const Icon(Icons.copy, size: 16, color: Colors.tealAccent),
                label: const Text('Linki Kopyala',
                    style: TextStyle(color: Colors.tealAccent)),
              ),
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
              context.go('/pvp-battle?match=$matchId');
            },
            icon: const Icon(Icons.login, size: 16, color: Colors.black),
            label: const Text('LOBİYE GEÇ',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  double _cardWidth(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cols = 3;
    final available = screenW - 32;
    final raw = (available / cols) - 8;
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
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          title: const Text('ÇOĞUN TAKIM HAZIRLA',
              style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
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
                _loadHeroes();
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
            'Kahramanlar Seviye 100\'de yüklendi  ·  Kahraman seç → yuvaya ekle',
            style: TextStyle(color: Colors.white38, fontSize: context.labelFont - 1),
          ),
        ],
      ),
    );
  }

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
              : _buildEmptySlot(index, cardWidth),
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          KamCardWidget(
            card: hero,
            isSelected: false,
            isEnemy: false,
            onTap: () => _removeFromSlot(index),
            overrideWidth: cardWidth,
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
                child: const Icon(Icons.close, size: 11, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySlot(int index, double cardWidth,
      {bool isDragging = false}) {
    final isMain = index < 3;
    final cardH = cardWidth * 1.6;
    return SizedBox(
      width: cardWidth + 8,
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

  Widget _buildAvailableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              const Text(
                'KAHRAMANLAR (SEVİYE 1-5)',
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
        childAspectRatio: 1 / 1.75,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
      ),
      itemCount: _availableHeroes.length,
      itemBuilder: (_, index) {
        final hero = _availableHeroes[index];
        final blocked = _allSlotsFull;
        return LayoutBuilder(
          builder: (ctx, constraints) {
            final w = (constraints.maxWidth - 8).clamp(60.0, 200.0);
            return Stack(
              children: [
                KamCardWidget(
                  card: hero,
                  isSelected: false,
                  isEnemy: false,
                  onTap: blocked ? () {} : () => _tapAvailableHero(hero),
                  overrideWidth: w,
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
            );
          },
        );
      },
    );
  }

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
          else
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
        ],
      ),
    );
  }
}
