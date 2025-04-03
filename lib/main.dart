import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'screens/Home.dart';
import 'screens/InitLogin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Check login status
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  bool isGuest = prefs.getBool('isGuest') ?? false;

  // Check if the user is already authenticated with Firebase
  bool isFirebaseLoggedIn = FirebaseAuth.instance.currentUser != null;

  runApp(MyApp(
    isLoggedIn: isLoggedIn || isFirebaseLoggedIn,
    isGuest: isGuest,
  ));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final bool isGuest;

  const MyApp({super.key, required this.isLoggedIn, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Appointment App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: isLoggedIn || isGuest
          ? const Home()
          : const InitLogin(),
    );
  }
}
