import 'package:flutter/material.dart';
import '../../domain/entities/hero_entities.dart';
import '../../domain/entities/buff_entities.dart';
import 'element_icon.dart';

/// Kahramanın tüm detaylarını gösteren tam ekran modal.
/// Stats, açıklama, yetenekler (Töz), element matchup tablosu.
class HeroDetailDialog extends StatelessWidget {
  final HeroCardEntity hero;
  final List<BuffEntity> allBuffs;
  const HeroDetailDialog({
    super.key,
    required this.hero,
    this.allBuffs = const [],
  });

  static Future<void> show(
    BuildContext context,
    HeroCardEntity hero, {
    List<BuffEntity> allBuffs = const [],
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => HeroDetailDialog(hero: hero, allBuffs: allBuffs),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0B1220),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(),
                  const SizedBox(height: 14),
                  _buildStatsGrid(),
                  const SizedBox(height: 14),
                  _buildXpBar(),
                  const SizedBox(height: 16),
                  if (hero.description.isNotEmpty) ...[
                    _sectionTitle('HİKÂYE'),
                    const SizedBox(height: 6),
                    Text(
                      hero.description,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12, height: 1.45),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _sectionTitle('YETENEKLER (TÖZ)'),
                  const SizedBox(height: 6),
                  if (hero.tozler.isEmpty)
                    const Text(
                      'Bu kahramanın yeteneği yok.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    )
                  else
                    ...hero.tozler.map(_buildTozCard),
                  const SizedBox(height: 16),
                  _sectionTitle('ELEMENT AVANTAJLARI'),
                  const SizedBox(height: 6),
                  _buildElementTable(),
                ],
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    final isUrl = hero.imageUrl.startsWith('http');
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: _gradient(hero.element),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isUrl)
            Image.network(hero.imageUrl,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                stops: const [0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 12, right: 12, bottom: 10,
            child: Row(
              children: [
                ElementIcon(element: hero.element, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hero.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                        ),
                      ),
                      Text(
                        '${hero.element.label} • ${hero.role.label} • Lv ${hero.level}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
                Icon(_roleIcon(hero.role), color: Colors.white, size: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        _stat('ATK', '${hero.currentAttackPower}', Icons.flash_on, Colors.orangeAccent,
            bonus: hero.bonusAttack),
        _stat('DEF', '${hero.currentDefensePower}', Icons.security, Colors.blueAccent,
            bonus: hero.bonusDefense),
        _stat('CP', '${hero.currentCp}', Icons.favorite, Colors.redAccent),
        _stat('LV', '${hero.level}', Icons.star, Colors.purpleAccent),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color,
      {int bonus = 0}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 9, letterSpacing: 1)),
            if (bonus > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('+$bonus',
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 9)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildXpBar() {
    final progress = hero.xpProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('XP',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            Text(
              '${hero.xp} / ${hero.level * 1000}  ·  sonraki seviyeye ${hero.xpToNextLevel}',
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white12,
            color: Colors.purpleAccent,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 3)),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: Colors.white12, height: 1)),
      ],
    );
  }

  Widget _buildTozCard(String buffId) {
    final buff = allBuffs.where((b) => b.id == buffId).firstOrNull;
    final name = buff?.name ?? buffId;
    final description = buff?.description ?? '';
    final cost = buff?.cost ?? 0;
    final (icon, color) = _buffVisual(buff);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
              if (buff?.isManual ?? false)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.lightBlueAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: Colors.lightBlueAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt,
                          color: Colors.lightBlueAccent, size: 11),
                      const SizedBox(width: 2),
                      Text('$cost',
                          style: const TextStyle(
                              color: Colors.lightBlueAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11, height: 1.4)),
          ],
          if (buff != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _chip(_buffSummary(buff), color),
            ),
        ],
      ),
    );
  }

  String _buffSummary(BuffEntity b) {
    final suffix = b.valueMode == ValueMode.percent ? '%' : '';
    return '${b.type.name} · ${b.value}$suffix';
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildElementTable() {
    final strongAgainst = <HeroElement>[];
    final weakAgainst = <HeroElement>[];
    for (final t in HeroElement.values) {
      if (t == hero.element) continue;
      final m = hero.element.getDamageMultiplier(t);
      if (m > 1.0) strongAgainst.add(t);
      if (m < 1.0) weakAgainst.add(t);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _matchupRow('Güçlü', strongAgainst, Colors.greenAccent, Icons.arrow_upward),
        const SizedBox(height: 6),
        _matchupRow('Zayıf', weakAgainst, Colors.redAccent, Icons.arrow_downward),
      ],
    );
  }

  Widget _matchupRow(
      String label, List<HeroElement> elements, Color color, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: elements.isEmpty
              ? const Text('—',
                  style: TextStyle(color: Colors.white38, fontSize: 11))
              : Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: elements.map((e) {
                    final m = hero.element.getDamageMultiplier(e);
                    return Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElementIcon(element: e, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${e.label} ×${m.toStringAsFixed(1)}',
                            style: TextStyle(color: color, fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  (IconData, Color) _buffVisual(BuffEntity? buff) {
    if (buff == null) return (Icons.help_outline, Colors.white54);
    return switch (buff.type) {
      BuffType.hot => (Icons.healing, Colors.greenAccent),
      BuffType.dot => (Icons.local_fire_department, Colors.redAccent),
      BuffType.damageSoak => (Icons.shield, Colors.blueAccent),
      BuffType.arenaImmunity => (Icons.public, Colors.purpleAccent),
      BuffType.statChange => buff.statType == StatType.defense
          ? (Icons.shield_outlined, Colors.blueAccent)
          : (Icons.flash_on, Colors.orangeAccent),
      BuffType.dispel => (Icons.cleaning_services, Colors.purpleAccent),
      BuffType.damageRedirect => (Icons.compare_arrows, Colors.amberAccent),
    };
  }

  IconData _roleIcon(HeroRole role) => switch (role) {
        HeroRole.warrior => Icons.rocket_launch,
        HeroRole.support => Icons.favorite,
        HeroRole.mage => Icons.auto_fix_high,
        HeroRole.tank => Icons.shield,
      };

  LinearGradient _gradient(HeroElement element) => switch (element) {
        HeroElement.fire => const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFF7F1D1D)]),
        HeroElement.water => const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)]),
        HeroElement.wind => const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF064E3B)]),
        HeroElement.steppe => const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFF78350F)]),
        HeroElement.forest => const LinearGradient(
            colors: [Color(0xFF22C55E), Color(0xFF14532D)]),
        HeroElement.dark => const LinearGradient(
            colors: [Color(0xFF4B5563), Color(0xFF111827)]),
      };
}
