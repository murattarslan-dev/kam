import 'package:flutter/material.dart';

/// Kart üzerinde yükselip silinen hasar/iyileşme rakamı.
/// Negatif değer kırmızı (hasar), pozitif değer yeşil (iyileşme) gösterir.
class FloatingNumber extends StatefulWidget {
  final int amount;
  final Duration duration;
  const FloatingNumber({
    super.key,
    required this.amount,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<FloatingNumber> createState() => _FloatingNumberState();
}

class _FloatingNumberState extends State<FloatingNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _rise;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)..forward();
    _rise = Tween<double>(begin: 0, end: -56).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOut),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 4),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 3),
    ]).animate(_c);
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.15), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 7),
    ]).animate(_c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDamage = widget.amount < 0;
    final color = isDamage ? Colors.redAccent : Colors.greenAccent;
    final text =
        isDamage ? '-${widget.amount.abs()}' : '+${widget.amount}';
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(0, _rise.value),
          child: Opacity(
            opacity: _opacity.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _scale.value,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 1,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 6, offset: Offset(1, 2)),
                    Shadow(color: Colors.black87, blurRadius: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
