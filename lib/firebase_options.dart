// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

/// Helper function to get environment variables
String _getEnv(String name) {
  final value = dotenv.env[name];
  if (value == null) {
    throw Exception('Missing environment variable: $name. Ensure .env file is loaded.');
  }
  return value;
}

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (dotenv.env.isEmpty && !kIsWeb) { 
      print("Warning: dotenv seems not loaded in DefaultFirebaseOptions. Ensure await dotenv.load() was called in main().");
      throw Exception("dotenv is not loaded. Call await dotenv.load() in main() first.");
    }

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

  // --- Read values from environment variables ---
  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _getEnv('FIREBASE_WEB_API_KEY'),
        appId: _getEnv('FIREBASE_WEB_APP_ID'),
        messagingSenderId: _getEnv('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _getEnv('FIREBASE_PROJECT_ID'),
        authDomain: _getEnv('FIREBASE_WEB_AUTH_DOMAIN'),
        storageBucket: _getEnv('FIREBASE_STORAGE_BUCKET'),
        measurementId: _getEnv('FIREBASE_WEB_MEASUREMENT_ID'),
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _getEnv('FIREBASE_ANDROID_API_KEY'),
        appId: _getEnv('FIREBASE_ANDROID_APP_ID'),
        messagingSenderId: _getEnv('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _getEnv('FIREBASE_PROJECT_ID'),
        storageBucket: _getEnv('FIREBASE_STORAGE_BUCKET'),
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: _getEnv('FIREBASE_IOS_API_KEY'),
        appId: _getEnv('FIREBASE_IOS_APP_ID'),
        messagingSenderId: _getEnv('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _getEnv('FIREBASE_PROJECT_ID'),
        storageBucket: _getEnv('FIREBASE_STORAGE_BUCKET'),
        iosBundleId: _getEnv('FIREBASE_IOS_BUNDLE_ID'),
      );

  static FirebaseOptions get macos => FirebaseOptions(
        apiKey: _getEnv('FIREBASE_MACOS_API_KEY'),
        appId: _getEnv('FIREBASE_MACOS_APP_ID'),
        messagingSenderId: _getEnv('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _getEnv('FIREBASE_PROJECT_ID'),
        storageBucket: _getEnv('FIREBASE_STORAGE_BUCKET'),
        iosBundleId: _getEnv('FIREBASE_MACOS_BUNDLE_ID'),
      );

  static FirebaseOptions get windows => FirebaseOptions(
        apiKey: _getEnv('FIREBASE_WINDOWS_API_KEY'),
        appId: _getEnv('FIREBASE_WINDOWS_APP_ID'),
        messagingSenderId: _getEnv('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _getEnv('FIREBASE_PROJECT_ID'),
        authDomain: _getEnv('FIREBASE_WINDOWS_AUTH_DOMAIN'),
        storageBucket: _getEnv('FIREBASE_STORAGE_BUCKET'),
        measurementId: _getEnv('FIREBASE_WINDOWS_MEASUREMENT_ID'),
      );
}