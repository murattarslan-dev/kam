import 'dart:ui';
import 'package:flutter/material.dart';
import '../../domain/entities/hero_entities.dart';
import '../../domain/entities/buff_entities.dart';
import 'package:kam/core/util/responsive_helper.dart';

class KamCardWidget extends StatelessWidget {
  final HeroCardEntity card;
  final bool isSelected;
  final bool isEnemy;
  final VoidCallback onTap;
  final VoidCallback? onTozPressed;
  final double? advantageMultiplier;
  final List<ActiveBuff> activeBuffs;
  final List<BuffEntity> allBuffs;
  final double? overrideWidth;

  const KamCardWidget({
    super.key,
    required this.card,
    required this.isSelected,
    required this.isEnemy,
    required this.onTap,
    this.onTozPressed,
    this.advantageMultiplier,
    this.activeBuffs = const [],
    this.allBuffs = const [],
    this.overrideWidth,
  });

  @override
  Widget build(BuildContext context) {
    // Kartın seçim durumuna göre animasyon değerleri
    final double scale = isSelected && card.isAlive ? 1.08 : 1.0;
    final double translateY = isSelected && card.isAlive ? -context.scaleH(10) : 0.0;

    // Responsive boyutlar
    final double cardWidth = overrideWidth ?? context.responsive(
      context.screenWidth * 0.28, // Mobil için ekranın %28'i
      tablet: 140.0,
      desktop: 160.0,
    );
    final double cardHeight = cardWidth * 1.6; // Altın oran benzeri oran (1.6)

    // Sağlık oranı (0.0 ile 1.0 arasında)
    final double hpRatio = (card.health / card.currentCp).clamp(0.0, 1.0);

    Color? advantageColor;
    if (advantageMultiplier != null && advantageMultiplier != 1.0 && isSelected) {
      advantageColor = advantageMultiplier! > 1.0 ? Colors.greenAccent : Colors.redAccent;
    }

    return GestureDetector(
      onTap: card.isAlive ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        margin: EdgeInsets.symmetric(
          horizontal: context.responsive(4.0, tablet: 8.0),
          vertical: context.responsive(8.0, tablet: 12.0),
        ),
        width: cardWidth,
        height: cardHeight + (isSelected && card.isAlive ? 20 : 0), // Seçili olduğunda buton alanı ekle
        transform: Matrix4.identity()
          ..scale(scale, scale, 1.0)
          ..translate(0.0, translateY, 0.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Kart Gövdesi (Animasyonlu Dekorasyon ile)
            Positioned(
              top: 15,
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: card.isAlive
                      ? _getElementGradient(card.element)
                      : const LinearGradient(
                    colors: [Color(0xFF4B5563), Color(0xFF1F2937)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isSelected ? (advantageColor ?? _getBorderColor()) : _getBorderColor(),
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected && card.isAlive
                          ? (advantageColor ?? Colors.yellowAccent).withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.3),
                      blurRadius: isSelected ? 20 : 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    children: [
                      ColorFiltered(
                        colorFilter: card.isAlive
                            ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                            : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                        child: Stack(
                          children: [
                            _buildHeader(context),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 40),
                                child: Text(
                                  card.isAlive ? _getElementEmoji(card.element) : "👻",
                                  style: const TextStyle(fontSize: 48),
                                ),
                              ),
                            ),
                            if (advantageMultiplier != null && advantageMultiplier != 1.0 && isSelected)
                              Positioned(
                                top: 10,
                                right: 10,
                                child: BouncingArrow(isAdvantage: advantageMultiplier! > 1.0),
                              ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: _buildBottomPanel(context, hpRatio),
                            ),
                          ],
                        ),
                      ),
                      if (!card.isAlive) ...[
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                          child: Container(color: Colors.black.withValues(alpha: 0.2)),
                        ),
                        Center(
                          child: Transform.rotate(
                            angle: -0.2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.redAccent, width: 2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "ÖLÜ",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Töz Kullan Butonu (Kartın üstünde, hit-test edilebilir alanda)
            if (onTozPressed != null && isSelected && card.isAlive)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(80, 36),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: onTozPressed,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text("TÖZ KULLAN",
                            style: TextStyle(
                                fontSize: context.responsive(10.0, tablet: 11.0),
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBorderColor() {
    if (!card.isAlive) return Colors.black54;
    return isSelected ? Colors.yellowAccent : Colors.white24;
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(
                card.isAlive ? _getElementEmoji(card.element) : "💀",
                style: const TextStyle(fontSize: 14)
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 70,
              child: Text(
                card.name.toUpperCase(),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: card.isAlive ? Colors.white : Colors.grey,
                  fontSize: context.responsive(8.0, tablet: 10.0),
                  fontWeight: FontWeight.bold,
                  decoration: card.isAlive ? null : TextDecoration.lineThrough,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Icon(
                _getRoleIcon(card.role),
                size: 14,
                color: card.isAlive ? Colors.white70 : Colors.grey
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, double hpRatio) {
    final heroBuffs = _resolveHeroBuffs();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: card.isAlive ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.flash_on, card.currentAttackPower.toString(), card.isAlive ? Colors.orange : Colors.grey),
              _buildStatItem(Icons.security, card.currentDefensePower.toString(), card.isAlive ? Colors.blue : Colors.grey),
              if (isSelected) _buildStatItem(Icons.favorite, card.currentCp.toString(), card.isAlive ? Colors.greenAccent : Colors.grey),
            ],
          ),
          if (heroBuffs.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildBuffStrip(heroBuffs),
          ],
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                if (isSelected) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Lv ${card.level}",
                        style: TextStyle(color: card.isAlive ? Colors.purpleAccent : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                      if (!isEnemy && card.isAlive)
                        Row(
                          children: [
                            const Icon(Icons.flash_on, size: 10, color: Colors.lightBlueAccent),
                            Text(
                              "${card.kut}",
                              style: TextStyle(color: Colors.lightBlueAccent, fontSize: context.responsive(10.0, tablet: 12.0), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      Text(
                        "XP ${card.xp}",
                        style: TextStyle(color: card.isAlive ? Colors.white70 : Colors.grey, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: hpRatio,
                    minHeight: 5,
                    backgroundColor: Colors.white10,
                    color: _getHealthColor(hpRatio, card.isAlive),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 2),
                  Text(
                    card.isAlive ? "HP ${card.health}" : "CAN TÜKENDİ",
                    style: const TextStyle(color: Colors.white60, fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// UX Çalışması: Can barının doluluk oranına göre renk döndürür
  Color _getHealthColor(double ratio, bool isAlive) {
    if (!isAlive) return Colors.grey; // Ölü ise gri
    if (ratio > 0.7) return Colors.greenAccent; // %70+ Yeşil
    if (ratio > 0.4) return Colors.yellowAccent; // %40-%70 Sarı
    if (ratio > 0.15) return Colors.orangeAccent; // %15-%40 Turuncu
    return Colors.redAccent; // %15- Kritik Kırmızı
  }

  Widget _buildStatItem(IconData icon, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 12, color: color),
        Text(
          value,
          style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// Bu kartla eşleşen aktif buff'ları (BuffEntity, ActiveBuff) çiftleri olarak çözer.
  List<({BuffEntity buff, ActiveBuff active})> _resolveHeroBuffs() {
    if (activeBuffs.isEmpty || allBuffs.isEmpty) return const [];
    final result = <({BuffEntity buff, ActiveBuff active})>[];
    for (final ab in activeBuffs) {
      if (ab.targetHeroId != card.id) continue;
      final match = allBuffs.where((b) => b.id == ab.buffId);
      if (match.isEmpty) continue;
      result.add((buff: match.first, active: ab));
    }
    return result;
  }

  Widget _buildBuffStrip(List<({BuffEntity buff, ActiveBuff active})> heroBuffs) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: heroBuffs.map((entry) => _buildBuffBadge(entry.buff, entry.active)).toList(),
    );
  }

  Widget _buildBuffBadge(BuffEntity buff, ActiveBuff active) {
    final (icon, color) = _buffVisual(buff);
    final tooltip = '${buff.name}'
        '${buff.description.isNotEmpty ? '\n${buff.description}' : ''}'
        '${active.remainingTurns > 0 ? '\nKalan: ${active.remainingTurns} tur' : ''}';

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, size: 10, color: color)),
            if (active.remainingTurns > 0)
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${active.remainingTurns}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _buffVisual(BuffEntity buff) {
    switch (buff.type) {
      case BuffType.dot:
        return (Icons.local_fire_department, Colors.orangeAccent);
      case BuffType.hot:
        return (Icons.healing, Colors.greenAccent);
      case BuffType.statChange:
        return buff.isDebuff
            ? (Icons.arrow_downward, Colors.redAccent)
            : (Icons.arrow_upward, Colors.lightGreenAccent);
    }
  }

  IconData _getRoleIcon(HeroRole role) {
    return switch (role) {
      HeroRole.warrior => Icons.rocket_launch,
      HeroRole.support => Icons.favorite,
      HeroRole.mage => Icons.auto_fix_high,
      HeroRole.tank => Icons.shield,
    };
  }

  LinearGradient _getElementGradient(HeroElement element) {
    return switch (element) {
      HeroElement.fire => const LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFF7F1D1D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      HeroElement.water => const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      HeroElement.wind => const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF064E3B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      HeroElement.steppe => const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFF78350F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      HeroElement.forest => const LinearGradient(
        colors: [Color(0xFF22C55E), Color(0xFF14532D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      HeroElement.dark => const LinearGradient(
        colors: [Color(0xFF4B5563), Color(0xFF111827)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    };
  }

  String _getElementEmoji(HeroElement element) {
    return switch (element) {
      HeroElement.fire => "🔥",
      HeroElement.water => "💧",
      HeroElement.wind => "🌬️",
      HeroElement.steppe => "🌾",
      HeroElement.forest => "🌲",
      HeroElement.dark => "🌑",
    };
  }
}

/// Yukarı veya aşağı doğru hareket eden (bouncing) avantaj animasyon oku.
class BouncingArrow extends StatefulWidget {
  final bool isAdvantage;
  const BouncingArrow({super.key, required this.isAdvantage});

  @override
  State<BouncingArrow> createState() => _BouncingArrowState();
}

class _BouncingArrowState extends State<BouncingArrow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    _animation = Tween<double>(begin: -5.0, end: 5.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Icon(
            widget.isAdvantage ? Icons.keyboard_double_arrow_up : Icons.keyboard_double_arrow_down,
            color: widget.isAdvantage ? Colors.greenAccent : Colors.redAccent,
            size: 32,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 4,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        );
      },
    );
  }
}