import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../manager/battle_cubit.dart';
import '../manager/battle_state.dart';
import '../widgets/card_widget.dart';
import 'package:kam/core/util/responsive_helper.dart';
import 'package:kam/core/di/injection.dart';

class BattleScreen extends StatelessWidget {
  const BattleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<BattleCubit>()..startBattle(),
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
        body: BlocBuilder<BattleCubit, BattleState>(
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
                        Expanded(flex: 3, child: _buildArena(context, state)),
                        if (context.screenHeight > 700)
                          Expanded(flex: 1, child: _buildSidebar(context, state, isPortrait: true))
                        else
                          SizedBox(height: 120, child: _buildSidebar(context, state, isPortrait: true)),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(flex: 3, child: _buildArena(context, state)),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.3,
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
            return const SizedBox.shrink();
          },
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
    return Row(
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
            ),
          ),
        );
      }),
    );
  }

  void _showTozDialog(BuildContext context, BattleInProgress state) {
    final heroIndex = state.selectedHeroIndex;
    if (heroIndex == null) return;
    final hero = state.playerTeam[heroIndex];

    showDialog(
      context: context,
      builder: (dContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Text("Töz'ü Açığa Çıkar - Kut: ${hero.kut}", style: const TextStyle(color: Colors.purpleAccent, fontSize: 16)),
          content: SizedBox(
            width: 400,
            height: 300,
            child: ListView.builder(
              itemCount: hero.skillCards.length,
              itemBuilder: (context, index) {
                final skill = hero.skillCards[index];
                final isUsed = state.usedSkillIds.contains(skill.id);
                final canAfford = hero.kut >= skill.cost;
                final isPrerequisiteMet = context.read<BattleCubit>().isSkillPrerequisiteMet(hero, skill);
                final isAvailable = !isUsed && canAfford && isPrerequisiteMet && state.isPlayerTurn;

                return ListTile(
                  title: Text(skill.name, style: TextStyle(color: isAvailable ? Colors.white : Colors.white24)),
                  subtitle: Text(skill.description, style: TextStyle(color: isAvailable ? Colors.white70 : Colors.white12)),
                  trailing: Text(skill.cost.toString(), style: const TextStyle(color: Colors.blueAccent)),
                  onTap: isAvailable ? () {
                    context.read<BattleCubit>().useSkill(heroIndex, skill);
                    Navigator.pop(dContext);
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(state.isVictory ? LucideIcons.trophy : LucideIcons.skull, size: 100, color: state.isVictory ? Colors.amber : Colors.redAccent),
          const SizedBox(height: 20),
          Text(state.isVictory ? "ZAFER" : "MAĞLUBİYET", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(state.message, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 40),
          ElevatedButton(onPressed: () => context.read<BattleCubit>().startBattle(), child: const Text("TEKRAR OYNA")),
        ],
      ),
    );
  }
}