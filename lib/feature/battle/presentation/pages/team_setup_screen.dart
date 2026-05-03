import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../domain/entities/hero_entities.dart';
import '../../domain/usecases/fetch_user_heroes_usecase.dart';
import '../widgets/card_widget.dart';
import 'package:kam/core/di/injection.dart';

class TeamSetupScreen extends StatefulWidget {
  const TeamSetupScreen({super.key});

  @override
  State<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends State<TeamSetupScreen> {
  bool _isLoading = true;
  String? _error;
  List<HeroCardEntity> _allHeroes = [];

  // 5 yuva: 0-1-2 as takımı, 3-4 yedek kadro
  final List<HeroCardEntity?> _slots = List.filled(5, null);

  @override
  void initState() {
    super.initState();
    _loadHeroes();
  }

  Future<void> _loadHeroes() async {
    try {
      final heroes = await sl<FetchUserHeroesUseCase>().execute();
      if (!mounted) return;
      setState(() {
        _allHeroes = heroes;
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

  void _startBattle() {
    final playerTeam =
        _slots.sublist(0, 3).whereType<HeroCardEntity>().toList();
    if (playerTeam.isEmpty) return;
    final benchHeroes =
        _slots.sublist(3, 5).whereType<HeroCardEntity>().toList();
    context.go('/battle', extra: {
      'playerTeam': playerTeam,
      'benchHeroes': benchHeroes,
    });
  }

  // ── kart genişliğini ekran genişliğinden hesapla ─────────────────────────
  // 3 kart yan yana, 12px yatay padding, kartın kendi 4px marjini dahil
  double _cardWidth(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    // 3 * (cardW + 8) + 24 = screenW  →  cardW = (screenW - 48) / 3
    return ((screenW - 48.0) / 3).clamp(80.0, 130.0);
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

  // ── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TAKIM HAZIRLA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Kahraman seç → yuvaya ekle  ·  Sürükle → sırala  ·  Kart tıkla → çıkar',
            style: TextStyle(color: Colors.white38, fontSize: 10),
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                child:
                    const Icon(Icons.close, size: 11, color: Colors.white),
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
      width: cardWidth + 8, // kart marjını hesaba kat
      height: cardH + 16,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.plusCircle,
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1 / 1.75, // kart oranı (margin dahil)
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

  // ── CONFIRM BAR ───────────────────────────────────────────────────────────

  Widget _buildConfirmBar() {
    final mainCount =
        _slots.sublist(0, 3).whereType<HeroCardEntity>().length;
    final benchCount =
        _slots.sublist(3, 5).whereType<HeroCardEntity>().length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
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
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _canStart ? 1.0 : 0.4,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _canStart ? _startBattle : null,
              icon: const Icon(LucideIcons.swords,
                  color: Colors.white, size: 16),
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
      ),
    );
  }
}
