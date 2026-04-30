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

class BattleView extends StatelessWidget {
  const BattleView({super.key});

  @override
  Widget build(BuildContext context) {
    // GoogleFonts yerine standart font simülasyonu ve teması
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
          fontFamily: 'Serif', // Kadim bir hava için varsayılan serif fontu
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
              return Stack(
                children: [
                  Row(
                    children: [
                      // Sol Töz Paneli
                      _buildLeftSidebar(context, state),

                      // Orta: Savaş Alanı (3v3 Grid)
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(height: 40),
                            // Düşman Takımı
                            _buildTeamRow(context, state.enemyTeam, true, state),

                            // Orta Alan: Savaş Efektleri ve Tur Bilgisi
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
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
                                    Icon(
                                      state.isPlayerTurn ? LucideIcons.swords : LucideIcons.shieldAlert,
                                      color: state.isPlayerTurn ? Colors.blue.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                      size: 80,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Oyuncu Takımı
                            _buildTeamRow(context, state.playerTeam, false, state),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),

                      // Sağ: Sidebar (Görsel ve Loglar)
                      _buildSidebar(context, state),
                    ],
                  ),

                  // Sıra Uyarısı (Overlay)
                  if (!state.isPlayerTurn)
                    Positioned(
                      top: 20,
                      left: 0,
                      right: MediaQuery.of(context).size.width * 0.25,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.8),
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

  Widget _buildTeamRow(BuildContext context, List<dynamic> team, bool isEnemy, BattleInProgress state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(team.length, (index) {
        final card = team[index];
        final bool hasActed = !isEnemy && state.actedHeroIds.contains(card.id);
        final bool isSelected = isEnemy
            ? state.selectedTargetIndex == index
            : state.selectedHeroIndex == index;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Opacity(
            opacity: card.isAlive ? (hasActed ? 0.5 : 1.0) : 0.3,
            child: KamCardWidget(
              card: card,
              isSelected: isSelected,
              isEnemy: isEnemy,
              onTap: () => context.read<BattleCubit>().selectHero(index, isEnemy),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLeftSidebar(BuildContext context, BattleInProgress state) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.20,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              "Töz'ü Açığa Çıkar",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
            ),
          ),
          if (state.selectedHeroIndex == null)
            const Expanded(
              child: Center(
                child: Text(
                  "Bir kahraman seçin",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            )
          else ...[
            Builder(
              builder: (context) {
                final heroIndex = state.selectedHeroIndex!;
                final hero = state.playerTeam[heroIndex];
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.zap, color: Colors.lightBlueAccent, size: 20),
                        const SizedBox(width: 4),
                        Text("Kut: ${hero.kut}", style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  final heroIndex = state.selectedHeroIndex!;
                  final hero = state.playerTeam[heroIndex];
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: hero.skillCards.length,
                    itemBuilder: (context, index) {
                      final skill = hero.skillCards[index];
                      final isUsed = state.usedSkillIds.contains(skill.id);
                      final canAfford = hero.kut >= skill.cost;
                      final isAvailable = !isUsed && canAfford && state.isPlayerTurn;

                      return GestureDetector(
                        onTap: isAvailable ? () {
                          context.read<BattleCubit>().useSkill(heroIndex, skill);
                        } : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
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
                                  Expanded(child: Text(skill.name, style: TextStyle(color: isAvailable ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                                    child: Text(skill.cost.toString(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(skill.description, style: TextStyle(color: isAvailable ? Colors.white70 : Colors.white24, fontSize: 10)),
                              if (isUsed)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text("KULLANILDI", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                              else if (!canAfford && !isUsed)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text("YETERSİZ KUT", style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, BattleInProgress state) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.25,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(left: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          // Üst Kısım: Statik Karakter Görseli veya Bilgi
          AspectRatio(
            aspectRatio: 1.2,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.scroll, color: Colors.amber, size: 40),
                  SizedBox(height: 8),
                  Text(
                    "SAVAŞ DURUMU",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

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

          // Log Listesi
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: state.battleLogs.length,
              itemBuilder: (context, index) {
                final log = state.battleLogs[index];
                final isNew = index == 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isNew ? Colors.white.withOpacity(0.05) : Colors.transparent,
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