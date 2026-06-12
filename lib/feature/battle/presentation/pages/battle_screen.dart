import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../manager/battle_cubit.dart';
import '../manager/battle_state.dart';
import '../widgets/card_widget.dart';
import '../widgets/floating_number.dart';
import '../widgets/hero_detail_dialog.dart';
import '../../domain/entities/hero_entities.dart';
import '../../domain/entities/buff_entities.dart';
import 'package:kam/core/util/responsive_helper.dart';
import 'package:kam/core/util/player_id.dart';
import 'package:kam/core/di/injection.dart';

class BattleScreen extends StatelessWidget {
  final List<HeroCardEntity>? playerTeam;
  final List<HeroCardEntity>? benchHeroes;
  final String? matchId;

  const BattleScreen({super.key, this.playerTeam, this.benchHeroes, this.matchId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BattleCubit>(
      create: (context) {
        final cubit = sl<BattleCubit>();
        final myId = getPlayerId();
        final mid = matchId;
        if (mid != null) {
          cubit.openExistingBattle(mid, myId);
        } else {
          cubit.startPveBattle(
            myId: myId,
            playerTeam: playerTeam,
            benchHeroes: benchHeroes,
          );
        }
        return cubit;
      },
      child: const BattleView(),
    );
  }
}

class BattleAnimationOverlay extends StatefulWidget {
  final BattleAction action;
  final VoidCallback onComplete;

  const BattleAnimationOverlay({
    super.key,
    required this.action,
    required this.onComplete,
  });

  @override
  State<BattleAnimationOverlay> createState() => _BattleAnimationOverlayState();
}

class _BattleAnimationOverlayState extends State<BattleAnimationOverlay> with TickerProviderStateMixin {
  late AnimationController _moveController;
  late AnimationController _shakeController;
  late AnimationController _flashController;

  late Animation<double> _moveAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();

    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _moveAnimation = CurvedAnimation(
      parent: _moveController,
      curve: Curves.easeInExpo,
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 20.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 20.0, end: -20.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -20.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_flashController);

    _startSequence();
  }

  Future<void> _startSequence() async {
    await _moveController.forward();
    _flashController.forward();
    _shakeController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _flashController.reverse();
    _shakeController.reverse();
    await _moveController.reverse();
    widget.onComplete();
  }

  @override
  void dispose() {
    _moveController.dispose();
    _shakeController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return Stack(
      children: [
        Container(color: Colors.black45),
        AnimatedBuilder(
          animation: Listenable.merge([_moveAnimation, _shakeAnimation, _flashAnimation]),
          builder: (context, child) {
            double attackerX = 0, attackerY = 0;
            double targetX = 0, targetY = 0;

            if (isPortrait) {
              double startY = size.height * 0.3;
              double endY = size.height * -0.3;
              if (widget.action.isPlayerAttacking) {
                attackerY = startY * (1 - _moveAnimation.value);
                targetY = endY * (1 - _moveAnimation.value);
              } else {
                attackerY = endY * (1 - _moveAnimation.value);
                targetY = startY * (1 - _moveAnimation.value);
              }
            } else {
              double startX = size.width * 0.3;
              double endX = size.width * -0.3;
              if (widget.action.isPlayerAttacking) {
                attackerX = startX * (1 - _moveAnimation.value);
                targetX = endX * (1 - _moveAnimation.value);
              } else {
                attackerX = endX * (1 - _moveAnimation.value);
                targetX = startX * (1 - _moveAnimation.value);
              }
            }

            final shakeOffset = Offset(_shakeAnimation.value, _shakeAnimation.value / 2);

            return Stack(
              children: [
                Center(
                  child: Transform.translate(
                    offset: Offset(attackerX, attackerY) + shakeOffset,
                    child: KamCardWidget(
                      card: widget.action.attacker,
                      isSelected: true,
                      isEnemy: !widget.action.isPlayerAttacking,
                      onTap: () {},
                    ),
                  ),
                ),
                Center(
                  child: Transform.translate(
                    offset: Offset(targetX, targetY) + shakeOffset,
                    child: KamCardWidget(
                      card: widget.action.target,
                      isSelected: false,
                      isEnemy: widget.action.isPlayerAttacking,
                      onTap: () {},
                    ),
                  ),
                ),
                if (_flashAnimation.value > 0)
                  Center(
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: _flashAnimation.value),
                            Colors.blueAccent.withValues(alpha: _flashAnimation.value * 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class BattleView extends StatefulWidget {
  const BattleView({super.key});

  @override
  State<BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends State<BattleView> {
  int _seenLogCount = 0;

  void _showBattleLog(BuildContext context, BattleInProgress state) {
    // Aç anında tüm logları görülmüş say.
    setState(() => _seenLogCount = state.battleLogs.length);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildActiveEffectsSection(state),
                    ),
                    SliverToBoxAdapter(
                      child: _sectionHeader("SAVAŞ GÜNCESİ"),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      sliver: SliverList.separated(
                        itemCount: state.battleLogs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white12, height: 12),
                        itemBuilder: (_, i) {
                          // battleLogs[0] en yeni; doğal sırada gösteriyoruz.
                          final isNewest = i == 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              state.battleLogs[i],
                              style: TextStyle(
                                fontSize: 12,
                                color: isNewest ? Colors.white : Colors.white70,
                                height: 1.5,
                                fontWeight: isNewest ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: Colors.white10, height: 1)),
        ],
      ),
    );
  }

  Widget _buildActiveEffectsSection(BattleInProgress state) {
    if (state.activeBuffs.isEmpty) return const SizedBox.shrink();
    final allHeroes = [
      ...state.playerTeam,
      ...state.enemyTeam,
      ...state.benchHeroes,
    ];
    final playerIds = state.playerTeam.map((h) => h.id).toSet();

    Widget chip(ActiveBuff ab) {
      final buff = state.allBuffs.where((b) => b.id == ab.buffId).firstOrNull;
      final hero = allHeroes.where((h) => h.id == ab.targetHeroId).firstOrNull;
      final isPlayer = playerIds.contains(ab.targetHeroId);
      final isDebuff = buff?.isDebuff ?? false;
      final color = isDebuff ? Colors.redAccent : Colors.tealAccent;
      final heroName = hero?.name ?? '?';
      final buffName = buff?.name ?? ab.buffId;
      final desc = buff?.description ?? '';
      final remaining = ab.remainingTurns < 0
          ? '∞'
          : '${ab.remainingTurns} tur';

      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isPlayer ? Icons.shield_outlined : Icons.person_outline,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$heroName · $buffName",
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (desc.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              remaining,
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("AKTİF ETKİLER (${state.activeBuffs.length})"),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(children: state.activeBuffs.map(chip).toList()),
        ),
      ],
    );
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
          child: BlocConsumer<BattleCubit, BattleState>(
          listenWhen: (_, c) => c is BattleFinished,
          listener: (context, state) {
            if (state is BattleFinished) {
              // Savaş ekranını tamamen kapat, ana sayfaya dön ve rapor ekranını aç.
              final battleId = state.battleId;
              final side = state.mySide;
              context.go('/');
              context.push('/battle-result/$battleId?side=$side');
            }
          },
          builder: (context, state) {
            if (state is BattleInitial || state is BattleLoading) {
              final loadingState = state as BattleLoading?;
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.deepPurple),
                    if (loadingState?.message != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        loadingState!.message!,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              );
            }
            if (state is BattleFinished) {
              return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
            }
            if (state is BattleInProgress) {
              // Görülmemiş log sayısı: state.battleLogs.length > _seenLogCount → fark
              final unseen = (state.battleLogs.length - _seenLogCount).clamp(0, 999);
              return Stack(
                children: [
                  _buildArena(context, state),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'log_fab',
                      backgroundColor: const Color(0xFF1E293B),
                      onPressed: () => _showBattleLog(context, state),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.history_edu,
                            color: state.activeBuffs.isNotEmpty
                                ? Colors.tealAccent
                                : Colors.white70,
                            size: 20,
                          ),
                          if (unseen > 0)
                            Positioned(
                              top: -4, right: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$unseen',
                                  style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (state.currentAction != null)
                    BattleAnimationOverlay(
                      action: state.currentAction!,
                      onComplete: () => context.read<BattleCubit>().onAnimationComplete(),
                    ),
                  if (!state.isPlayerTurn && state.currentAction == null)
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "DÜŞMAN HAMLE YAPIYOR...",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }
            // BattleError veya beklenmedik durum
            if (state is BattleError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        ),
      ),
    );
  }

  Widget _buildArena(BuildContext context, BattleInProgress state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(height: 10),
        _buildPlayerLabel(state.enemyName ?? 'Rakip', isEnemy: true),
        _buildTeamRow(context, state.enemyTeam, true, state),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (state.selectedHeroIndex != null && state.selectedTargetIndex != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => context.read<BattleCubit>().executePlayerAttack(),
                      icon: const Icon(Icons.flash_on, color: Colors.white),
                      label: const Text("SALDIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  else
                    Text(
                      "TUR ${state.currentTurn}",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white24, letterSpacing: 8),
                    ),
                  const SizedBox(height: 10),
                  // Değiştir butonu: hero seçili, hedef yok, henüz saldırı yapılmamış, bench dolu
                  if (state.isPlayerTurn &&
                      state.selectedHeroIndex != null &&
                      state.selectedTargetIndex == null &&
                      state.benchHeroes.isNotEmpty &&
                      state.actedHeroIds.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showSwapDialog(context, state),
                        icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                        label: const Text("DEĞİŞTİR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (state.selectedHeroIndex == null && state.selectedTargetIndex == null)
                    Icon(
                      state.isPlayerTurn ? Icons.flash_on : Icons.shield_outlined,
                      color: state.isPlayerTurn ? Colors.blue.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                      size: 60,
                    ),
                ],
              ),
            ),
          ),
        ),
        _buildTeamRow(context, state.playerTeam, false, state),
        _buildPlayerLabel(state.playerName ?? 'Sen', isEnemy: false),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildPlayerLabel(String name, {required bool isEnemy}) {
    final color = isEnemy ? Colors.redAccent : Colors.tealAccent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEnemy ? Icons.person_outline : Icons.shield_outlined,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamRow(BuildContext context, List<dynamic> team, bool isEnemy, BattleInProgress state) {
    // Hedef seçili düşman (oyuncu takımı reaksiyonu için).
    final HeroCardEntity? selectedEnemy = (state.selectedTargetIndex != null &&
            state.selectedTargetIndex! < state.enemyTeam.length)
        ? state.enemyTeam[state.selectedTargetIndex!]
        : null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
      child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(team.length, (index) {
        final HeroCardEntity card = team[index];
        final bool hasActed = !isEnemy && state.actedHeroIds.contains(card.id);
        final bool isSelected = isEnemy ? state.selectedTargetIndex == index : state.selectedHeroIndex == index;
        final bool isAnimating = state.currentAction?.attacker.id == card.id || state.currentAction?.target.id == card.id;

        final delta = state.floatingDeltas[card.id];
        final showFloater = delta != null &&
            state.currentAction == null &&
            state.lastActionSeq != null;

        // Element reaksiyonu: SADECE oyuncunun seçili kartı, seçili düşmana göre reaksiyon verir.
        double? reaction;
        if (!isEnemy && isSelected && card.isAlive && !isAnimating && selectedEnemy != null) {
          reaction = card.element.getDamageMultiplier(selectedEnemy.element);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: isAnimating ? 0.0 : (card.isAlive ? (hasActed ? 0.5 : 1.0) : 0.3),
                child: _HeroBattleSlot(
                  card: card,
                  isEnemy: isEnemy,
                  isSelected: isSelected,
                  reactionMultiplier: reaction,
                  onTap: () {
                    if (!isEnemy && !card.isAlive) {
                      if (state.benchHeroes.isNotEmpty && state.isPlayerTurn) {
                        _showSwapDialogFor(context, state, index);
                      }
                      return;
                    }
                    context.read<BattleCubit>().selectHero(index, isEnemy);
                  },
                  onLongPress: () => HeroDetailDialog.show(context, card),
                  onTozPressed: (!isEnemy && isSelected && state.isPlayerTurn)
                      ? () => _showTozDialog(context, state)
                      : null,
                  activeBuffs: state.activeBuffs,
                  allBuffs: state.allBuffs,
                ),
              ),
              if (showFloater)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: FloatingNumber(
                        key: ValueKey('floater-${card.id}-${state.lastActionSeq}'),
                        amount: delta,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    ),
    );
  }

  String _elementEmoji(HeroElement element) => switch (element) {
    HeroElement.fire => "🔥",
    HeroElement.water => "💧",
    HeroElement.wind => "🌬️",
    HeroElement.steppe => "🌾",
    HeroElement.forest => "🌲",
    HeroElement.dark => "🌑",
  };

  void _showSwapDialog(BuildContext context, BattleInProgress state) {
    final heroIndex = state.selectedHeroIndex;
    if (heroIndex == null) return;
    _showSwapDialogFor(context, state, heroIndex);
  }

  void _showSwapDialogFor(BuildContext context, BattleInProgress state, int heroIndex) {
    if (heroIndex < 0 || heroIndex >= state.playerTeam.length) return;
    final fieldHero = state.playerTeam[heroIndex];
    // Cubit'i dialog açılmadan önce yakala — dialog içindeki context'ler
    // BlocProvider'a ulaşamadığından bu referans kapatma (closure) yoluyla kullanılır.
    final cubit = context.read<BattleCubit>();

    showDialog(
      context: context,
      builder: (dContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Text(
            "${fieldHero.name} → Değiştir",
            style: const TextStyle(color: Colors.tealAccent, fontSize: 16),
          ),
          content: SizedBox(
            width: dContext.dialogWidth(),
            height: dContext.dialogHeight(max: 320),
            child: ListView.builder(
              itemCount: state.benchHeroes.length,
              itemBuilder: (_, index) {
                final bench = state.benchHeroes[index];
                final dead = !bench.isAlive;
                return ListTile(
                  enabled: !dead,
                  leading: Text(_elementEmoji(bench.element), style: const TextStyle(fontSize: 22)),
                  title: Text(
                    dead ? "${bench.name} (ölü)" : bench.name,
                    style: TextStyle(color: dead ? Colors.white38 : Colors.white),
                  ),
                  subtitle: Text(
                    "Lv ${bench.level}  ·  ATK ${bench.currentAttackPower}  ·  DEF ${bench.currentDefensePower}  ·  HP ${bench.health}/${bench.currentCp}",
                    style: TextStyle(color: dead ? Colors.white24 : Colors.white60, fontSize: 11),
                  ),
                  onTap: dead
                      ? null
                      : () {
                          Navigator.pop(dContext);
                          cubit.swapHero(heroIndex, index);
                        },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dContext),
              child: const Text("KAPAT"),
            ),
          ],
        );
      },
    );
  }

  void _showTozDialog(BuildContext context, BattleInProgress state) {
    final heroIndex = state.selectedHeroIndex;
    if (heroIndex == null) return;
    final hero = state.playerTeam[heroIndex];
    final cubit = context.read<BattleCubit>();

    showDialog(
      context: context,
      builder: (dContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Text("Töz'ü Açığa Çıkar - Kut: ${hero.kut}", style: const TextStyle(color: Colors.purpleAccent, fontSize: 16)),
          content: SizedBox(
            width: dContext.dialogWidth(),
            height: dContext.dialogHeight(max: 320),
            child: ListView.builder(
              itemCount: hero.skillCards.length,
              itemBuilder: (_, index) {
                final skill = hero.skillCards[index];
                final isUsed = state.usedSkillIds.contains(skill.id);
                final canAfford = hero.kut >= skill.cost;
                final isPrerequisiteMet = cubit.isSkillPrerequisiteMet(hero, skill);
                final isAvailable = !isUsed && canAfford && isPrerequisiteMet && state.isPlayerTurn;

                return ListTile(
                  title: Text(skill.name, style: TextStyle(color: isAvailable ? Colors.white : Colors.white24)),
                  subtitle: Text(skill.description, style: TextStyle(color: isAvailable ? Colors.white70 : Colors.white12)),
                  trailing: Text(skill.cost.toString(), style: const TextStyle(color: Colors.blueAccent)),
                  onTap: isAvailable ? () {
                    Navigator.pop(dContext);
                    cubit.useSkill(heroIndex, skill);
                  } : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dContext), child: const Text("KAPAT")),
          ],
        );
      },
    );
  }
}

/// Savaş ekranındaki bir takım yuvası: kart + stat strip + element reaksiyonu.
/// [reactionMultiplier] null değilse karşı taraftan bir hedef seçilmiş demektir;
///   > 1.0 → bu kart o hedefe karşı üstün → saldırgan zıplama animasyonu
///   < 1.0 → o hedef bu karta karşı üstün → hafif geri çekilip soluklaşma
class _HeroBattleSlot extends StatefulWidget {
  final HeroCardEntity card;
  final bool isEnemy;
  final bool isSelected;
  final double? reactionMultiplier;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onTozPressed;
  final List<ActiveBuff> activeBuffs;
  final List<BuffEntity> allBuffs;

  const _HeroBattleSlot({
    required this.card,
    required this.isEnemy,
    required this.isSelected,
    required this.reactionMultiplier,
    required this.onTap,
    required this.onLongPress,
    required this.onTozPressed,
    required this.activeBuffs,
    required this.allBuffs,
  });

  @override
  State<_HeroBattleSlot> createState() => _HeroBattleSlotState();
}

class _HeroBattleSlotState extends State<_HeroBattleSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lunge;

  static const _lungeDistance = 18.0;
  // 0..1 boyunca: ilk %15 hızlı ileri atlama, kalan %85 yavaş geri dönüş.
  static const _peakPoint = 0.15;

  @override
  void initState() {
    super.initState();
    _lunge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _HeroBattleSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reactionMultiplier != widget.reactionMultiplier) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final mult = widget.reactionMultiplier;
    if (mult != null && mult > 1.0) {
      if (!_lunge.isAnimating) _lunge.repeat();
    } else {
      _lunge.stop();
      _lunge.value = 0.0;
    }
  }

  @override
  void dispose() {
    _lunge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mult = widget.reactionMultiplier;
    final bool hasAdvantage = mult != null && mult > 1.0;
    final bool isDisadvantaged = mult != null && mult < 1.0;

    return AnimatedBuilder(
      animation: _lunge,
      builder: (_, __) {
        double dy = 0;
        double opacity = 1.0;
        if (hasAdvantage) {
          final t = _lunge.value;
          double factor;
          if (t <= _peakPoint) {
            // Hızlı ileri: 0 → 1
            factor = Curves.easeOutCubic.transform(t / _peakPoint);
          } else {
            // Yavaş geri: 1 → 0
            final back = (t - _peakPoint) / (1 - _peakPoint);
            factor = 1 - Curves.easeInOutCubic.transform(back);
          }
          // Oyuncu takımı yukarı (-Y) yönünde rakibe doğru atlar.
          dy = -_lungeDistance * factor;
        } else if (isDisadvantaged) {
          // Hafif geri çekil + solgun.
          dy = 6;
          opacity = 0.55;
        }
        return Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(
            opacity: opacity,
            child: GestureDetector(
              onLongPress: widget.onLongPress,
              child: KamCardWidget(
                card: widget.card,
                isSelected: widget.isSelected,
                isEnemy: widget.isEnemy,
                onTap: widget.onTap,
                onTozPressed: widget.onTozPressed,
                activeBuffs: widget.activeBuffs,
                allBuffs: widget.allBuffs,
                advantageMultiplier: mult,
              ),
            ),
          ),
        );
      },
    );
  }
}


