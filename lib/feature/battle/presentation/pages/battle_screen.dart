import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../manager/battle_cubit.dart';
import '../manager/battle_state.dart';
import '../widgets/card_widget.dart';
import '../../domain/entities/hero_entities.dart';
import 'package:kam/core/util/responsive_helper.dart';
import 'package:kam/core/di/injection.dart';

class BattleScreen extends StatelessWidget {
  final List<HeroCardEntity>? playerTeam;
  final List<HeroCardEntity>? benchHeroes;

  const BattleScreen({super.key, this.playerTeam, this.benchHeroes});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<BattleCubit>()..startBattle(
        playerTeam: playerTeam,
        benchHeroes: benchHeroes,
      ),
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
          child: BlocBuilder<BattleCubit, BattleState>(
          builder: (context, state) {
            if (state is BattleInitial || state is BattleLoading) {
              return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
            }
            if (state is BattleResult) {
              return _buildResultView(context, state);
            }
            if (state is BattleInProgress) {
              final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
              return Stack(
                children: [
                  if (isPortrait)
                    Column(
                      children: [
                        Expanded(
                          flex: context.responsive<int>(5, tablet: 3),
                          child: _buildArena(context, state),
                        ),
                        Expanded(
                          flex: context.responsive<int>(4, tablet: 1),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 140),
                            child: _buildSidebar(context, state, isPortrait: true),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: _buildArena(context, state)),
                        SizedBox(
                          width: (MediaQuery.of(context).size.width *
                                  context.responsive<double>(0.38, tablet: 0.3))
                              .clamp(220.0, 380.0),
                          child: _buildSidebar(context, state, isPortrait: false),
                        ),
                      ],
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
                      icon: const Icon(LucideIcons.swords, color: Colors.white),
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
                        icon: const Icon(LucideIcons.arrowLeftRight, color: Colors.white, size: 18),
                        label: const Text("DEĞİŞTİR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (state.selectedHeroIndex == null && state.selectedTargetIndex == null)
                    Icon(
                      state.isPlayerTurn ? LucideIcons.swords : LucideIcons.shieldAlert,
                      color: state.isPlayerTurn ? Colors.blue.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                      size: 60,
                    ),
                ],
              ),
            ),
          ),
        ),
        _buildTeamRow(context, state.playerTeam, false, state),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildTeamRow(BuildContext context, List<dynamic> team, bool isEnemy, BattleInProgress state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
      child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(team.length, (index) {
        final card = team[index];
        final bool hasActed = !isEnemy && state.actedHeroIds.contains(card.id);
        final bool isSelected = isEnemy ? state.selectedTargetIndex == index : state.selectedHeroIndex == index;
        final bool isAnimating = state.currentAction?.attacker.id == card.id || state.currentAction?.target.id == card.id;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Opacity(
            opacity: isAnimating ? 0.0 : (card.isAlive ? (hasActed ? 0.5 : 1.0) : 0.3),
            child: KamCardWidget(
              card: card,
              isSelected: isSelected,
              isEnemy: isEnemy,
              onTap: () => context.read<BattleCubit>().selectHero(index, isEnemy),
              onTozPressed: (!isEnemy && isSelected && state.isPlayerTurn) ? () => _showTozDialog(context, state) : null,
              activeBuffs: state.activeBuffs,
              allBuffs: state.allBuffs,
            ),
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
                return ListTile(
                  leading: Text(_elementEmoji(bench.element), style: const TextStyle(fontSize: 22)),
                  title: Text(bench.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    "Lv ${bench.level}  ·  ATK ${bench.currentAttackPower}  ·  DEF ${bench.currentDefensePower}  ·  HP ${bench.health}/${bench.currentCp}",
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  onTap: () {
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

  Widget _buildSidebar(BuildContext context, BattleInProgress state, {required bool isPortrait}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0F172A), border: isPortrait ? const Border(top: BorderSide(color: Colors.white10)) : const Border(left: BorderSide(color: Colors.white10))),
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.all(12.0), child: Text("SAVAŞ GÜNCESİ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: state.battleLogs.length,
              itemBuilder: (context, index) => Text(state.battleLogs[index], style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context, BattleResult state) {
    final isVictory = state.isVictory;
    final accent = isVictory ? Colors.amber : Colors.redAccent;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          // Başlık
          Icon(isVictory ? LucideIcons.trophy : LucideIcons.skull, size: 72, color: accent),
          const SizedBox(height: 12),
          Text(
            isVictory ? "ZAFER" : "MAĞLUBİYET",
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: accent, letterSpacing: 4),
          ),
          const SizedBox(height: 6),
          Text(state.message, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 28),

          // Kahraman İstatistikleri — sahada oynayan kahramanlar
          _SectionHeader(title: "Kahraman İstatistikleri", icon: LucideIcons.swords),
          const SizedBox(height: 8),
          if (state.playerTeam.isEmpty)
            const Text("Veri yok", style: TextStyle(color: Colors.white38))
          else
            ...state.playerTeam.map((hero) => _HeroStatCard(
              hero: hero,
              damageDealt: (state.totalDamageDealt[hero.id] ?? 0).round(),
              damageReceived: (state.totalDamageReceived[hero.id] ?? 0).round(),
              xpGained: state.heroXpGained[hero.id] ?? 0,
              isBench: false,
            )),

          // Yedek kadro
          if (state.benchHeroes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionHeader(title: "Yedek Kadro", icon: LucideIcons.users),
            const SizedBox(height: 8),
            ...state.benchHeroes.map((hero) => _HeroStatCard(
              hero: hero,
              damageDealt: (state.totalDamageDealt[hero.id] ?? 0).round(),
              damageReceived: (state.totalDamageReceived[hero.id] ?? 0).round(),
              xpGained: state.heroXpGained[hero.id] ?? 0,
              isBench: true,
            )),
          ],

          // Aktif Buff/Debuff
          if (state.activeBuffs.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(title: "Aktif Etki Alanları", icon: LucideIcons.zap),
            const SizedBox(height: 8),
            ...state.activeBuffs.map((ab) {
              final buff = state.allBuffs.where((b) => b.id == ab.buffId).firstOrNull;
              final targetHero = state.playerTeam.where((h) => h.id == ab.targetHeroId).firstOrNull;
              return _BuffRow(
                buffName: buff?.name ?? ab.buffId,
                targetName: targetHero?.name ?? ab.targetHeroId,
                remainingTurns: ab.remainingTurns,
              );
            }),
          ],

          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/team-setup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              child: const Text("TEKRAR OYNA"),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.5)),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: Colors.white12)),
      ],
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  final HeroCardEntity hero;
  final int damageDealt;
  final int damageReceived;
  final int xpGained;
  final bool isBench;

  const _HeroStatCard({
    required this.hero,
    required this.damageDealt,
    required this.damageReceived,
    required this.xpGained,
    required this.isBench,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 32, height: 32,
                child: hero.imageUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          hero.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 20, color: Colors.white54),
                        ),
                      )
                    : const Icon(Icons.shield, size: 20, color: Colors.white54),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Text(hero.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    if (isBench) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text("yedek", style: TextStyle(fontSize: 9, color: Colors.white38, letterSpacing: 0.5)),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Text(
                  "+$xpGained XP",
                  style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatPill(icon: LucideIcons.swords, label: "Verilen Hasar", value: damageDealt, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              _StatPill(icon: LucideIcons.shieldAlert, label: "Alınan Hasar", value: damageReceived, color: Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _StatPill({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8), letterSpacing: 0.5)),
                  Text("$value", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuffRow extends StatelessWidget {
  final String buffName;
  final String targetName;
  final int remainingTurns;

  const _BuffRow({required this.buffName, required this.targetName, required this.remainingTurns});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, size: 14, color: Colors.purpleAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: buffName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                TextSpan(text: "  ·  $targetName", style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
          ),
          if (remainingTurns >= 0)
            Text("$remainingTurns tur", style: const TextStyle(fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }
}