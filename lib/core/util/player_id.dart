import 'dart:html' as html;
import 'dart:math';

/// Geçici (oturum-bazlı) oyuncu kimliği. Login yok; paylaşımlı Firebase hesabı
/// (kam@official.com) tüm istemcilerde aynı UID'yi verdiği için PvP eşleşmesinde
/// kullanılamaz. Bunun yerine her tarayıcı sekmesine özel, sessionStorage'da
/// saklanan bir id üretilir (iki sekme = iki ayrı oyuncu).
String? _cached;

String getPlayerId() {
  final existing = _cached;
  if (existing != null) return existing;

  final stored = html.window.sessionStorage['kam_player_id'];
  if (stored != null && stored.isNotEmpty) {
    _cached = stored;
    return stored;
  }

  final id = 'p_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 31)}';
  html.window.sessionStorage['kam_player_id'] = id;
  _cached = id;
  return id;
}
