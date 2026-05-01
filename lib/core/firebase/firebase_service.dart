import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

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

  /// Get firestore instance (Other features might need it)
  FirebaseFirestore get firestore => _firestore;
}
