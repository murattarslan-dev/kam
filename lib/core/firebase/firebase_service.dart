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

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Firestore Collections
  CollectionReference get _heroesCollection => _firestore.collection('heroes');

  /// Fetch all heroes from Firestore
  Future<List<HeroCardEntity>> fetchHeroes() async {
    QuerySnapshot snapshot = await _heroesCollection.get();
    return snapshot.docs.map((doc) => HeroCardEntity.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }
}
