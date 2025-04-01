import 'package:flutter/material.dart';

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
        title: const Text('Doctor Appointment'), // You can add a title here
        centerTitle: true,
      ),
      body: SingleChildScrollView( // Added SingleChildScrollView
        child: Column(
          children: [_loginSection()],
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
                color: const Color.fromARGB(255, 207, 191, 193).withOpacity(0.5), // Reduced opacity
                blurRadius: 20, // reduced blurRadius
                spreadRadius: 1, // reduced spreadRadius
              ),
            ],
          ),
          child: TextField(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), // Changed to symmetric padding
              hintText: 'Enter your email address',
              hintStyle: const TextStyle(color: Color(0xffDDDADA), fontSize: 14),
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
                color: const Color.fromARGB(255, 207, 191, 193).withOpacity(0.5), // Reduced opacity
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TextField(
             obscureText: true, // Hide the password
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), // Changed to symmetric padding
              hintText: 'Enter your password',
              hintStyle: const TextStyle(color: Color(0xffDDDADA), fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
         Padding(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 1.0), // Adjust padding
          child: Row(
             mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  // tODO:Handle forgot password
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
           padding: const EdgeInsets.all(15.0), // Adjust Padding
          child: SizedBox(
            width: double.infinity, // make the button take all the available space.
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                //TODO: handle on button click
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
      ],
    );
  }
}
