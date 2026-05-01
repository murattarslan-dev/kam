import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/hero_entities.dart';
import 'battle_datasource.dart';

class FirebaseBattleDataSourceImpl implements BattleDataSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<List<HeroCardEntity>> fetchAllHeroes() async {
    final heroesCollection = _firestore.collection('heroes');
    QuerySnapshot snapshot = await heroesCollection.get();
    List<HeroCardEntity> heroes = [];

    for (var doc in snapshot.docs) {
      final heroData = doc.data() as Map<String, dynamic>;
      heroData['id'] = doc.id;

      // Fetch skills from sub-collection
      final skillsSnapshot = await doc.reference.collection('skills').get();
      final skills = skillsSnapshot.docs.map((s) {
        final skillData = s.data() as Map<String, dynamic>;
        skillData['id'] = s.id;
        return SkillEntity.fromMap(skillData);
      }).toList();

      heroes.add(HeroCardEntity.fromMap(heroData, skills: skills));
    }
    return heroes;
  }

  @override
  Future<List<HeroCardEntity>> fetchUserHeroes(String userId) async {
    try {
      final userHeroesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('heroes')
          .get();

      List<HeroCardEntity> userHeroes = [];

      for (var userHeroDoc in userHeroesSnapshot.docs) {
        final userHeroData = userHeroDoc.data();
        final heroId = userHeroData['hero_id'] as String;
        
        int userXp = 0;
        final xpRaw = userHeroData['xp'];
        if (xpRaw is int) {
          userXp = xpRaw;
        } else if (xpRaw is String) {
          userXp = int.tryParse(xpRaw) ?? 0;
        }

        // Global kahraman verisini getir
        final globalHeroDoc = await _firestore.collection('heroes').doc(heroId).get();
        if (!globalHeroDoc.exists) continue;

        final heroData = globalHeroDoc.data() as Map<String, dynamic>;
        heroData['id'] = userHeroDoc.id; 
        heroData['xp'] = userXp; 

        // Global kahramanın yeteneklerini getir
        final skillsSnapshot = await globalHeroDoc.reference.collection('skills').get();
        final skills = skillsSnapshot.docs.map((s) {
          final skillData = s.data() as Map<String, dynamic>;
          skillData['id'] = s.id;
          return SkillEntity.fromMap(skillData);
        }).toList();

        userHeroes.add(HeroCardEntity.fromMap(heroData, skills: skills));
      }
      return userHeroes;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> updateHeroXp(String userId, String userHeroDocId, int xpGain) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('heroes')
          .doc(userHeroDocId)
          .update({
        'xp': FieldValue.increment(xpGain),
      });
    } catch (e) {
      // Handle error
    }
  }
}
