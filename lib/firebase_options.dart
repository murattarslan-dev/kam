import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyATnVYdFyzp-PCB43WgoHtwQbdsTYylbiY',
    appId: '1:430093785717:web:d78599c17a53d63a0d363c',
    messagingSenderId: '430093785717',
    projectId: 'kam-1a8ab',
    authDomain: 'kam-1a8ab.firebaseapp.com',
    storageBucket: 'kam-1a8ab.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD-Pu4moG7DZPkOf4wP71bT1BymI_7MKjE',
    appId: '1:430093785717:android:6eb2afc57a9b422a0d363c',
    messagingSenderId: '430093785717',
    projectId: 'kam-1a8ab',
    storageBucket: 'kam-1a8ab.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAhAQjj1U4EFODeABMffhNP4JobjI7KWho',
    appId: '1:430093785717:ios:20ddeea321faae240d363c',
    messagingSenderId: '430093785717',
    projectId: 'kam-1a8ab',
    storageBucket: 'kam-1a8ab.firebasestorage.app',
    iosBundleId: 'com.murattarslan.kam',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAhAQjj1U4EFODeABMffhNP4JobjI7KWho',
    appId: '1:430093785717:ios:20ddeea321faae240d363c',
    messagingSenderId: '430093785717',
    projectId: 'kam-1a8ab',
    storageBucket: 'kam-1a8ab.firebasestorage.app',
    iosBundleId: 'com.murattarslan.kam',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyATnVYdFyzp-PCB43WgoHtwQbdsTYylbiY',
    appId: '1:430093785717:web:bc5f487a7c054d4f0d363c',
    messagingSenderId: '430093785717',
    projectId: 'kam-1a8ab',
    authDomain: 'kam-1a8ab.firebaseapp.com',
    storageBucket: 'kam-1a8ab.firebasestorage.app',
  );

}