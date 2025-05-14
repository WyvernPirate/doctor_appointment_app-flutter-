// SignUp.dart
import 'package:flutter/material.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For UserCredential and FirebaseAuthException
import 'package:doctor_appointment_app/services/auth_service.dart';
import 'ProfileCreation.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final String email = _emailController.text.trim();
        final String password = _passwordController.text.trim();

        UserCredential? userCredential = await _authService.signUpWithEmailAndPassword(email, password);

        if (userCredential?.user != null && mounted) {
          // User created successfully in Firebase Auth.
          // Now navigate to ProfileCreation, passing Firebase user's info.
          // ProfileCreation will be responsible for creating the Firestore document.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => ProfileCreation(
                      firebaseUser: userCredential!.user!, // Pass the Firebase User object
                      // Or pass specific details:
                      // email: userCredential.user!.email!,
                      // uid: userCredential.user!.uid,
                    )),
          );
        } else if (mounted) {
           _showError('Could not complete sign up. Please try again.');
        }
      } on FirebaseAuthException catch (e) {
        _showError(e.message ?? 'Sign up failed. Please try again.');
      } catch (e, stackTrace) {
        print("Error during sign up: $e");
        print(stackTrace);
        _showError('An unexpected error occurred during sign up.');
      } finally {
         setState(() { // Ensure loading stops on error
           _isLoading = false;
         });
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

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(children: [_signUpSection()]),
              ),
            ),
    );
  }

  Column _signUpSection() {
    
     // Make sure the password confirmation validator works:
     validator: (value) {
        if (value == null || value.isEmpty) { return 'Please confirm password'; }
        if (value != _passwordController.text) { return 'Passwords do not match'; }
        return null;
      };
    return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         const Padding(
          padding: EdgeInsets.all(15.0),
          child: Text(
            'Sign Up',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 20, left: 15),
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
           child: TextFormField(  // Use TextFormField
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Enter your email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
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
            'Create Password',
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
              labelText: 'Enter your new password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 20, left: 15),
          child: Text(
            'Confirm Password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 6.0),
          child: TextFormField(
             controller: _confirmPasswordController,
             decoration: const InputDecoration(
               labelText: 'Confirm your password',
               border: OutlineInputBorder(),
             ),
             obscureText: true,
             validator: (value) { // Ensure validator is correct
               if (value == null || value.isEmpty) {
                 return 'Please confirm your password';
               }
               if (value != _passwordController.text) {
                 return 'Passwords do not match';
               }
               return null;
             },
           ),
         ),
         Padding(
           padding: const EdgeInsets.all(15.0),
           child: SizedBox(
             width: double.infinity,
             height: 50,
             child: ElevatedButton(
               onPressed: _handleSignUp,style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ), 
               child: const Text('Sign Up'),
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
                child: Text("Or Register with"),
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
      ],
    );
  }
}