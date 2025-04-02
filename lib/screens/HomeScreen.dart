// HomeScreen.dart
import 'PasswordReset.dart';
import 'package:flutter/material.dart';
import 'SignUp.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomePageState();
}

class _HomePageState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Appointment'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(children: [_loginSection()]),
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
            'Log in',
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
        Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 207, 191, 193).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TextField(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              hintText: 'Enter your email address',
              hintStyle: const TextStyle(
                color: Color(0xffDDDADA),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
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
        Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 207, 191, 193).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TextField(
            obscureText: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              hintText: 'Enter your password',
              hintStyle: const TextStyle(
                color: Color(0xffDDDADA),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: 15.0,
            right: 15.0,
            top: 1.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  // TODO:Handle forgot password
                  Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const PasswordReset())
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
              onPressed: () {
                //TODO: handle on button click
                print("Login button pressed");
              },
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
              Expanded(child: Divider(thickness: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text("Or Login with"),
              ),
              Expanded(child: Divider(thickness: 1)),
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
            ],
          ),
        ),
      ],
    );
  }
}
