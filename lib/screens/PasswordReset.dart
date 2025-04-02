import 'package:flutter/material.dart';

class PasswordReset extends StatefulWidget {
  const PasswordReset({super.key});

  @override
  State<PasswordReset> createState() => _PasswordResetState();
}

class _PasswordResetState extends State<PasswordReset> {
 Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Reset'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
      child: Column(children: [
        _passResetSection()
      ]),

      )
    );
  }

  Column _passResetSection() {
    return Column(

    );
  }
}
