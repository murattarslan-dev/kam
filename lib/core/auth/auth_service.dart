import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Auth + users/{uid} dokümanını yöneten ince servis.
///
/// users/{uid} şeması:
/// - displayName: string (kayıtta zorunlu)
/// - email: string
/// - createdAt: timestamp
/// - isAdmin: bool (default false)
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _fs;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _fs = firestore ?? FirebaseFirestore.instance;

  /// Yetkili kabul edilen e-postalar. Bu hesap admin paneli açabilir.
  static const Set<String> adminEmails = {'kam@official.com'};

  User? get currentUser => _auth.currentUser;

  // Tek bir broadcast stream'i cache'le. Aksi halde her getter çağrısında
  // yeni stream döner, StreamBuilder'ı 'waiting' durumuna sokar ve resize
  // gibi rebuild'lerde tüm widget ağacının (router+state) sıfırlanmasına yol açar.
  Stream<User?>? _userChanges;
  Stream<User?> get userChanges =>
      _userChanges ??= _auth.authStateChanges().asBroadcastStream();

  bool get isAdmin {
    final email = _auth.currentUser?.email?.toLowerCase();
    return email != null && adminEmails.contains(email);
  }

  // Bellek-içi displayName cache'i; battle akışında sync okuma için.
  String? _displayName;
  String? get displayName => _displayName;

  Future<UserCredential> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _refreshDisplayName(cred.user);
    return cred;
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(displayName);
    await _fs.collection('users').doc(user.uid).set({
      'displayName': displayName,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'isAdmin': adminEmails.contains((user.email ?? '').toLowerCase()),
    }, SetOptions(merge: true));
    _displayName = displayName;
    return cred;
  }

  Future<void> signOut() async {
    _displayName = null;
    await _auth.signOut();
  }

  /// Uygulama açılışında çağrılır — auth state varsa users/{uid}.displayName'i yükle.
  Future<void> bootstrap() async {
    await _refreshDisplayName(_auth.currentUser);
  }

  Future<void> _refreshDisplayName(User? user) async {
    if (user == null) {
      _displayName = null;
      return;
    }
    try {
      final doc = await _fs.collection('users').doc(user.uid).get();
      final n = doc.data()?['displayName'] as String?;
      _displayName = n ?? user.displayName ?? user.email;
    } catch (_) {
      _displayName = user.displayName ?? user.email;
    }
  }

  Future<void> updateDisplayName(String newName) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(newName);
    await _fs.collection('users').doc(user.uid).set(
      {'displayName': newName},
      SetOptions(merge: true),
    );
    _displayName = newName;
  }
}
