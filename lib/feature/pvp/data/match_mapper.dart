import '../../battle/domain/entities/hero_entities.dart';

/// matches/{id} dokümanındaki kahraman dizilerini HeroCardEntity'ye çevirir ve
/// geri serileştirir. HeroCardEntity.toMap() kayıplı olduğu için (yalnızca
/// id/name/element/role/hp/atk/def/imageUrl) burada tam bir snapshot tutulur:
/// savaş sırasındaki güncel `health`, `kut`, `xp` ve yetenek kartları dahil.
///
/// Kahraman id'leri payload'da SAKLANMAZ; istemciler diziyi okurken konuma göre
/// deterministik bir "instance id" atar (örn. host tarafı `h:0`, guest `g:0`).
/// Bu, iki oyuncunun aynı envanter kahramanına sahip olması durumunda yaşanan id
/// çakışmasını önler — savaş motoru kahramanları id ile eşleştiriyor.
class MatchMapper {
  static Map<String, dynamic> heroFull(HeroCardEntity h) => {
        'name': h.name,
        'description': h.description,
        'element': h.element.name,
        'role': h.role.name,
        'xp': h.xp,
        'cp': h.cp,
        'health': h.health,
        'attackPower': h.attackPower,
        'defensePower': h.defensePower,
        'imageUrl': h.imageUrl,
        'kut': h.kut,
        'skills': h.skillCards.map((s) => s.toMap()).toList(),
      };

  static HeroCardEntity heroFromFull(Map<String, dynamic> m, String id) {
    final skills = (m['skills'] as List<dynamic>? ?? [])
        .map((s) => SkillEntity.fromMap(Map<String, dynamic>.from(s as Map)))
        .toList();
    return HeroCardEntity(
      id: id,
      name: m['name'] as String? ?? 'Adsız',
      description: m['description'] as String? ?? '',
      element: HeroElement.fromString(m['element'] as String? ?? 'steppe'),
      role: HeroRole.fromString(m['role'] as String? ?? 'warrior'),
      xp: (m['xp'] as num?)?.toInt() ?? 0,
      cp: (m['cp'] as num?)?.toInt() ?? 100,
      health: (m['health'] as num?)?.toInt() ?? 100,
      attackPower: (m['attackPower'] as num?)?.toInt() ?? 10,
      defensePower: (m['defensePower'] as num?)?.toInt() ?? 5,
      imageUrl: m['imageUrl'] as String? ?? '',
      kut: (m['kut'] as num?)?.toInt() ?? 0,
      skillCards: skills,
    );
  }

  static List<Map<String, dynamic>> teamToList(List<HeroCardEntity> team) =>
      team.map(heroFull).toList();

  static List<HeroCardEntity> teamFromList(dynamic raw, String prefix) {
    if (raw is! List) return [];
    final out = <HeroCardEntity>[];
    for (var i = 0; i < raw.length; i++) {
      out.add(heroFromFull(Map<String, dynamic>.from(raw[i] as Map), '$prefix$i'));
    }
    return out;
  }
}
