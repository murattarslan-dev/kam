import 'package:flutter/material.dart';
import '../../domain/entities/hero_entities.dart';

/// Oyunun ana kart bileşeni (Kam veya Töz birimlerini temsil eder)
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
    // Şimdilik maksimum sağlığı 100 varsayıyoruz (İleride entity'e eklenebilir)
    const double maxHealth = 100.0;
    final double hpRatio = card.health / maxHealth;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 100,
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.yellow
                : (isEnemy ? Colors.red.withOpacity(0.4) : Colors.blue.withOpacity(0.4)),
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.yellow.withOpacity(0.3), blurRadius: 15)]
              : [],
        ),
        child: Opacity(
          opacity: !card.isAlive ? 0.4 : 1.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Element İkonu veya Karakter Görseli (Şimdilik Emoji)
              Text(
                _getElementEmoji(card.element),
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 6),

              // İsim Alanı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  card.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Sağlık Çubuğu (HP Bar)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: hpRatio.clamp(0.0, 1.0),
                    backgroundColor: Colors.black26,
                    color: hpRatio > 0.5 ? Colors.greenAccent : Colors.redAccent,
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // İstatistikler
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flash_on, size: 12, color: Colors.orangeAccent),
                  Text(
                    " ${card.attackPower}",
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),

              // Durum Etiketi
              if (!card.isAlive)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "RUH OLDU",
                    style: TextStyle(fontSize: 7, color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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