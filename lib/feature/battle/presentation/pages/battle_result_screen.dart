import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Savaş sonu raporu — `battles/{id}` dokümanını bir kez okur ve
/// host/guest sekmelerinde her iki takımın da tüm kahramanlarını
/// (yedek/as ayrımı olmadan) listeler.
///
/// Bu ekran savaş motoruyla **bağlantısızdır**: ne snapshot dinler ne de
/// XP yazar. XP yazımı savaş bittiği an cubit tarafından tetiklenmiştir.
class BattleResultScreen extends StatefulWidget {
  final String battleId;
  final String mySide; // 'host' | 'guest' — hangi sekme önce açılsın

  const BattleResultScreen({
    super.key,
    required this.battleId,
    required this.mySide,
  });

  @override
  State<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends State<BattleResultScreen>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>?> _docFuture;
  TabController? _tab;

  @override
  void initState() {
    super.initState();
    _docFuture = FirebaseFirestore.instance
        .collection('battles')
        .doc(widget.battleId)
        .get()
        .then((s) => s.data());
  }

  @override
  void dispose() {
    _tab?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _docFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              );
            }
            final data = snap.data;
            if (data == null) {
              return _error("Savaş kaydı bulunamadı.");
            }
            final result = data['result'] as Map?;
            if (result == null) {
              return _error("Savaş sonucu yazılmadı.");
            }
            return _buildReport(context, data, Map<String, dynamic>.from(result));
          },
        ),
      ),
    );
  }

  Widget _error(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(msg,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text("Ana sayfaya dön"),
              ),
            ],
          ),
        ),
      );

  Widget _buildReport(
    BuildContext context,
    Map<String, dynamic> data,
    Map<String, dynamic> result,
  ) {
    final winnerSide = result['winnerSide'] as String?;
    final isVictory = winnerSide == widget.mySide;
    final accent = isVictory ? Colors.amber : Colors.redAccent;

    final hostName = (data['hostName'] as String?) ?? 'Ev sahibi';
    final guestName = (data['guestName'] as String?) ?? 'Konuk';
    final turns = (result['turns'] as num?)?.toInt() ?? 0;

    final heroStats = ((result['heroStats'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    int xpOf(Map<String, dynamic> s) => (s['xpGained'] as num?)?.toInt() ?? 0;
    final hostStats = heroStats.where((s) => s['side'] == 'host').toList()
      ..sort((a, b) => xpOf(b).compareTo(xpOf(a)));
    final guestStats = heroStats.where((s) => s['side'] == 'guest').toList()
      ..sort((a, b) => xpOf(b).compareTo(xpOf(a)));

    final hostTotal = (result['hostTotalXp'] as num?)?.toInt() ??
        hostStats.fold<int>(0, (a, s) => a + ((s['xpGained'] as num?)?.toInt() ?? 0));
    final guestTotal = (result['guestTotalXp'] as num?)?.toInt() ??
        guestStats.fold<int>(0, (a, s) => a + ((s['xpGained'] as num?)?.toInt() ?? 0));

    _tab ??= TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.mySide == 'guest' ? 1 : 0,
    );

    return Column(
      children: [
        // Başlık
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            children: [
              Icon(
                isVictory
                    ? Icons.emoji_events
                    : Icons.sentiment_very_dissatisfied,
                size: 56,
                color: accent,
              ),
              const SizedBox(height: 8),
              Text(
                isVictory ? "ZAFER" : "MAĞLUBİYET",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: accent,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$turns tur",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        // Sekmeler
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              _playerTab(hostName, 'host', winnerSide, hostTotal),
              _playerTab(guestName, 'guest', winnerSide, guestTotal),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // İçerik
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _teamReport(hostStats),
              _teamReport(guestStats),
            ],
          ),
        ),
        // Buton
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                child: const Text("ANA SAYFA"),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _playerTab(
      String name, String side, String? winnerSide, int totalXp) {
    final isWinner = side == winnerSide;
    return Tab(
      height: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWinner) ...[
                const Icon(Icons.emoji_events,
                    size: 14, color: Colors.amber),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            "+$totalXp XP",
            style: const TextStyle(
              fontSize: 10,
              color: Colors.amber,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamReport(List<Map<String, dynamic>> stats) {
    if (stats.isEmpty) {
      return const Center(
        child: Text("Veri yok", style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: stats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _HeroRow(stat: stats[i]),
    );
  }
}

class _HeroRow extends StatelessWidget {
  final Map<String, dynamic> stat;
  const _HeroRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final name = (stat['name'] as String?) ?? 'Adsız';
    final imageUrl = (stat['imageUrl'] as String?) ?? '';
    final isAlive = stat['isAlive'] == true;
    final damageDealt = (stat['damageDealt'] as num?)?.toInt() ?? 0;
    final damageReceived = (stat['damageReceived'] as num?)?.toInt() ?? 0;
    final killBonus = (stat['killBonusXp'] as num?)?.toInt() ?? 0;
    final survivalBonus = (stat['survivalBonusXp'] as num?)?.toInt() ?? 0;
    final xpGained = (stat['xpGained'] as num?)?.toInt() ?? 0;
    final kills = ((stat['kills'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlive
              ? Colors.white12
              : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: ClipOval(
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.shield,
                              color: Colors.white54),
                        )
                      : const Icon(Icons.shield, color: Colors.white54),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      isAlive ? "Hayatta" : "Ölü",
                      style: TextStyle(
                        fontSize: 10,
                        color: isAlive
                            ? Colors.tealAccent.withValues(alpha: 0.7)
                            : Colors.redAccent.withValues(alpha: 0.7),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Text("+$xpGained XP",
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.amber,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _pill(Icons.flash_on, "Verilen", damageDealt,
                  Colors.orangeAccent),
              const SizedBox(width: 6),
              _pill(Icons.shield_outlined, "Alınan", damageReceived,
                  Colors.redAccent),
            ],
          ),
          if (killBonus > 0 || survivalBonus > 0) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (killBonus > 0)
                  _bonusChip(Icons.local_fire_department,
                      "Öldürme bonusu", killBonus),
                if (survivalBonus > 0)
                  _bonusChip(Icons.favorite, "Hayatta kalma", survivalBonus),
              ],
            ),
          ],
          if (kills.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.deepOrange.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 12, color: Colors.deepOrange),
                      const SizedBox(width: 6),
                      Text(
                        "Öldürdükleri (${kills.length})",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final k in kills)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "· ${k['victimName'] ?? '?'}  "
                        "(ATK ${k['victimAttack'] ?? 0} + "
                        "DEF ${k['victimDefense'] ?? 0})  "
                        "T${k['turn'] ?? '?'}",
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  Text(label,
                      style: TextStyle(
                          fontSize: 9,
                          color: color.withValues(alpha: 0.8),
                          letterSpacing: 0.5)),
                  Text("$value",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bonusChip(IconData icon, String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.amber),
          const SizedBox(width: 4),
          Text("$label +$value",
              style: const TextStyle(fontSize: 10, color: Colors.amber)),
        ],
      ),
    );
  }
}
