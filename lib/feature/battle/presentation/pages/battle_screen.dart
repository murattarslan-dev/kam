import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../manager/battle_cubit.dart';
import '../manager/battle_state.dart';
import '../widgets/card_widget.dart';

class BattleScreen extends StatelessWidget {
  const BattleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BattleCubit()..startBattle(),
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

    // Hareket Animasyonu: 0.0 -> 1.0 (Merkeze gidiş)
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _moveAnimation = CurvedAnimation(
      parent: _moveController,
      curve: Curves.easeInExpo,
    );

    // Titreme Animasyonu
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 20.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 20.0, end: -20.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -20.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    // Parlama Animasyonu
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_flashController);

    _startSequence();
  }

  Future<void> _startSequence() async {
    // 1. Merkeze doğru hızlanarak git
    await _moveController.forward();

    // 2. Çarpışma: Parlama ve Kısa Titreme
    _flashController.forward();
    _shakeController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _flashController.reverse();
    _shakeController.reverse();

    // 3. Geri yerlerine dön
    await _moveController.reverse();

    // 4. Bitiş
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
    return Stack(
      children: [
        // Arka Plan Karartma
        Container(color: Colors.black45),

        AnimatedBuilder(
          animation: Listenable.merge([_moveAnimation, _shakeAnimation, _flashAnimation]),
          builder: (context, child) {
            final size = MediaQuery.of(context).size;
            final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

            // Kartların başlangıç ve bitiş konumları
            // Oyuncu altta, Düşman üstte (Portrait)
            // Oyuncu solda, Düşman sağda (Landscape)
            
            double attackerX = 0, attackerY = 0;
            double targetX = 0, targetY = 0;

            if (isPortrait) {
              // Dikey konumlandırma
              double startY = size.height * 0.3; // Oyuncu alt
              double endY = size.height * -0.3; // Düşman üst
              
              if (widget.action.isPlayerAttacking) {
                attackerY = startY * (1 - _moveAnimation.value);
                targetY = endY * (1 - _moveAnimation.value);
              } else {
                attackerY = endY * (1 - _moveAnimation.value);
                targetY = startY * (1 - _moveAnimation.value);
              }
            } else {
              // Yatay konumlandırma
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

            // Titreme ofseti
            final shakeOffset = Offset(_shakeAnimation.value, _shakeAnimation.value / 2);

            return Stack(
              children: [
                // Saldıran Kart
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

                // Hedef Kart
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

                // Parlama Efekti
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
                        Expanded(flex: 1, child: _buildSidebar(context, state, isPortrait: true)),
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

                  // Animasyon Overlay
                  if (state.currentAction != null)
                    BattleAnimationOverlay(
                      action: state.currentAction!,
                      onComplete: () => context.read<BattleCubit>().onAnimationComplete(),
                    ),

                  // Sıra Uyarısı (Overlay)
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
        // Düşman Takımı
        _buildTeamRow(context, state.enemyTeam, true, state),

        // Orta Alan: Savaş Efektleri, Butonlar ve Tur Bilgisi
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.selectedHeroIndex != null && state.selectedTargetIndex != null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => context.read<BattleCubit>().executePlayerAttack(),
                    icon: const Icon(LucideIcons.swords, color: Colors.white),
                    label: const Text("SALDIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                else
                  Text(
                    "TUR ${state.currentTurn}",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white24,
                      letterSpacing: 8,
                    ),
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

        // Oyuncu Takımı
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
        final bool isSelected = isEnemy
            ? state.selectedTargetIndex == index
            : state.selectedHeroIndex == index;

        // Animasyon sırasında ilgili kartları gizle
        final bool isAnimating = state.currentAction?.attacker.id == card.id || 
                                 state.currentAction?.target.id == card.id;

        double? advantageMultiplier;
        if (isEnemy && state.selectedHeroIndex != null && isSelected) {
          final playerHero = state.playerTeam[state.selectedHeroIndex!];
          advantageMultiplier = playerHero.element.getDamageMultiplier(card.element);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Opacity(
            opacity: isAnimating ? 0.0 : (card.isAlive ? (hasActed ? 0.5 : 1.0) : 0.3),
            child: KamCardWidget(
              card: card,
              isSelected: isSelected,
              isEnemy: isEnemy,
              advantageMultiplier: advantageMultiplier,
              onTap: () => context.read<BattleCubit>().selectHero(index, isEnemy),
              onTozPressed: (!isEnemy && isSelected && state.isPlayerTurn) 
                  ? () => _showTozDialog(context, state) 
                  : null,
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
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: hero.skillCards.length,
              itemBuilder: (itemContext, index) {
                final skill = hero.skillCards[index];
                final isUsed = state.usedSkillIds.contains(skill.id);
                final canAfford = hero.kut >= skill.cost;
                final isAvailable = !isUsed && canAfford && state.isPlayerTurn;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAvailable ? const Color(0xFF1E293B) : Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isAvailable ? Colors.purpleAccent : Colors.white10),
                  ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(skill.name, style: TextStyle(color: isAvailable ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                              child: Text(skill.cost.toString(), style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(skill.description, style: TextStyle(color: isAvailable ? Colors.white70 : Colors.white24, fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (isUsed)
                              const Text("KULLANILDI", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))
                            else if (!canAfford)
                              const Text("YETERSİZ KUT", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold))
                            else
                              const SizedBox.shrink(),
                            if (isAvailable)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purpleAccent,
                                  minimumSize: const Size(60, 30),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                onPressed: () {
                                  context.read<BattleCubit>().useSkill(heroIndex, skill);
                                  Navigator.pop(dContext);
                                },
                                child: const Text("KULLAN", style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
                    ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dContext),
              child: const Text("KAPAT", style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, BattleInProgress state, {required bool isPortrait}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: isPortrait
            ? const Border(top: BorderSide(color: Colors.white10))
            : const Border(left: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          // Başlık
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(LucideIcons.activity, size: 16, color: Colors.blueGrey),
                SizedBox(width: 8),
                Text(
                  "SAVAŞ GÜNCESİ",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Log Listesi
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: state.battleLogs.length,
              itemBuilder: (context, index) {
                final log = state.battleLogs[index];
                final isNew = index == 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isNew ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: isNew ? Border.all(color: Colors.white10) : null,
                  ),
                  child: Text(
                    log,
                    style: TextStyle(
                      fontSize: 12,
                      color: isNew ? Colors.white : Colors.white38,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context, BattleResult state) {
    return Container(
      width: double.infinity,
      color: Colors.black26,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            state.isVictory ? LucideIcons.trophy : LucideIcons.skull,
            size: 120,
            color: state.isVictory ? Colors.amber : Colors.redAccent,
          ),
          const SizedBox(height: 24),
          Text(
            state.isVictory ? "ZAFER" : "MAĞLUBİYET",
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: 10,
              color: state.isVictory ? Colors.amber : Colors.redAccent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.white70),
          ),
          if (state.rewards.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text("KAZANIMLAR:", style: TextStyle(color: Colors.blueGrey, fontSize: 14)),
            const SizedBox(height: 8),
            ...state.rewards.map((r) => Text(r, style: const TextStyle(color: Colors.greenAccent))),
          ],
          const SizedBox(height: 60),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            onPressed: () => context.read<BattleCubit>().startBattle(),
            icon: const Icon(LucideIcons.refreshCw),
            label: const Text("YENİDEN DENE"),
          ),
        ],
      ),
    );
  }
}