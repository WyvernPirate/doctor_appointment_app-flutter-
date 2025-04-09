// InitLogin.dart
import 'package:cloud_firestore/cloud_firestore.dart';
// Remove firebase_auth import
import 'package:flutter/material.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Home.dart';
import 'PasswordReset.dart'; // This will need a custom implementation now
import 'SignUp.dart';
import '../utils/hash_helper.dart'; // Import the hashing utility

class InitLogin extends StatefulWidget {
  const InitLogin({super.key});

  @override
  State<InitLogin> createState() => _InitLoginState();
}

class _InitLoginState extends State<InitLogin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>(); // Keep form key

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final String email = _emailController.text.trim();
        final String password = _passwordController.text.trim(); // Plain text password

        // Query Firestore for the user by email
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1) // Expect only one user per email
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // User found
          var userData = querySnapshot.docs.first.data() as Map<String, dynamic>;
          String storedHash = userData['hashedPassword'] ?? '';
          String userId = querySnapshot.docs.first.id; // Get the document ID

          // Verify the entered password against the stored hash
          if (HashHelper.verifyPassword(password, storedHash)) {
            // Password matches!
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('loggedInUserId', userId); // Store Firestore doc ID
            await prefs.setBool('isGuest', false);

            // Navigate to the Home screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Home()),
            );
            // No need to return here, navigation replaces the screen

          } else {
            // Password does not match
            _showError('Incorrect password.');
          }
        } else {
          // User not found
          _showError('No user found for that email.');
        }
      } catch (e, stackTrace) {
        print("Error during login: $e");
        print(stackTrace);
        _showError('An unexpected error occurred during login.');
      } finally {
        // Ensure loading indicator stops regardless of outcome
        if (mounted) { // Check if the widget is still in the tree
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showError(String message) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(message)),
       );
     }
  }


  Future<void> _handleSkipLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Clear any potential loggedInUserId if skipping
    await prefs.remove('loggedInUserId');
    await prefs.setBool('isGuest', true);

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
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(children: [_loginSection()]),
              ),
            ),
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
          child: TextFormField( // Use TextFormField
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Enter your Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) { // Add validator
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
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
          child: TextFormField( // Use TextFormField
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Enter your Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (value) { // Add validator
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
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
               onPressed: _handleLogin, // Calls the refactored login
               style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
               child: const Text('Log In'
               ,style: TextStyle(
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
