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
    apiKey: 'AIzaSyDRFSrbAFOQSDAqaY8kRK2JO8urT24eVHk',
    appId: '1:4258195571:web:5d426201af99e7dfece206',
    messagingSenderId: '4258195571',
    projectId: 'doctorappointmentapp-9f11a',
    authDomain: 'doctorappointmentapp-9f11a.firebaseapp.com',
    storageBucket: 'doctorappointmentapp-9f11a.firebasestorage.app',
    measurementId: 'G-17FJDGBC2T',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB_BUlJIrAQ4KO2ANO2-X9qFmu0XcNoNp8',
    appId: '1:4258195571:android:53216a74a62412c4ece206',
    messagingSenderId: '4258195571',
    projectId: 'doctorappointmentapp-9f11a',
    storageBucket: 'doctorappointmentapp-9f11a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAJ9ASkjimR8cDHSHncLkYwyd0eKah2a5Q',
    appId: '1:4258195571:ios:99e52dc2dd59fab7ece206',
    messagingSenderId: '4258195571',
    projectId: 'doctorappointmentapp-9f11a',
    storageBucket: 'doctorappointmentapp-9f11a.firebasestorage.app',
    iosBundleId: 'com.example.doctorAppointmentApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAJ9ASkjimR8cDHSHncLkYwyd0eKah2a5Q',
    appId: '1:4258195571:ios:99e52dc2dd59fab7ece206',
    messagingSenderId: '4258195571',
    projectId: 'doctorappointmentapp-9f11a',
    storageBucket: 'doctorappointmentapp-9f11a.firebasestorage.app',
    iosBundleId: 'com.example.doctorAppointmentApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDRFSrbAFOQSDAqaY8kRK2JO8urT24eVHk',
    appId: '1:4258195571:web:73875b2466136043ece206',
    messagingSenderId: '4258195571',
    projectId: 'doctorappointmentapp-9f11a',
    authDomain: 'doctorappointmentapp-9f11a.firebaseapp.com',
    storageBucket: 'doctorappointmentapp-9f11a.firebasestorage.app',
    measurementId: 'G-EDNFJ8WQPB',
  );
}