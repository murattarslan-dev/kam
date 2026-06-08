import 'package:firebase_auth/firebase_auth.dart';

/// Oyuncu kimliği = FirebaseAuth uid.
///
/// Daha önce localStorage tabanlı bir geçici id kullanılıyordu (tüm
/// istemciler aynı sabit hesapla giriş yaptığı için zorunluydu). Auth
/// akışı eklendiğinden artık `uid` doğrudan kullanılıyor.
String getPlayerId() {
  return FirebaseAuth.instance.currentUser?.uid ?? '';
}
