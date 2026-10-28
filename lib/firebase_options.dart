import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyACr1qqBBPguK0xkr71pitq-paxZMiA9NQ',
    appId: '1:47443081490:android:adc3bda5c25de229715bcb',
    messagingSenderId: '47443081490',
    projectId: 'dostyq-taxi',
    storageBucket: 'dostyq-taxi.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBs_hT-uTf2Ay8EVVhgLiqfYFoNsHQx2GI',
    appId: '1:47443081490:web:ede2c87e96b9565d715bcb',
    messagingSenderId: '47443081490',
    projectId: 'dostyq-taxi',
    storageBucket: 'dostyq-taxi.firebasestorage.app',
    authDomain: 'dostyq-taxi.firebaseapp.com',
    measurementId: 'G-GC01TBN6V9',
  );
}
