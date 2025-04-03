// InitLogin.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Home.dart';
import 'PasswordReset.dart';
import 'ProfileCreation.dart';
import 'SignUp.dart';

class InitLogin extends StatefulWidget {
  const InitLogin({super.key});

  @override
  State<InitLogin> createState() => _InitLoginState();
}

class _InitLoginState extends State<InitLogin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields')),
        );
        return;
      }

      // Sign in with email and password
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // If successful, save login state and navigate
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setBool('isGuest', false);

      // Check if it's the first time login
      bool isFirstTime = await _checkFirstTime(userCredential.user!.uid);

      // Navigate to the appropriate screen
      // ignore: use_build_context_synchronously
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                isFirstTime ? const ProfileCreation() : const Home()),
      );
    } on FirebaseAuthException catch (e) {
      // Handle Firebase authentication errors
      String errorMessage = 'An error occurred.';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is badly formatted.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This user account has been disabled.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      // Handle other errors
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkFirstTime(String userId) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    return !userDoc.exists;
  }

  Future<void> _handleSkipLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.setBool('isGuest', true);

    // Navigate to the Home screen
    // ignore: use_build_context_synchronously
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Home()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Appointment'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(child: Column(children: [_loginSection()])),
    );
  }

  Column _loginSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 50),
        const Padding(
          padding: EdgeInsets.all(15.0),
          child: Text(
            'Log In',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 5, left: 15),
          child: Text(
            'Email Address',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 6.0),
          child: TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Enter your Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 20, left: 15),
          child: Text(
            'Password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 6.0),
          child: TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Enter your Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 1.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PasswordReset(),
                    ),
                  );
                  print("Forgot password pressed");
                },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Log In',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0),
          child: Row(
            children: [
              Expanded(
                  child: Divider(
                thickness: 1,
                indent: 20,
              )),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text("Or Login with"),
              ),
              Expanded(
                  child: Divider(
                thickness: 1,
                endIndent: 20,
              )),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SignInButton(
                Buttons.FacebookNew,
                onPressed: () {
                  // TODO: Handle Facebook login
                  print("Facebook login pressed");
                },
              ),
              SignInButton(
                Buttons.GoogleDark,
                onPressed: () {
                  // TODO: Handle Google login
                  print("Google login pressed");
                },
              ),
              SignInButton(
                Buttons.AppleDark,
                onPressed: () {
                  // TODO: Handle Apple login
                  print("Apple login pressed");
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account?"),
              TextButton(
                onPressed: () {
                  // Navigate to the SignUp screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignUp()),
                  );
                },
                child: const Text("Sign up"),
              ),
              TextButton(
                onPressed: _handleSkipLogin,
                child: const Text("Skip"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
