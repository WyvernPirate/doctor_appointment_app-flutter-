// main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/Home.dart';
import 'screens/InitLogin.dart';
import 'screens/ProfileCreation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Appointment App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthCheck(),
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isGuest = false;
  bool _isFirstTime = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isGuest = prefs.getBool('isGuest') ?? false;
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (_isGuest) {
      setState(() {
        _isLoading = false;
      });
    } else if (FirebaseAuth.instance.currentUser != null) {
      // User is logged in with Firebase
      _isLoggedIn = true;
      await _checkFirstTime();
    } else {
      // User is not logged in
      _isLoggedIn = false;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkFirstTime() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    setState(() {
      _isFirstTime = !userDoc.exists;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      if (_isGuest) {
        return const Home();
      } else if (_isLoggedIn && _isFirstTime) {
        return const ProfileCreation();
      } else if (_isLoggedIn && !_isFirstTime) {
        return const Home();
      } else {
        return const InitLogin();
      }
    }
  }
}
