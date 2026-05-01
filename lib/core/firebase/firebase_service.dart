import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../feature/battle/domain/entities/hero_entities.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initializes Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  /// Anonymous sign in
  Future<User?> signInAnonymously() async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      print("Firebase Auth Error: $e");
      return null;
    }
  }

  /// Sign in with email and password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Firebase Auth Error (Login): $e");
      return null;
    }
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Firestore Collections
  CollectionReference get _heroesCollection => _firestore.collection('heroes');

  /// Fetch all heroes from Firestore including their skills
  Future<List<HeroCardEntity>> fetchHeroes() async {
    QuerySnapshot snapshot = await _heroesCollection.get();
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

  /// Fetch user-specific heroes from Firestore
  /// Path: users/{userId}/heroes
  /// Each doc contains hero_id and xp. The rest is fetched from global heroes collection.
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
        
        // XP değerini güvenli bir şekilde int'e çevir
        int userXp = 0;
        final xpRaw = userHeroData['xp'];
        if (xpRaw is int) {
          userXp = xpRaw;
        } else if (xpRaw is String) {
          userXp = int.tryParse(xpRaw) ?? 0;
        }

        // Global kahraman verisini getir
        final globalHeroDoc = await _heroesCollection.doc(heroId).get();
        if (!globalHeroDoc.exists) {
          continue;
        }

        final heroData = globalHeroDoc.data() as Map<String, dynamic>;
        // Entity ID'si olarak kullanıcının döküman ID'sini kullanıyoruz (güncelleme için lazım)
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
      print("Error fetching user heroes: $e");
      return [];
    }
  }

  /// Update hero XP in Firestore
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
      print("XP Updated: +$xpGain for hero $userHeroDocId");
    } catch (e) {
      print("Error updating XP: $e");
    }
  }
}
