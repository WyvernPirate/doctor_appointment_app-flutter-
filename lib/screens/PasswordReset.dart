import 'package:flutter/material.dart';

class PasswordReset extends StatefulWidget {
  const PasswordReset({super.key});

  @override
  State<PasswordReset> createState() => _PasswordResetState();
}

class _PasswordResetState extends State<PasswordReset> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _currentStep = 0; // 0: Email, 1: Code, 2: New Password

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      _currentStep++;
    });
  }

  void _previousStep() {
    setState(() {
      _currentStep--;
    });
  }

  void _handleEmailSubmit() {
    // TODO: Send email with confirmation code
    // For now, just simulate success
    print('Email submitted: ${_emailController.text}');
    _nextStep();
  }

  void _handleCodeSubmit() {
    // TODO: Verify confirmation code
    // For now, just simulate success
    print('Code submitted: ${_codeController.text}');
    _nextStep();
  }

  void _handlePasswordReset() {
    // TODO: Reset password
    // For now, just simulate success
    print('New password: ${_newPasswordController.text}');
    print('Confirm password: ${_confirmPasswordController.text}');

    // Check if passwords match
    if (_newPasswordController.text == _confirmPasswordController.text) {
      // Passwords match, proceed with reset
      // TODO: Call your password reset API here
      print('Password reset successful!');
      // Show success message and navigate back to login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successful!')),
      );
      Navigator.pop(context); // Go back to the previous screen (login)
    } else {
      // Passwords don't match, show error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Reset'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    switch (_currentStep) {
      case 0:
        return _buildEmailForm();
      case 1:
        return _buildCodeForm();
      case 2:
        return _buildPasswordForm();
      default:
        return Container();
    }
  }

  Widget _buildEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter your email to receive a confirmation code.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _handleEmailSubmit,
          child: const Text('Send Code'),
        ),
      ],
    );
  }

  Widget _buildCodeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter the confirmation code sent to your email.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: 'Confirmation Code',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: _previousStep,
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: _handleCodeSubmit,
              child: const Text('Verify Code'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter your new password.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _newPasswordController,
          decoration: const InputDecoration(
            labelText: 'New Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmPasswordController,
          decoration: const InputDecoration(
            labelText: 'Confirm New Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: _previousStep,
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: _handlePasswordReset,
              child: const Text('Reset Password'),
            ),
          ],
        ),
      ],
    );
  }
}
