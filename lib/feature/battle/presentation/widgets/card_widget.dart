import 'dart:ui';
import 'package:flutter/material.dart';
import '../../domain/entities/hero_entities.dart';

/// Gelişmiş Oyun Kartı Bileşeni
class KamCardWidget extends StatelessWidget {
  final HeroCardEntity card;
  final bool isSelected;
  final bool isEnemy;
  final VoidCallback onTap;

  const KamCardWidget({
    super.key,
    required this.card,
    required this.isSelected,
    required this.isEnemy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Kartın seçim durumuna göre animasyon değerleri
    final double scale = isSelected && card.isAlive ? 1.1 : 1.0;
    final double translateY = isSelected && card.isAlive ? -15.0 : 0.0;

    // Sağlık oranı (0.0 ile 1.0 arasında)
    final double hpRatio = (card.health / card.healthPower).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: card.isAlive ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        width: 130,
        height: 190,
        transform: Matrix4.identity()
          ..scale(scale)
          ..translate(0.0, translateY),
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
            color: _getBorderColor(),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected && card.isAlive
                  ? Colors.yellowAccent.withOpacity(0.4)
                  : Colors.black.withOpacity(0.3),
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
                    _buildHeader(),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: Text(
                          card.isAlive ? _getElementEmoji(card.element) : "👻",
                          style: const TextStyle(fontSize: 48),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildBottomPanel(hpRatio),
                    ),
                  ],
                ),
              ),

              if (!card.isAlive) ...[
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                  child: Container(color: Colors.black.withOpacity(0.2)),
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
    );
  }

  Color _getBorderColor() {
    if (!card.isAlive) return Colors.black54;
    return isSelected ? Colors.yellowAccent : Colors.white24;
  }

  Widget _buildHeader() {
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
                  fontSize: 9,
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

  Widget _buildBottomPanel(double hpRatio) {
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
              _buildStatItem(Icons.flash_on, card.attackPower.toString(), card.isAlive ? Colors.orange : Colors.grey),
              _buildStatItem(Icons.security, card.defensePower.toString(), card.isAlive ? Colors.blue : Colors.grey),
              _buildStatItem(Icons.stars_outlined, card.level.toString(), card.isAlive ? Colors.purpleAccent : Colors.grey),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: hpRatio,
                    minHeight: 5, // Daha belirgin olması için 5 yaptık
                    backgroundColor: Colors.white10,
                    // Dinamik renk fonksiyonunu çağırıyoruz
                    color: _getHealthColor(hpRatio, card.isAlive),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  card.isAlive ? "HP ${card.health}" : "CAN TÜKENDİ",
                  style: const TextStyle(color: Colors.white60, fontSize: 7, fontWeight: FontWeight.bold),
                ),
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
          style: TextStyle(color: color.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ],
    );
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