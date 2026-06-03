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
    final double scale = isSelected && card.isAlive ? 1.08 : 1.0;
    final double translateY = isSelected && card.isAlive ? -context.scaleH(10) : 0.0;

    final double cardWidth = overrideWidth ?? context.responsive(
      (context.screenWidth * 0.28).clamp(78.0, 130.0),
      tablet: 140.0,
      desktop: 160.0,
    );
    final double cardHeight = cardWidth * 1.6;
    final double hpRatio = (card.health / card.currentCp).clamp(0.0, 1.0);

    Color? advantageColor;
    if (advantageMultiplier != null && advantageMultiplier != 1.0 && isSelected) {
      advantageColor = advantageMultiplier! > 1.0 ? Colors.greenAccent : Colors.redAccent;
    }

    final borderColor = isSelected
        ? (advantageColor ?? Colors.yellowAccent)
        : (card.isAlive ? Colors.white24 : Colors.black54);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      margin: EdgeInsets.symmetric(
        horizontal: context.responsive(4.0, tablet: 8.0),
        vertical: context.responsive(8.0, tablet: 12.0),
      ),
      width: cardWidth,
      height: cardHeight + (isSelected && card.isAlive ? 20 : 0),
      transform: Matrix4.identity()
        ..scale(scale, scale, 1.0)
        ..translate(0.0, translateY, 0.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Card body
          Positioned(
            top: 15, left: 0, right: 0, bottom: 0,
            child: GestureDetector(
              onTap: card.isAlive ? onTap : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: isSelected ? 3 : 1),
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
                  child: ColorFiltered(
                    colorFilter: card.isAlive
                        ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                        : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Full-bleed background image
                        _buildBackground(),
                        // Bottom gradient overlay for readability
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.35, 0.65, 1.0],
                                colors: [
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.55),
                                  Colors.black.withValues(alpha: 0.92),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Advantage arrow
                        if (advantageMultiplier != null && advantageMultiplier != 1.0 && isSelected)
                          Positioned(
                            top: 8, right: 8,
                            child: BouncingArrow(isAdvantage: advantageMultiplier! > 1.0),
                          ),
                        // Bottom info block
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: _buildBottomPanel(context, hpRatio),
                        ),
                        // Dead overlay
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
                                child: Text(
                                  "ÖLÜ",
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: context.responsive(13.0, tablet: 16.0),
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
            ),
          ),
          // Töz button (above card)
          if (onTozPressed != null && isSelected && card.isAlive)
            Positioned(
              top: 0, left: 0, right: 0,
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
                      Text(
                        "TÖZ KULLAN",
                        style: TextStyle(
                          fontSize: context.responsive(10.0, tablet: 11.0),
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Full-bleed background: image if available, else element gradient.
  Widget _buildBackground() {
    final url = card.imageUrl;
    final isWebUrl = url.startsWith('http://') || url.startsWith('https://');
    if (isWebUrl) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _gradientBackground(),
      );
    }
    return _gradientBackground();
  }

  Widget _gradientBackground() {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: _getElementGradient(card.element)),
    );
  }

  Widget _buildBottomPanel(BuildContext context, double hpRatio) {
    final heroBuffs = _resolveHeroBuffs();

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Buff badges
          if (heroBuffs.isNotEmpty) ...[
            _buildBuffStrip(heroBuffs),
            const SizedBox(height: 4),
          ],
          // Stats row (only when selected)
          if (isSelected) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.flash_on, card.currentAttackPower.toString(), Colors.orange),
                _buildStatItem(Icons.security, card.currentDefensePower.toString(), Colors.blue),
                if (!isEnemy)
                  _buildStatItem(Icons.flash_on, "${card.kut}", Colors.lightBlueAccent),
              ],
            ),
            const SizedBox(height: 4),
          ],
          // HP bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: hpRatio,
              minHeight: 4,
              backgroundColor: Colors.white12,
              color: _getHealthColor(hpRatio, card.isAlive),
            ),
          ),
          const SizedBox(height: 5),
          // Name + element + role row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _getElementEmoji(card.element),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  card.name.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: card.isAlive ? Colors.white : Colors.grey,
                    fontSize: context.responsive(8.0, tablet: 9.0),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                    decoration: card.isAlive ? null : TextDecoration.lineThrough,
                  ),
                ),
              ),
              Icon(
                _getRoleIcon(card.role),
                size: 12,
                color: card.isAlive ? Colors.white70 : Colors.grey,
              ),
            ],
          ),
          // Level + HP text (only when selected)
          if (isSelected) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Lv ${card.level}",
                  style: TextStyle(
                    color: card.isAlive ? Colors.purpleAccent : Colors.grey,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  card.isAlive ? "HP ${card.health}/${card.currentCp}" : "CAN TÜKENDİ",
                  style: const TextStyle(color: Colors.white60, fontSize: 7, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getHealthColor(double ratio, bool isAlive) {
    if (!isAlive) return Colors.grey;
    if (ratio > 0.7) return Colors.greenAccent;
    if (ratio > 0.4) return Colors.yellowAccent;
    if (ratio > 0.15) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Widget _buildStatItem(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 2),
        Text(value, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

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
      children: heroBuffs.map((e) => _buildBuffBadge(e.buff, e.active)).toList(),
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
        width: 16, height: 16,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, size: 10, color: color)),
            if (active.remainingTurns > 0)
              Positioned(
                right: -3, bottom: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${active.remainingTurns}',
                    style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
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
      case BuffType.damageSoak:
        return (Icons.local_fire_department, Colors.redAccent);
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
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      HeroElement.water => const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      HeroElement.wind => const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF064E3B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      HeroElement.steppe => const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFF78350F)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      HeroElement.forest => const LinearGradient(
        colors: [Color(0xFF22C55E), Color(0xFF14532D)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      HeroElement.dark => const LinearGradient(
        colors: [Color(0xFF4B5563), Color(0xFF111827)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: -5.0, end: 5.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(1, 1))],
          ),
        );
      },
    );
  }
}
