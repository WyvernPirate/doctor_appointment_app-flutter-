import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'Home.dart'; // Your existing Home screen
import 'InitLogin.dart'; // Your existing Login screen

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // User is not signed in
        if (!snapshot.hasData || snapshot.data == null) {
          return const InitLogin();
        }

        // User is signed in
        return const Home(); // Navigate to your existing Home screen
      },
    );
  }
}